# frozen_string_literal: true

# Issue Agent Service
#
# This service reads work items from the database and creates corresponding
# GitHub issues, maintaining synchronization between the project management
# system and GitHub.
#
# Example usage:
#   service = IssueAgentService.new
#   result = service.run
#   # => { success: true, issues_created: 3, ... }
#
class IssueAgentService
  attr_reader :github_client, :repository

  def initialize(repository: nil, github_token: nil)
    @repository = repository || ENV.fetch("GITHUB_REPOSITORY", "mitchellfyi/synorg")
    @github_token = github_token || ENV["GITHUB_TOKEN"]
  end

  def run
    Rails.logger.info("Issue Agent: Starting GitHub issue creation")

    # Find work items that need GitHub issues
    work_items = WorkItem.tasks.without_github_issue

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
      work_item_ids: created_issues.map { |wi| wi.id },
      issue_numbers: created_issues.map { |wi| wi.github_issue_number },
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

  def read_prompt
    prompt_path = Rails.root.join("agents", "issue", "prompt.md")
    File.read(prompt_path)
  rescue Errno::ENOENT
    Rails.logger.warn("Issue Agent: Prompt file not found at #{prompt_path}")
    nil
  end

  def create_github_issues(work_items)
    # Stub implementation - in production, this would use Octokit
    # to actually create GitHub issues
    work_items.map.with_index do |work_item, index|
      # Simulate creating a GitHub issue
      simulated_issue_number = 1000 + index

      # Update work item with the simulated GitHub issue number
      work_item.update!(github_issue_number: simulated_issue_number)

      Rails.logger.info("Issue Agent: Created issue ##{simulated_issue_number} for work item #{work_item.id}")

      work_item
    end
  end

  def format_issue_body(work_item)
    # Format the issue body with description and acceptance criteria
    <<~MARKDOWN
      ## Description
      #{work_item.description}

      ## Acceptance Criteria
      - [ ] Implementation complete
      - [ ] Tests added
      - [ ] Documentation updated
      - [ ] Code reviewed

      ## Context
      This work item was created by the Product Manager Agent.

      ---

      *Created by Issue Agent on #{Time.current.to_s(:long)}*
      *Work Item ID: #{work_item.id}*
    MARKDOWN
  end

  # Uncomment when ready to integrate with GitHub
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
  #   issue = @github_client.create_issue(
  #     @repository,
  #     work_item.title,
  #     format_issue_body(work_item),
  #     labels: ['task', 'agent-created']
  #   )
  #
  #   work_item.update!(github_issue_number: issue.number)
  #   work_item
  # rescue Octokit::Error => e
  #   Rails.logger.error("Failed to create GitHub issue for work item #{work_item.id}: #{e.message}")
  #   raise
  # end
end
