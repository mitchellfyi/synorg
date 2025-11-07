# frozen_string_literal: true

# Dev Tooling Agent Service
#
# This service monitors the repository for missing or outdated development
# tooling, CI configuration, testing frameworks, and quality gates.
#
# Example usage:
#   service = DevToolingAgentService.new
#   result = service.run
#   # => { success: true, issues_created: 2, ... }
#
class DevToolingAgentService
  attr_reader :repository, :github_token

  def initialize(repository: nil, github_token: nil)
    @repository = repository || ENV.fetch("GITHUB_REPOSITORY", "mitchellfyi/synorg")
    @github_token = github_token || ENV["GITHUB_TOKEN"]
  end

  def run
    Rails.logger.info("Dev Tooling Agent: Starting repository audit")

    # Stub: In production, this would call an LLM API with the prompt to analyze repository
    # Audit the repository for issues
    audit_results = audit_repository

    # Generate recommendations
    recommendations = generate_recommendations(audit_results)

    # Stub: In production, this would create GitHub issues or PRs
    # For now, log the recommendations
    log_recommendations(recommendations)

    Rails.logger.info("Dev Tooling Agent: Identified #{recommendations.count} recommendations")

    {
      success: true,
      recommendations_count: recommendations.count,
      recommendations: recommendations,
      message: "Repository audit complete with #{recommendations.count} recommendations"
    }
  rescue StandardError => e
    Rails.logger.error("Dev Tooling Agent failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  # Future: When integrating with LLM, read prompt file here
  # def read_prompt
  #   prompt_path = Rails.root.join("agents", "dev_tooling", "prompt.md")
  #   File.read(prompt_path)
  # rescue Errno::ENOENT
  #   Rails.logger.warn("Dev Tooling Agent: Prompt file not found at #{prompt_path}")
  #   nil
  # end

  def audit_repository
    # Stub implementation - in production, this would do comprehensive audits
    results = {
      has_playwright: File.exist?(Rails.root.join("playwright.config.ts")),
      has_simplecov: File.read(Rails.root.join("Gemfile")).include?("simplecov"),
      has_lefthook: File.exist?(Rails.root.join("lefthook.yml")),
      rubocop_version: check_rubocop_config,
      ci_config: check_ci_config
    }

    Rails.logger.info("Dev Tooling Agent: Audit results - #{results}")
    results
  end

  def check_rubocop_config
    # Check if RuboCop is configured with GitHub preset
    rubocop_yml = Rails.root.join(".rubocop.yml")
    return :missing unless File.exist?(rubocop_yml)

    content = File.read(rubocop_yml)
    if content.include?("rubocop-github")
      :github_preset
    else
      :basic
    end
  end

  def check_ci_config
    # Check for GitHub Actions workflow files
    workflows_dir = Rails.root.join(".github", "workflows")
    return :missing unless Dir.exist?(workflows_dir)

    workflows = Dir.glob(workflows_dir.join("*.yml"))
    {
      count: workflows.count,
      has_ci: workflows.any? { |f| File.read(f).include?("rspec") }
    }
  end

  def generate_recommendations(audit_results)
    recommendations = []

    # Check for Playwright
    unless audit_results[:has_playwright]
      recommendations << {
        title: "Add Playwright for end-to-end browser testing",
        priority: "high",
        category: "testing",
        description: "The project lacks end-to-end browser testing. Playwright would provide comprehensive E2E test coverage."
      }
    end

    # Check for SimpleCov
    unless audit_results[:has_simplecov]
      recommendations << {
        title: "Add SimpleCov for test coverage tracking",
        priority: "medium",
        category: "testing",
        description: "Test coverage is not being tracked. SimpleCov would provide visibility into code coverage."
      }
    end

    # Check RuboCop configuration
    if audit_results[:rubocop_version] == :basic
      recommendations << {
        title: "Upgrade RuboCop configuration with GitHub preset",
        priority: "medium",
        category: "linting",
        description: "RuboCop is using basic configuration. The GitHub preset provides more comprehensive style checking."
      }
    end

    recommendations
  end

  def log_recommendations(recommendations)
    recommendations.each do |rec|
      Rails.logger.info("Dev Tooling Agent Recommendation: [#{rec[:priority].upcase}] #{rec[:title]}")
      Rails.logger.info("  Category: #{rec[:category]}")
      Rails.logger.info("  Description: #{rec[:description]}")
    end
  end

  # Uncomment when ready to integrate with GitHub
  # def create_github_issues(recommendations)
  #   require 'octokit'
  #
  #   unless @github_token
  #     raise "GitHub token not configured. Set GITHUB_TOKEN environment variable."
  #   end
  #
  #   client = Octokit::Client.new(access_token: @github_token)
  #
  #   recommendations.map do |rec|
  #     issue = client.create_issue(
  #       @repository,
  #       rec[:title],
  #       format_issue_body(rec),
  #       labels: ['dev-tooling', rec[:category]]
  #     )
  #
  #     Rails.logger.info("Created issue ##{issue.number}: #{rec[:title]}")
  #     issue
  #   rescue Octokit::Error => e
  #     Rails.logger.error("Failed to create issue: #{e.message}")
  #     nil
  #   end.compact
  # end
  #
  # def format_issue_body(recommendation)
  #   <<~MARKDOWN
  #     ## Priority
  #     #{recommendation[:priority].upcase}
  #
  #     ## Category
  #     #{recommendation[:category]}
  #
  #     ## Description
  #     #{recommendation[:description]}
  #
  #     ---
  #
  #     *Created by Dev Tooling Agent on #{Time.current.to_s(:long)}*
  #   MARKDOWN
  # end
end
