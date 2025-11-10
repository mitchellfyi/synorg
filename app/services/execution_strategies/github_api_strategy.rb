# frozen_string_literal: true

require "net/http"
require "json"
require "base64"
require "securerandom"

# Execution Strategy for agents that interact with GitHub API
# Handles agents that create GitHub issues, PRs, and file changes
# All code changes are done via GitHub API - GitHub Copilot handles the actual implementation
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
    pr_info = nil

    operations.each do |op|
      case op[:operation] || op["operation"]
      when "create_issue"
        result = create_issue(github_service, op)
        operations_performed << result if result
      when "create_pr"
        result = create_pr(github_service, op)
        operations_performed << result if result
        pr_info = result if result && result[:type] == "pull_request"
      when "create_files_and_pr"
        result = create_files_and_pr(github_service, op)
        operations_performed << result if result
        pr_info = result if result && result[:type] == "pull_request"
      else
        Rails.logger.warn("Unknown GitHub operation: #{op[:operation]}")
      end
    end

    result_hash = {
      success: true,
      message: "Successfully performed #{operations_performed.count} GitHub operations",
      operations_performed: operations_performed.count
    }

    # Include PR info if a PR was created
    result_hash[:pr_info] = pr_info if pr_info

    result_hash
  rescue StandardError => e
    Rails.logger.error("GitHubApiStrategy failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  def create_issue(github_service, op_data)
    title = op_data[:title] || op_data["title"]
    labels = op_data[:labels] || op_data["labels"] || ["agent-created"]

    return nil unless title

    # Build issue body with work item context
    issue_body = op_data[:body] || op_data["body"] || build_issue_body(op_data)

    # Use GitHub API to create issue
    uri = URI("https://api.github.com/repos/#{project.repo_full_name}/issues")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{project.github_pat}"
    request["Accept"] = "application/vnd.github.v3+json"
    request["Content-Type"] = "application/json"
    request.body = {
      title: title,
      body: issue_body,
      labels: labels
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error("Failed to create issue: #{response.code} - #{response.body}")
      return nil
    end

    issue = JSON.parse(response.body)

    # Assign issue to Copilot
    assignment_result = github_service.assign_issue_to_copilot(issue["number"])
    if assignment_result.nil?
      Rails.logger.warn("Failed to assign issue #{issue['number']} to Copilot - Copilot may not be available")
    end

    # Update work item payload with issue number
    updated_payload = work_item.payload.merge(
      "github_issue_number" => issue["number"],
      "github_issue_url" => issue["html_url"]
    )
    work_item.update!(payload: updated_payload)

    {
      type: "issue",
      issue_number: issue["number"],
      title: title,
      url: issue["html_url"],
      labels: labels
    }
  rescue StandardError => e
    Rails.logger.error("Failed to create issue: #{e.message}")
    nil
  end

  def create_pr(github_service, op_data)
    title = op_data[:title] || op_data["pr_title"] || op_data["title"]
    body = op_data[:body] || op_data["pr_body"] || op_data["body"]
    head = op_data[:head] || op_data["head"]
    base = op_data[:base] || op_data["base"] || project.repo_default_branch || "main"

    return nil unless title && head

    # Enhance PR title with work item title if available
    if work_item.payload["title"].present? && title.exclude?(work_item.payload["title"])
      title = "#{title}: #{work_item.payload['title']}"
    end

    pr = github_service.create_pull_request(
      title: title,
      body: body,
      head: head,
      base: base
    )

    return nil unless pr

    # Get PR head SHA
    pr_head_sha = pr["head"]&.dig("sha")

    # Update work item payload with PR information
    updated_payload = work_item.payload.merge(
      "github_pr_number" => pr["number"],
      "github_pr_url" => pr["html_url"]
    )
    work_item.update!(payload: updated_payload)

    {
      type: "pull_request",
      pr_number: pr["number"],
      pr_head_sha: pr_head_sha,
      title: title,
      url: pr["html_url"]
    }
  rescue StandardError => e
    Rails.logger.error("Failed to create PR: #{e.message}")
    nil
  end

  # Create files in a new branch and open a PR
  # This replaces the workspace functionality - files are created directly via GitHub API
  def create_files_and_pr(github_service, op_data)
    files = op_data[:files] || op_data["files"] || []
    pr_title = op_data[:pr_title] || op_data["title"] || "feat: automated work by #{agent.name}"
    pr_body = op_data[:pr_body] || op_data["body"] || build_default_pr_body
    base_branch = op_data[:base] || op_data["base"] || project.repo_default_branch || "main"

    return nil if files.empty?

    # Generate branch name
    branch_name = "agent/#{agent.key}-#{SecureRandom.hex(8)}"

    # Get base branch SHA
    base_sha = github_service.get_branch_sha(base_branch)
    return nil unless base_sha

    # Create branch
    unless create_branch(branch_name, base_sha)
      return nil
    end

    # Create files via GitHub API
    files_created = []
    files.each do |file_data|
      path = file_data[:path] || file_data["path"]
      content = file_data[:content] || file_data["content"]
      next unless path && content

      if create_file_in_branch(branch_name, path, content)
        files_created << path
      end
    end

    return nil if files_created.empty?

    # Create PR
    pr = github_service.create_pull_request(
      title: pr_title,
      body: pr_body,
      head: branch_name,
      base: base_branch
    )

    return nil unless pr

    # Get PR head SHA
    pr_head_sha = pr["head"]&.dig("sha")

    # Enhance PR title with work item title if available
    if work_item.payload["title"].present? && pr_title.exclude?(work_item.payload["title"])
      pr_title = "#{pr_title}: #{work_item.payload['title']}"
      # Update PR title if we enhanced it
      # Note: We could update the PR via API, but for now we'll just use the enhanced title in our records
    end

    # Update work item payload with PR information
    updated_payload = work_item.payload.merge(
      "github_pr_number" => pr["number"],
      "github_pr_url" => pr["html_url"],
      "github_branch" => branch_name,
      "files_created" => files_created
    )
    work_item.update!(payload: updated_payload)

    {
      type: "pull_request",
      pr_number: pr["number"],
      pr_head_sha: pr_head_sha,
      title: pr_title,
      url: pr["html_url"],
      branch: branch_name,
      files_created: files_created
    }
  rescue StandardError => e
    Rails.logger.error("Failed to create files and PR: #{e.message}")
    nil
  end

  def get_branch_sha(branch_name)
    uri = URI("https://api.github.com/repos/#{project.repo_full_name}/git/ref/heads/#{branch_name}")
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{project.github_pat}"
    request["Accept"] = "application/vnd.github.v3+json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data["object"]["sha"]
    else
      Rails.logger.error("Failed to get branch SHA: #{response.code} - #{response.body}")
      nil
    end
  rescue StandardError => e
    Rails.logger.error("Failed to get branch SHA: #{e.message}")
    nil
  end

  def create_branch(branch_name, base_sha)
    uri = URI("https://api.github.com/repos/#{project.repo_full_name}/git/refs")
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{project.github_pat}"
    request["Accept"] = "application/vnd.github.v3+json"
    request["Content-Type"] = "application/json"
    request.body = {
      ref: "refs/heads/#{branch_name}",
      sha: base_sha
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess) || response.code == "422" # 422 means branch already exists
      true
    else
      Rails.logger.error("Failed to create branch: #{response.code} - #{response.body}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Failed to create branch: #{e.message}")
    false
  end

  def create_file_in_branch(branch_name, path, content)
    uri = URI("https://api.github.com/repos/#{project.repo_full_name}/contents/#{path}")
    request = Net::HTTP::Put.new(uri)
    request["Authorization"] = "Bearer #{project.github_pat}"
    request["Accept"] = "application/vnd.github.v3+json"
    request["Content-Type"] = "application/json"

    # Get existing file SHA if it exists (for updates)
    existing_sha = get_file_sha(path, branch_name)

    request_body = {
      message: "feat: #{agent.name} - #{path}",
      content: Base64.strict_encode64(content),
      branch: branch_name
    }
    request_body[:sha] = existing_sha if existing_sha
    request.body = request_body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      true
    else
      Rails.logger.error("Failed to create file #{path}: #{response.code} - #{response.body}")
      false
    end
  rescue StandardError => e
    Rails.logger.error("Failed to create file #{path}: #{e.message}")
    false
  end

  def get_file_sha(path, branch_name)
    uri = URI("https://api.github.com/repos/#{project.repo_full_name}/contents/#{path}")
    uri.query = URI.encode_www_form(ref: branch_name)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{project.github_pat}"
    request["Accept"] = "application/vnd.github.v3+json"

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      data["sha"]
    else
      nil # File doesn't exist, which is fine for new files
    end
  rescue StandardError
    nil
  end

  def build_default_pr_body
    description = work_item.payload["description"] || work_item.payload["title"] || ""
    issue_number = work_item.payload["github_issue_number"]

    parts = []
    parts << description if description.present?

    # Add issue reference if available
    if issue_number
      parts << "\n\nFixes ##{issue_number}"
    end

    parts << "\n\n---"
    parts << "\n\nThis PR was automatically created by #{agent.name}."
    parts << "\n\nGitHub Copilot will handle the code review and implementation."
    parts.join("\n")
  end

  def build_issue_body(op_data)
    parts = []

    # Add description from work item or operation data
    description = op_data[:description] || op_data["description"] ||
                  work_item.payload["description"] ||
                  work_item.payload["title"] || ""
    parts << description if description.present?

    # Add acceptance criteria if available
    acceptance_criteria = op_data[:acceptance_criteria] || op_data["acceptance_criteria"] ||
                          work_item.payload["acceptance_criteria"]
    if acceptance_criteria.present?
      parts << "\n\n## Acceptance Criteria"
      if acceptance_criteria.is_a?(Array)
        acceptance_criteria.each do |criterion|
          parts << "\n- #{criterion}"
        end
      else
        parts << "\n#{acceptance_criteria}"
      end
    end

    # Add work item context
    parts << "\n\n---"
    parts << "\n\n**Work Item ID**: ##{work_item.id}"
    parts << "\n**Agent**: #{agent.name}"
    parts << "\n**Project**: #{project.name || project.slug}"

    parts.join("\n")
  end
end
