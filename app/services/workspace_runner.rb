# frozen_string_literal: true

# rubocop:disable Naming/PredicateMethod

require "digest"
require "fileutils"
require "open3"
require "securerandom"
require "shellwords"

# Service to execute agent work in isolated Git workspaces
# Handles full lifecycle: clone, branch, commit, push, PR creation, cleanup
class WorkspaceRunner
  attr_reader :project, :agent, :work_item, :workspace_service, :run

  def initialize(project:, agent:, work_item:)
    @project = project
    @agent = agent
    @work_item = work_item
    @workspace_service = WorkspaceService.new(project)
    @run = nil
  end

  # Execute the work item in an isolated workspace
  #
  # @param changes [Hash] Hash with :message and :files (array of {path:, content:})
  # @return [Boolean] Success status
  def execute(changes:)
    idempotency_key = generate_idempotency_key

    # Check if this exact run has already been executed
    if run_already_executed?(idempotency_key)
      Rails.logger.info("Run already executed with idempotency_key: #{idempotency_key}")
      return true
    end

    # Create run record
    @run = Run.create!(
      agent: agent,
      work_item: work_item,
      started_at: Time.current,
      idempotency_key: idempotency_key
    )

    begin
      # Provision workspace
      workspace_service.provision

      # Get PAT from project configuration
      pat = fetch_project_pat
      return mark_failed("No PAT configured for project") unless pat

      # Clone repository
      unless workspace_service.clone_repository(pat)
        return mark_failed("Failed to clone repository")
      end

      # Create branch with naming convention
      branch_name = generate_branch_name

      # Check if branch already exists and handle idempotency
      if branch_exists_remotely?(branch_name, pat)
        Rails.logger.info("Branch #{branch_name} already exists, updating it")
        unless checkout_and_update_branch(branch_name, pat)
          return mark_failed("Failed to update existing branch")
        end
      else
        # Fetch latest main and create new branch
        unless fetch_and_create_branch(branch_name)
          return mark_failed("Failed to create branch")
        end
      end

      # Apply changes
      unless apply_changes(changes)
        return mark_failed("Failed to apply changes")
      end

      # Commit changes
      commit_message = changes[:message] || "feat: automated agent work"
      unless workspace_service.commit_changes(commit_message)
        return mark_failed("Failed to commit changes")
      end

      # Push branch
      unless push_branch(branch_name, pat)
        return mark_failed("Failed to push branch")
      end

      # Open pull request
      pr_result = open_pull_request(branch_name, changes)
      unless pr_result
        return mark_failed("Failed to create pull request")
      end

      # Mark as successful
      mark_successful(pr_result)
      true
    rescue StandardError => e
      Rails.logger.error("Workspace execution failed: #{e.message}\n#{e.backtrace.join("\n")}")
      mark_failed(e.message)
      false
    ensure
      workspace_service.cleanup
    end
  end

  private

  def generate_idempotency_key
    # Generate key based on work item, agent, and content hash
    content_digest = Digest::SHA256.hexdigest([
      work_item.id,
      work_item.work_type,
      work_item.payload.to_json,
      agent.key
    ].join(":"))

    "run:#{work_item.id}:#{agent.key}:#{content_digest}"
  end

  def run_already_executed?(idempotency_key)
    Run.exists?(idempotency_key: idempotency_key, outcome: "success")
  end

  def fetch_project_pat
    # Fetch PAT from Rails credentials or environment
    # In production, this should use a secure secret management system
    return nil unless project.github_pat_secret_name

    # For now, we'll use Rails credentials
    Rails.application.credentials.dig(:github, :pat) ||
      ENV["GITHUB_PAT"]
  end

  def generate_branch_name
    timestamp = Time.current.strftime("%Y%m%d-%H%M%S")
    # parameterize converts underscores and special chars to hyphens and lowercases
    sanitized_key = agent.key.parameterize(separator: "-")
    "agent/#{sanitized_key}-#{timestamp}"
  end

  def branch_exists_remotely?(branch_name, pat)
    # Validate branch_name to prevent command injection
    return false unless branch_name.match?(%r{\Aagent/[\w-]+\z})

    # Use git ls-remote to check if branch exists
    repo_url = "https://github.com/#{sanitize_repo_name(project.repo_full_name)}.git"

    # Create temporary askpass script for authentication
    askpass_path = File.join(workspace_service.work_dir, "git-askpass-check.sh")
    File.write(askpass_path, "#!/bin/sh\nprintf '%s' #{Shellwords.escape(pat)}\n")
    FileUtils.chmod("+x", askpass_path)

    env = { "GIT_ASKPASS" => askpass_path }

    stdout, _stderr, status = Open3.capture3(
      env,
      "git", "ls-remote", "--heads", repo_url, "refs/heads/#{branch_name}"
    )

    status.success? && !stdout.strip.empty?
  rescue StandardError => e
    Rails.logger.error("Failed to check remote branch: #{e.message}")
    false
  end

  def checkout_and_update_branch(branch_name, pat)
    # Validate branch_name to prevent command injection
    return false unless branch_name.match?(%r{\Aagent/[\w-]+\z})

    repo_path = workspace_service.repo_path

    # Fetch the branch
    _stdout, _stderr, status = Open3.capture3(
      "git", "fetch", "origin", branch_name,
      chdir: repo_path
    )

    return false unless status.success?

    # Checkout the branch
    _stdout, stderr, status = Open3.capture3(
      "git", "checkout", branch_name,
      chdir: repo_path
    )

    return false unless status.success?

    # Merge latest main
    merge_latest_main
  end

  def fetch_and_create_branch(branch_name)
    # Validate branch_name to prevent command injection
    return false unless branch_name.match?(%r{\Aagent/[\w-]+\z})

    repo_path = workspace_service.repo_path
    base_branch = sanitize_branch_name(project.repo_default_branch || "main")

    # Fetch latest from origin
    _stdout, stderr, status = Open3.capture3(
      "git", "fetch", "origin", base_branch,
      chdir: repo_path
    )

    return false unless status.success?

    # Create and checkout new branch from latest origin/main
    _stdout, stderr, status = Open3.capture3(
      "git", "checkout", "-b", branch_name, "origin/#{base_branch}",
      chdir: repo_path
    )

    if status.success?
      true
    else
      Rails.logger.error("Failed to create branch: #{stderr}")
      false
    end
  end

  def merge_latest_main
    repo_path = workspace_service.repo_path
    base_branch = sanitize_branch_name(project.repo_default_branch || "main")

    # Fetch latest main
    _stdout, _stderr, status = Open3.capture3(
      "git", "fetch", "origin", base_branch,
      chdir: repo_path
    )

    return false unless status.success?

    # Merge origin/main into current branch
    _stdout, stderr, status = Open3.capture3(
      "git", "merge", "origin/#{base_branch}",
      chdir: repo_path
    )

    if status.success?
      true
    else
      Rails.logger.error("Failed to merge latest main: #{stderr}")
      false
    end
  end

  def apply_changes(changes)
    return true unless changes[:files]

    repo_path = workspace_service.repo_path

    changes[:files].each do |file_change|
      # Validate file path to prevent directory traversal
      normalized_path = File.expand_path(file_change[:path], repo_path)
      unless normalized_path.start_with?(repo_path)
        Rails.logger.error("Invalid file path: #{file_change[:path]}")
        return false
      end

      # Create directory if it doesn't exist
      FileUtils.mkdir_p(File.dirname(normalized_path))

      # Write file content
      File.write(normalized_path, file_change[:content])
    end

    true
  rescue StandardError => e
    Rails.logger.error("Failed to apply changes: #{e.message}")
    false
  end

  def push_branch(branch_name, pat)
    # Validate branch_name to prevent command injection
    return false unless branch_name.match?(%r{\Aagent/[\w-]+\z})

    repo_path = workspace_service.repo_path

    # Set up authentication using git credential helper
    askpass_path = File.join(workspace_service.work_dir, "git-askpass.sh")
    env = { "GIT_ASKPASS" => askpass_path }

    _stdout, stderr, status = Open3.capture3(
      env,
      "git", "push", "-u", "origin", branch_name,
      chdir: repo_path
    )

    if status.success?
      true
    else
      sanitized_error = stderr
      # Redact PAT itself
      sanitized_error = sanitized_error.gsub(/#{Regexp.escape(pat)}/, "[REDACTED]")
      # Redact PAT in URL form (e.g., https://x-access-token:PAT@github.com)
      sanitized_error = sanitized_error.gsub(%r{https://x-access-token:#{Regexp.escape(pat)}@github\.com}, "https://x-access-token:[REDACTED]@github.com")
      Rails.logger.error("Failed to push branch: #{sanitized_error}")
      false
    end
  end

  def open_pull_request(branch_name, changes)
    pat = fetch_project_pat
    return nil unless pat

    github_service = GithubService.new(project.repo_full_name, pat)

    base_branch = project.repo_default_branch || "main"
    pr_title = changes[:pr_title] || "feat: automated work by #{agent.name}"
    pr_body = changes[:pr_body] || build_default_pr_body

    pr_data = github_service.create_pull_request(
      title: pr_title,
      body: pr_body,
      head: branch_name,
      base: base_branch
    )

    if pr_data
      Rails.logger.info("Created PR ##{pr_data['number']}: #{pr_data['html_url']}")
      pr_data
    else
      nil
    end
  end

  def build_default_pr_body
    description = work_item.payload["description"]

    <<~BODY
      ## Automated Agent Work

      **Agent:** #{agent.name} (#{agent.key})
      **Work Item:** ##{work_item.id}
      **Type:** #{work_item.work_type}

      This PR was automatically generated by the Synorg agent system.

      #{description if description}
    BODY
  end

  def mark_successful(pr_data)
    logs = build_success_logs(pr_data)

    run.update!(
      finished_at: Time.current,
      outcome: "success",
      logs: logs,
      artifacts_url: pr_data&.dig("html_url")
    )
  end

  def mark_failed(error_message)
    logs = build_failure_logs(error_message)

    run.update!(
      finished_at: Time.current,
      outcome: "failure",
      logs: logs
    )

    false
  end

  def build_success_logs(pr_data)
    <<~LOGS
      Workspace execution completed successfully
      Branch created and pushed
      Pull request created: #{pr_data&.dig('html_url') || 'N/A'}
    LOGS
  end

  def build_failure_logs(error_message)
    <<~LOGS
      Workspace execution failed
      Error: #{error_message}
    LOGS
  end

  # Sanitize branch name to prevent command injection
  def sanitize_branch_name(branch_name)
    # Only allow alphanumeric, hyphens, underscores, and slashes
    branch_name.gsub(/[^a-zA-Z0-9\-_\/]/, "")
  end

  # Sanitize repository name to prevent command injection
  def sanitize_repo_name(repo_name)
    # Only allow owner/repo format with alphanumeric, hyphens, underscores
    return nil unless repo_name.match?(%r{\A[\w-]+/[\w-]+\z})
    repo_name
  end
end
