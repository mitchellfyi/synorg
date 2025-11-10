# frozen_string_literal: true

# Execution Strategy for agents that use WorkspaceRunner
# Handles setup agents that create files via Git workspace operations
class WorkspaceRunnerStrategy
  attr_reader :project, :agent, :work_item

  def initialize(project:, agent:, work_item:)
    @project = project
    @agent = agent
    @work_item = work_item
  end

  def execute(parsed_response)
    return { success: false, error: "Invalid response type: #{parsed_response[:type]}" } unless parsed_response[:type] == "workspace_changes"

    changes_data = parsed_response[:changes]
    return { success: false, error: "No changes provided" } if changes_data.blank?

    # Handle both old format (array) and new format (hash with message, files, etc.)
    changes = if changes_data.is_a?(Hash) && changes_data[:files]
                 # New format: { message:, pr_title:, pr_body:, files: [...] }
                 {
                   message: changes_data[:message] || "",
                   pr_title: changes_data[:pr_title] || "",
                   pr_body: changes_data[:pr_body] || "",
                   files: changes_data[:files] || []
                 }
               else
                 # Old format: array of files
                 {
                   message: "",
                   pr_title: "",
                   pr_body: "",
                   files: changes_data
                 }
               end

    return { success: false, error: "No files provided" } if changes[:files].blank?

    pat = project.github_pat
    return { success: false, error: "No PAT configured" } unless pat

    workspace_runner = WorkspaceRunner.new(
      project: project,
      agent: agent,
      work_item: work_item
    )

    result = workspace_runner.execute(changes: changes)

    if result
      {
        success: true,
        message: "#{agent.name} completed successfully",
        pr_url: workspace_runner.run&.payload&.dig("pr_url")
      }
    else
      {
        success: false,
        error: "#{agent.name} failed"
      }
    end
  rescue StandardError => e
    Rails.logger.error("WorkspaceRunnerStrategy failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end
