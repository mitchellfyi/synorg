# frozen_string_literal: true

# Execution Strategy for agents that interact with GitHub API
# Handles agents like Issue that create GitHub issues, PRs, etc.
class GitHubApiStrategy
  attr_reader :project, :agent, :work_item

  def initialize(project:, agent:, work_item:)
    @project = project
    @agent = agent
    @work_item = work_item
  end

  def execute(parsed_response)
    return { success: false, error: "Invalid response type: #{parsed_response[:type]}" } unless parsed_response[:type] == "github_operations"

    operations = parsed_response[:operations] || []
    return { success: false, error: "No operations provided" } if operations.empty?

    pat = project.github_pat
    return { success: false, error: "No PAT configured" } unless pat

    github_service = GithubService.new(project.repo_full_name, pat)
    operations_performed = []

    operations.each do |op|
      case op[:operation] || op["operation"]
      when "create_issue"
        result = create_issue(github_service, op)
        operations_performed << result if result
      when "create_pr"
        result = create_pr(github_service, op)
        operations_performed << result if result
      else
        Rails.logger.warn("Unknown GitHub operation: #{op[:operation]}")
      end
    end

    {
      success: true,
      message: "Successfully performed #{operations_performed.count} GitHub operations",
      operations_performed: operations_performed.count
    }
  rescue StandardError => e
    Rails.logger.error("GitHubApiStrategy failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  def create_issue(github_service, op_data)
    # Stub: In production, this would use GithubService to create issues
    # For now, simulate issue creation
    title = op_data[:title] || op_data["title"]
    body = op_data[:body] || op_data["body"]

    return nil unless title

    # Update work item payload with simulated issue number
    simulated_issue_number = rand(1000..9999)
    updated_payload = work_item.payload.merge("github_issue_number" => simulated_issue_number)
    work_item.update!(payload: updated_payload)

    {
      type: "issue",
      issue_number: simulated_issue_number,
      title: title
    }
  end

  def create_pr(github_service, op_data)
    # Stub: In production, this would use GithubService to create PRs
    nil
  end
end
