# frozen_string_literal: true

require "fileutils"
require "open3"

# Service to manage temporary workspaces for agents
# Handles Git operations: clone, branch, commit, push, PR creation
class WorkspaceService
  attr_reader :project, :work_dir

  def initialize(project)
    @project = project
    @work_dir = nil
  end

  # Provision a temporary working directory for the project
  #
  # @return [String] Path to the workspace directory
  def provision
    @work_dir = File.join(Dir.tmpdir, "synorg-workspace-#{SecureRandom.hex(16)}")
    FileUtils.mkdir_p(@work_dir)
    @work_dir
  end

  # Clone the repository using the PAT
  #
  # @param pat [String] Personal Access Token for authentication
  # @return [Boolean] Success status
  # rubocop:disable Naming/PredicateMethod
  # Note: Method returns boolean but is named as action verb (clone) not predicate (cloned?)
  # This is intentional as it performs an action and returns success status
  def clone_repository(pat)
    return false unless project.repo_full_name

    # Note: PAT is used in URL for Git authentication. Git commands are run with
    # chdir option to avoid exposing in shell history. Consider using Git credential
    # helpers in production for additional security.
    repo_url = "https://#{pat}@github.com/#{project.repo_full_name}.git"
    branch = project.repo_default_branch || "main"

    _stdout, stderr, status = Open3.capture3(
      "git", "clone",
      "--branch", branch,
      "--depth", "1",
      repo_url,
      "repo",
      chdir: @work_dir
    )

    unless status.success?
      # stderr may contain repo URL, so we sanitize before logging
      sanitized_error = stderr.gsub(/#{Regexp.escape(pat)}/, "[REDACTED]")
      Rails.logger.error("Failed to clone repository: #{sanitized_error}")
      return false
    end

    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Create a new branch
  #
  # @param branch_name [String] Name of the branch to create
  # @return [Boolean] Success status
  # rubocop:disable Naming/PredicateMethod
  # Note: Method returns boolean but is named as action verb (create) not predicate (created?)
  # This is intentional as it performs an action and returns success status
  def create_branch(branch_name)
    _stdout, stderr, status = Open3.capture3(
      "git", "checkout", "-b", branch_name,
      chdir: repo_path
    )

    unless status.success?
      Rails.logger.error("Failed to create branch: #{stderr}")
      return false
    end

    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Commit changes
  #
  # @param message [String] Commit message
  # @return [Boolean] Success status
  # rubocop:disable Naming/PredicateMethod
  # Note: Method returns boolean but is named as action verb (commit) not predicate (committed?)
  # This is intentional as it performs an action and returns success status
  def commit_changes(message)
    # Add all changes
    _stdout, _stderr, status = Open3.capture3(
      "git", "add", ".",
      chdir: repo_path
    )

    return false unless status.success?

    # Commit
    _stdout, stderr, status = Open3.capture3(
      "git", "commit", "-m", message,
      chdir: repo_path
    )

    unless status.success?
      Rails.logger.error("Failed to commit changes: #{stderr}")
      return false
    end

    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Push branch to remote
  #
  # @param branch_name [String] Name of the branch to push
  # @return [Boolean] Success status
  # rubocop:disable Naming/PredicateMethod
  # Note: Method returns boolean but is named as action verb (push) not predicate (pushed?)
  # This is intentional as it performs an action and returns success status
  def push_branch(branch_name)
    _stdout, stderr, status = Open3.capture3(
      "git", "push", "origin", branch_name,
      chdir: repo_path
    )

    unless status.success?
      Rails.logger.error("Failed to push branch: #{stderr}")
      return false
    end

    true
  end
  # rubocop:enable Naming/PredicateMethod

  # Open a pull request (stub - delegates to GithubService)
  #
  # @param branch_name [String] Source branch name
  # @param title [String] PR title
  # @param body [String] PR body
  # @return [Hash, nil] PR data or nil
  def open_pull_request(branch_name, title:, body:)
    # Stub: Will be implemented via GithubService
    # GithubService.create_pull_request(...)
    Rails.logger.info("Stub: Would create PR from #{branch_name} with title: #{title}")
    nil
  end

  # Clean up the workspace
  def cleanup
    return unless @work_dir && File.directory?(@work_dir)

    FileUtils.rm_rf(@work_dir)
    @work_dir = nil
  end

  private

  def repo_path
    File.join(@work_dir, "repo")
  end
end
