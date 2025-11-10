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

    # Call LLM with prompt and context (stub for now)
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
    # Try to use LLM service if available
    llm_service = LlmService.new
    response = llm_service.chat(prompt: prompt, context: context)

    # If LLM returned an error or no content, fall back to legacy services
    if response[:error] || response[:content].blank?
      Rails.logger.warn("LLM service unavailable or returned error, falling back to legacy service")
      return generate_stub_response(prompt, context)
    end

    # Return LLM response content for parsing
    {
      llm_content: response[:content],
      usage: response[:usage]
    }
  rescue StandardError => e
    Rails.logger.warn("Failed to call LLM, falling back to legacy service: #{e.message}")
    generate_stub_response(prompt, context)
  end

  def generate_stub_response(prompt, context)
    # Bridge to legacy service classes for now
    # In production, this would call an LLM API and parse the response
    # For now, we delegate to legacy services that have the actual implementation
    legacy_service = find_legacy_service
    if legacy_service
      return execute_legacy_service(legacy_service)
    end

    # Fallback stub implementation
    case work_item.work_type
    when /_setup$/, "repo_bootstrap"
      {
        type: "workspace_changes",
        changes: []
      }
    when "gtm", "docs"
      {
        type: "file_writes",
        files: []
      }
    when "product_manager", "orchestrator"
      {
        type: "work_items",
        work_items: []
      }
    when "issue"
      {
        type: "github_operations",
        operations: []
      }
    else
      {
        type: "unknown",
        message: "No implementation for work_type: #{work_item.work_type}"
      }
    end
  end

  def find_legacy_service
    # Map work_type to legacy service class
    service_class = case work_item.work_type
                    when "dependabot_setup"
                      DependabotSetupAgentService
                    when "ci_setup"
                      CiWorkflowSetupAgentService
                    when "rails_setup"
                      RailsAppSetupAgentService
                    when "repo_bootstrap"
                      RepoBootstrapAgentService
                    when "gtm"
                      GtmAgentService
                    when "docs"
                      DocsAgentService
                    when "product_manager"
                      ProductManagerAgentService
                    when "issue"
                      IssueAgentService
                    when "dev_tooling"
                      DevToolingAgentService
                    else
                      nil
                    end

    return nil unless service_class

    # Instantiate the legacy service with appropriate arguments
    case work_item.work_type
    when /_setup$/, "repo_bootstrap"
      # Setup agents need project, agent, work_item
      service_class.new(project, agent, work_item)
    when "gtm"
      # GTM needs project_brief
      service_class.new(project.brief, agent: agent)
    when "docs"
      # Docs needs project_brief
      service_class.new(project.brief, agent: agent)
    when "product_manager"
      # Product Manager needs project
      service_class.new(project, agent: agent)
    when "issue"
      # Issue needs project
      service_class.new(project, agent: agent)
    when "dev_tooling"
      # Dev Tooling needs no args
      service_class.new(agent: agent)
    else
      nil
    end
  end

  def execute_legacy_service(legacy_service)
    # For setup agents, extract changes without executing
    # For other agents, execute and convert response
    case work_item.work_type
    when /_setup$/, "repo_bootstrap"
      # Setup agents: extract changes, don't execute (strategy will handle execution)
      changes = extract_changes_from_legacy_service(legacy_service)
      {
        type: "workspace_changes",
        changes: changes
      }
    when "gtm", "docs"
      # File-writing agents: execute and extract files
      result = legacy_service.run
      if result[:success]
        {
          type: "file_writes",
          files: extract_files_from_legacy_service(legacy_service, result)
        }
      else
        {
          type: "error",
          error: result[:error]
        }
      end
    when "product_manager"
      # Product Manager: execute (creates work items), return success
      result = legacy_service.run
      if result[:success]
        {
          type: "work_items",
          work_items: [] # Already created by legacy service
        }
      else
        {
          type: "error",
          error: result[:error]
        }
      end
    when "issue"
      # Issue agent: execute (creates GitHub issues), return success
      result = legacy_service.run
      if result[:success]
        {
          type: "github_operations",
          operations: [] # Already performed by legacy service
        }
      else
        {
          type: "error",
          error: result[:error]
        }
      end
    else
      {
        type: "unknown",
        message: "Unknown work_type: #{work_item.work_type}"
      }
    end
  end

  def extract_changes_from_legacy_service(legacy_service)
    # Extract file changes from legacy setup service
    # Setup services implement generate_changes method that returns:
    # { message:, pr_title:, pr_body:, files: [...] }
    return { message: "", pr_title: "", pr_body: "", files: [] } unless legacy_service.respond_to?(:generate_changes, true)

    changes = legacy_service.send(:generate_changes)
    {
      message: changes[:message] || "",
      pr_title: changes[:pr_title] || "",
      pr_body: changes[:pr_body] || "",
      files: changes[:files] || []
    }
  rescue StandardError => e
    Rails.logger.error("Failed to extract changes from legacy service: #{e.message}")
    { message: "", pr_title: "", pr_body: "", files: [] }
  end

  def extract_files_from_legacy_service(legacy_service, result)
    # Extract file paths and content from legacy file-writing service
    files = []

    if result[:file_path]
      # Single file (GTM)
      files << {
        path: result[:file_path].to_s.gsub(Rails.root.to_s + "/", ""),
        content: File.read(result[:file_path]) if File.exist?(result[:file_path])
      }
    elsif result[:files_updated]
      # Multiple files (Docs)
      result[:files_updated].each do |file_path|
        full_path = Rails.root.join(file_path)
        files << {
          path: file_path,
          content: File.read(full_path) if File.exist?(full_path)
        }
      end
    end

    files
  rescue StandardError => e
    Rails.logger.error("Failed to extract files from legacy service: #{e.message}")
    []
  end

  def parse_llm_response(response)
    # If response is from legacy service (no llm_content), return as-is
    return response unless response[:llm_content]

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

      # Fall back to legacy service if JSON parsing fails
      Rails.logger.warn("Falling back to legacy service due to JSON parse error")
      generate_stub_response("", {})
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
