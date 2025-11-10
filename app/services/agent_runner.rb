# frozen_string_literal: true

require "json"
require_relative "../lib/structured_logger"
require_relative "../lib/llm_output_schema"

# Generic Agent Runner
#
# Executes any agent by reading its prompt from the database and using
# the appropriate execution strategy based on work_type.
# Uses structured output schemas for deterministic behavior.
#
# Example usage:
#   agent = Agent.find_by(key: "gtm")
#   work_item = project.work_items.create!(work_type: "gtm", ...)
#   runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
#   result = runner.run
#
class AgentRunner
  attr_reader :agent, :project, :work_item

  def initialize(agent:, project:, work_item:)
    @agent = agent
    @project = project
    @work_item = work_item
  end

  def run
    StructuredLogger.agent_event(:started, agent: agent, work_item: work_item)

    # Create a Run record to track this execution
    run = Run.create!(
      agent: agent,
      work_item: work_item,
      started_at: Time.current
    )

    # Read prompt from agent record
    prompt = agent.prompt
    unless prompt
      StructuredLogger.error(
        "Agent has no prompt configured",
        agent_id: agent.id,
        agent_key: agent.key,
        work_item_id: work_item.id
      )
      run.update!(
        finished_at: Time.current,
        outcome: "failure",
        logs: "Agent #{agent.key} has no prompt configured"
      )
      return {
        success: false,
        error: "Agent #{agent.key} has no prompt configured"
      }
    end

    # Build context for LLM
    context = build_context

    # Determine expected schema type from work_type
    schema_type = LlmOutputSchema.infer_from_work_type(work_item.work_type)
    schema = LlmOutputSchema.for_type(schema_type)

    # Call LLM with prompt, context, and structured output schema
    llm_response = call_llm(prompt, context, schema)

    # Parse and validate LLM response against schema
    parsed_response = parse_llm_response(llm_response, schema)

    # Handle error responses
    if parsed_response[:type] == "error"
      StructuredLogger.agent_event(
        :failed,
        agent: agent,
        work_item: work_item,
        error: parsed_response[:error]
      )
      run.update!(
        finished_at: Time.current,
        outcome: "failure",
        logs: parsed_response[:error] || "Unknown error"
      )
      return {
        success: false,
        error: parsed_response[:error] || "Unknown error"
      }
    end

    # Determine execution strategy based on work_type
    strategy = resolve_strategy

    # Execute using the strategy
    result = strategy.execute(parsed_response)

    # Update work item and run records
    update_run_records(result, run)

    if result[:success]
      StructuredLogger.agent_event(
        :completed,
        agent: agent,
        work_item: work_item,
        strategy: strategy.class.name
      )
    else
      StructuredLogger.agent_event(
        :failed,
        agent: agent,
        work_item: work_item,
        error: result[:error]
      )
    end

    result
  rescue StandardError => e
    # Update run record if it exists
    if defined?(run) && run
      run.update!(
        finished_at: Time.current,
        outcome: "failure",
        logs: e.message
      )
    end
    StructuredLogger.error(
      "AgentRunner failed",
      agent_id: agent.id,
      agent_key: agent.key,
      work_item_id: work_item.id,
      project_id: project.id,
      error: e.message,
      error_class: e.class.name,
      backtrace: e.backtrace.first(5)
    )
    {
      success: false,
      error: e.message
    }
  end

  private

  def build_context
    {
      project: {
        name: project.name,
        slug: project.slug,
        state: project.state,
        brief: project.brief,
        repo_full_name: project.repo_full_name,
        repo_default_branch: project.repo_default_branch
      },
      work_item: {
        id: work_item.id,
        work_type: work_item.work_type,
        payload: work_item.payload,
        priority: work_item.priority
      },
      agent: {
        key: agent.key,
        name: agent.name,
        capabilities: agent.capabilities
      }
    }
  end

  def call_llm(prompt, context, schema)
    llm_service = LlmService.new
    response = llm_service.chat(
      prompt: prompt,
      context: context,
      project: project,
      agent: agent,
      structured_output: schema
    )

    # If LLM returned an error or no content, return error response
    if response[:error] || response[:content].blank?
      error_msg = response[:error] || "LLM returned empty response"
      StructuredLogger.error(
        "LLM service error",
        agent_id: agent.id,
        work_item_id: work_item.id,
        error: error_msg,
        usage: response[:usage]
      )
      return {
        llm_content: nil,
        usage: response[:usage] || {},
        error: error_msg
      }
    end

    # Log successful LLM call
    StructuredLogger.llm_event(
      :response,
      model: llm_service.model,
      agent_id: agent.id,
      work_item_id: work_item.id,
      usage: response[:usage],
      structured_output: schema.schema_type
    )

    # Return LLM response content for parsing
    {
      llm_content: response[:content],
      usage: response[:usage]
    }
  rescue StandardError => e
    StructuredLogger.error(
      "Failed to call LLM",
      agent_id: agent.id,
      work_item_id: work_item.id,
      error: e.message,
      error_class: e.class.name
    )
    {
      llm_content: nil,
      usage: {},
      error: e.message
    }
  end

  def parse_llm_response(response, schema)
    # Handle error responses
    if response[:error] || response[:llm_content].blank?
      return {
        type: "error",
        error: response[:error] || "LLM returned empty response"
      }
    end

    # Content is already parsed JSON when using structured outputs
    parsed = response[:llm_content]

    # Validate and normalize against schema
    begin
      validated = schema.validate_and_normalize(parsed)
      StructuredLogger.debug(
        "LLM response validated",
        agent_id: agent.id,
        work_item_id: work_item.id,
        schema_type: schema.schema_type
      )
      validated
    rescue LlmOutputSchema::ValidationError => e
      StructuredLogger.error(
        "LLM response validation failed",
        agent_id: agent.id,
        work_item_id: work_item.id,
        error: e.message,
        schema_type: schema.schema_type,
        response_preview: parsed.is_a?(Hash) ? parsed.to_json.truncate(500) : parsed&.truncate(500)
      )
      {
        type: "error",
        error: "Response validation failed: #{e.message}"
      }
    rescue StandardError => e
      StructuredLogger.error(
        "Failed to parse LLM response",
        agent_id: agent.id,
        work_item_id: work_item.id,
        error: e.message,
        error_class: e.class.name,
        response_preview: parsed.is_a?(Hash) ? parsed.to_json.truncate(500) : parsed&.truncate(500)
      )
      {
        type: "error",
        error: "Failed to parse LLM response: #{e.message}"
      }
    end
  end

  def resolve_strategy
    # Determine execution strategy based on work_type
    case work_item.work_type
    when /_setup$/, "repo_bootstrap", "rails_setup", "ci_setup", "dependabot_setup",
         "rubocop_setup", "eslint_setup", "git_hooks_setup", "frontend_setup", "readme_setup"
      GitHubApiStrategy.new(project: project, agent: agent, work_item: work_item)
    when "gtm", "docs"
      FileWriteStrategy.new(project: project, agent: agent, work_item: work_item)
    when "product_manager", "orchestrator"
      DatabaseStrategy.new(project: project, agent: agent, work_item: work_item)
    when "issue"
      GitHubApiStrategy.new(project: project, agent: agent, work_item: work_item)
    else
      raise "Unknown execution strategy for work_type: #{work_item.work_type}"
    end
  end

  def update_run_records(result, run)
    # Update run record with outcome
    run.update!(
      finished_at: Time.current,
      outcome: result[:success] ? "success" : "failure",
      logs: result[:message] || result[:error] || "Execution completed"
    )

    # Update work item status
    if result[:success]
      work_item.update!(status: "completed")
    else
      work_item.update!(status: "failed")
    end
  end
end
