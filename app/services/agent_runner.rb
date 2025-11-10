# frozen_string_literal: true

require "json"

# Generic Agent Runner
#
# Executes any agent by reading its prompt from the database and using
# the appropriate execution strategy based on work_type.
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
    Rails.logger.info("AgentRunner: Executing #{agent.name} (#{agent.key}) for work item ##{work_item.id}")

    # Read prompt from agent record
    prompt = agent.prompt
    unless prompt
      return {
        success: false,
        error: "Agent #{agent.key} has no prompt configured"
      }
    end

    # Build context for LLM
    context = build_context

    # Call LLM with prompt and context
    llm_response = call_llm(prompt, context)

    # Parse LLM response
    parsed_response = parse_llm_response(llm_response)

    # Handle error responses
    if parsed_response[:type] == "error"
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
    update_run_records(result)

    result
  rescue StandardError => e
    Rails.logger.error("AgentRunner failed: #{e.message}\n#{e.backtrace.join("\n")}")
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

  def call_llm(prompt, context)
    llm_service = LlmService.new
    response = llm_service.chat(prompt: prompt, context: context)

    # If LLM returned an error or no content, return error response
    if response[:error] || response[:content].blank?
      error_msg = response[:error] || "LLM returned empty response"
      Rails.logger.error("LLM service error: #{error_msg}")
      return {
        llm_content: nil,
        usage: response[:usage] || {},
        error: error_msg
      }
    end

    # Return LLM response content for parsing
    {
      llm_content: response[:content],
      usage: response[:usage]
    }
  rescue StandardError => e
    Rails.logger.error("Failed to call LLM: #{e.message}\n#{e.backtrace.join("\n")}")
    {
      llm_content: nil,
      usage: {},
      error: e.message
    }
  end


  def parse_llm_response(response)
    # Handle error responses
    if response[:error] || response[:llm_content].blank?
      return {
        type: "error",
        error: response[:error] || "LLM returned empty response"
      }
    end

    # Try to parse LLM response as JSON
    # The LLM should return structured JSON matching the expected format
    begin
      parsed = JSON.parse(response[:llm_content])
      # Ensure it's a hash with symbol keys
      parsed = parsed.deep_symbolize_keys if parsed.is_a?(Hash)
      parsed
    rescue JSON::ParserError => e
      Rails.logger.error("Failed to parse LLM response as JSON: #{e.message}")
      Rails.logger.debug("LLM response content: #{response[:llm_content]}")
      {
        type: "error",
        error: "Failed to parse LLM response as JSON: #{e.message}"
      }
    end
  end

  def resolve_strategy
    # Determine execution strategy based on work_type
    case work_item.work_type
    when /_setup$/, "repo_bootstrap", "rails_setup", "ci_setup", "dependabot_setup",
         "rubocop_setup", "eslint_setup", "git_hooks_setup", "frontend_setup", "readme_setup"
      WorkspaceRunnerStrategy.new(project: project, agent: agent, work_item: work_item)
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

  def update_run_records(result)
    # Update run records with outcome
    run = work_item.runs.order(started_at: :desc).first
    return unless run

    run.update!(
      finished_at: Time.current,
      outcome: result[:success] ? "success" : "failure",
      logs: result[:message] || result[:error]
    )

    # Update work item status
    if result[:success]
      work_item.update!(status: "completed")
    else
      work_item.update!(status: "failed")
    end
  end
end
