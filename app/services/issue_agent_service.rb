# frozen_string_literal: true

# Issue Agent Service
#
# This service reads work items from the database and creates corresponding
# GitHub issues, maintaining synchronization between the project management
# system and GitHub.
#
# Example usage:
#   project = Project.find_by(slug: "my-project")
#   service = IssueAgentService.new(project)
#   result = service.run
#   # => { success: true, issues_created: 3, ... }
#
class IssueAgentService
  attr_reader :project, :repository, :github_token

  def initialize(project, repository: nil, github_token: nil)
    @project = project
    @repository = repository || ENV.fetch("GITHUB_REPOSITORY", "mitchellfyi/synorg")
    @github_token = github_token || ENV["GITHUB_TOKEN"]
  end

  def run
    Rails.logger.info("Issue Agent: Starting GitHub issue creation for project #{project.slug}")

    # Find work items that need GitHub issues (those with work_type=task and no GitHub issue)
    work_items = project.work_items.where(work_type: "task").where("payload->>'github_issue_number' IS NULL")

    if work_items.empty?
      Rails.logger.info("Issue Agent: No work items found that need GitHub issues")
      return {
        success: true,
        issues_created: 0,
        message: "No work items to create issues for"
      }
    end

    # Stub: In production, this would use Octokit to create GitHub issues
    # For now, simulate issue creation
    created_issues = create_github_issues(work_items)

    Rails.logger.info("Issue Agent: Created #{created_issues.count} GitHub issues")

    {
      success: true,
      issues_created: created_issues.count,
      work_item_ids: created_issues.map(&:id),
      issue_numbers: created_issues.map { |wi| wi.payload["github_issue_number"] },
      message: "Successfully created #{created_issues.count} GitHub issues"
    }
  rescue StandardError => e
    Rails.logger.error("Issue Agent failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  def create_github_issues(work_items)
    # Stub implementation - in production, this would use Octokit
    # to actually create GitHub issues
    work_items.map.with_index do |work_item, index|
      # Simulate creating a GitHub issue
      simulated_issue_number = 1000 + index

      # Update work item payload with the simulated GitHub issue number
      updated_payload = work_item.payload.merge("github_issue_number" => simulated_issue_number)
      work_item.update!(payload: updated_payload)

      Rails.logger.info("Issue Agent: Created issue ##{simulated_issue_number} for work item #{work_item.id}")

      work_item
    end
  end

  # Future: Uncomment when ready to integrate with GitHub
  # def format_issue_body(work_item)
  #   title = work_item.payload["title"] || "Work Item #{work_item.id}"
  #   description = work_item.payload["description"] || "No description provided"
  #
  #   <<~MARKDOWN
  #     ## Description
  #     #{description}
  #
  #     ## Acceptance Criteria
  #     - [ ] Implementation complete
  #     - [ ] Tests added
  #     - [ ] Documentation updated
  #     - [ ] Code reviewed
  #
  #     ## Context
  #     This work item was created by the Product Manager Agent.
  #
  #     ---
  #
  #     *Created by Issue Agent*
  #     *Work Item ID: #{work_item.id}*
  #   MARKDOWN
  # end
  #
  # def setup_github_client
  #   require 'octokit'
  #
  #   unless @github_token
  #     raise "GitHub token not configured. Set GITHUB_TOKEN environment variable."
  #   end
  #
  #   @github_client = Octokit::Client.new(access_token: @github_token)
  # end
  #
  # def create_real_github_issue(work_item)
  #   title = work_item.payload["title"] || "Work Item #{work_item.id}"
  #
  #   issue = @github_client.create_issue(
  #     @repository,
  #     title,
  #     format_issue_body(work_item),
  #     labels: ['task', 'agent-created']
  #   )
  #
  #   updated_payload = work_item.payload.merge("github_issue_number" => issue.number)
  #   work_item.update!(payload: updated_payload)
  #   work_item
  # rescue Octokit::Error => e
  #   Rails.logger.error("Failed to create GitHub issue for work item #{work_item.id}: #{e.message}")
  #   raise
  # end
end
