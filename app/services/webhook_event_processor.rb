# frozen_string_literal: true

# Service to process GitHub webhook events
# Handles issues, pull_request, push, workflow_run, and check_suite events
class WebhookEventProcessor
  attr_reader :project, :event_type, :payload

  def initialize(project, event_type, payload)
    @project = project
    @event_type = event_type
    @payload = payload
  end

  # Process the webhook event based on its type
  #
  # This method returns a boolean indicating success/failure, but it's not a predicate
  # (methods ending in ?) because it performs an action (processing the event).
  # The boolean return value indicates whether processing completed successfully.
  #
  # @return [Boolean] True if processed successfully
  def call
    process
  end

  # Process the webhook event based on its type
  #
  # This method returns a boolean indicating success/failure, but it's not a predicate
  # (methods ending in ?) because it performs an action (processing the event).
  # The boolean return value indicates whether processing completed successfully.
  #
  # @return [Boolean] True if processed successfully
  def process
    case event_type
    when "issues"
      process_issue_event
    when "pull_request"
      process_pull_request_event
    when "push"
      process_push_event
    when "workflow_run"
      process_workflow_run_event
    when "check_suite"
      process_check_suite_event
    else
      Rails.logger.warn("Unsupported webhook event type: #{event_type}")
      false
    end
  end

  # GitHub issue reference patterns
  # Matches common patterns like "Fixes #123", "Closes #456", etc.
  ISSUE_REFERENCE_PATTERN = /
    (?:fix(?:es|ed)?|close(?:s|d)?|resolve(?:s|d)?)
    \s+\#(\d+)
  /ix

  private

  # rubocop:disable Naming/PredicateMethod
  # These methods perform actions (processing events) and return success/failure status,
  # they are not predicate methods despite returning booleans.

  def process_issue_event
    action = payload["action"]
    issue = payload["issue"]

    return false unless issue

    case action
    when "opened", "labeled", "reopened"
      create_or_update_work_item_from_issue(issue)
    when "closed"
      mark_work_item_completed(issue)
    else
      Rails.logger.debug { "Ignoring issue action: #{action}" }
    end

    true
  end

  def process_pull_request_event
    action = payload["action"]
    pull_request = payload["pull_request"]

    return false unless pull_request

    case action
    when "opened"
      create_run_from_pull_request(pull_request)
    when "closed"
      update_run_outcome(pull_request)
    else
      Rails.logger.debug { "Ignoring pull request action: #{action}" }
    end

    true
  end

  def process_push_event
    # Push events can be used for triggering builds or other workflows
    # For now, we'll just log them
    Rails.logger.info("Received push event for ref: #{payload['ref']}")
    true
  end

  def process_workflow_run_event
    action = payload["action"]
    workflow_run = payload["workflow_run"]

    return false unless workflow_run

    if action == "completed"
      update_run_from_workflow(workflow_run)
    end

    true
  end

  def process_check_suite_event
    action = payload["action"]
    check_suite = payload["check_suite"]

    return false unless check_suite

    if action == "completed"
      update_run_from_check_suite(check_suite)
    end

    true
  end

  def create_or_update_work_item_from_issue(issue)
    issue_number = issue["number"]
    return unless issue_number

    # Use PostgreSQL JSON query to find existing work item
    # Standardize on github_issue_number key
    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'github_issue_number' = ? OR payload->>'issue_number' = ?", issue_number.to_s, issue_number.to_s)
      .first_or_initialize

    work_item.payload = (work_item.payload || {}).merge({
      github_issue_number: issue["number"],
      github_issue_url: issue["html_url"],
      title: issue["title"],
      body: issue["body"],
      labels: issue["labels"]&.pluck("name") || [],
      state: issue["state"]
    })

    work_item.status = issue["state"] == "open" ? "pending" : "completed"

    work_item.save!
    work_item
  end

  def mark_work_item_completed(issue)
    issue_number = issue["number"]
    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'github_issue_number' = ? OR payload->>'issue_number' = ?", issue_number.to_s, issue_number.to_s)
      .first

    return unless work_item

    work_item.update!(status: "completed")
  end

  def create_run_from_pull_request(pull_request)
    # Find the associated work item from the PR body or linked issue
    issue_number = extract_issue_number_from_pr(pull_request)

    return unless issue_number

    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'github_issue_number' = ? OR payload->>'issue_number' = ?", issue_number.to_s, issue_number.to_s)
      .first

    return unless work_item
    return unless work_item.assigned_agent

    pr_number = pull_request["number"]
    pr_head_sha = pull_request["head"]&.dig("sha")

    # Find existing run or create new one, handling potential race conditions
    # Try to find by PR number first (most reliable)
    run = work_item.runs.find_by(github_pr_number: pr_number) if pr_number

    unless run
      begin
        run = work_item.runs.find_or_create_by!(agent: work_item.assigned_agent) do |r|
          r.started_at = Time.current
        end
      rescue ActiveRecord::RecordNotUnique
        # If a duplicate is attempted due to race, fetch the existing run
        run = work_item.runs.find_by(agent: work_item.assigned_agent)
      end
    end

    # Update run with PR information
    update_hash = {
      logs_url: pull_request["html_url"],
      artifacts_url: pull_request["html_url"]
    }
    update_hash[:github_pr_number] = pr_number if pr_number
    update_hash[:github_pr_head_sha] = pr_head_sha if pr_head_sha

    run.update!(update_hash)

    run
  end

  def update_run_outcome(pull_request)
    pr_number = pull_request["number"]
    pr_head_sha = pull_request["head"]&.dig("sha")

    # Find run by PR number (most reliable)
    run = Run.find_by(github_pr_number: pr_number) if pr_number

    # Fall back to head SHA if PR number not found
    run ||= Run.find_by(github_pr_head_sha: pr_head_sha) if pr_head_sha

    # Fall back to issue-based lookup
    unless run
      issue_number = extract_issue_number_from_pr(pull_request)
      return unless issue_number

      work_item = project.work_items
        .where(work_type: "issue")
        .where("payload->>'github_issue_number' = ? OR payload->>'issue_number' = ?", issue_number.to_s, issue_number.to_s)
        .first

      return unless work_item

      # Find by PR URL
      pr_url = pull_request["html_url"]
      run = work_item.runs.find_by(logs_url: pr_url)

      # Last resort: most recent run
      run ||= work_item.runs.order(created_at: :desc).first
    end

    return unless run

    outcome = pull_request["merged"] ? "success" : "failure"
    run.update!(
      outcome: outcome,
      finished_at: Time.current
    )

    # Mark work item as completed if PR was merged
    if pull_request["merged"]
      work_item = run.work_item
      work_item.update!(status: "completed")
    end
  end

  def update_run_from_workflow(workflow_run)
    # Find run by PR number or head SHA from workflow run
    pull_requests = workflow_run["pull_requests"] || []
    head_sha = workflow_run["head_sha"] || workflow_run["head_commit"]&.dig("id")

    run = nil

    # Try to find by PR number first
    pull_requests.each do |pr|
      pr_number = pr["number"]
      next unless pr_number

      run = Run.find_by(github_pr_number: pr_number)
      break if run
    end

    # Fall back to head SHA
    run ||= Run.find_by(github_pr_head_sha: head_sha) if head_sha

    # Last resort: try logs_url matching
    unless run
      logs_url = workflow_run["html_url"]
      run = Run.find_by(logs_url: logs_url) if logs_url
    end

    return unless run

    conclusion = workflow_run["conclusion"]
    outcome = case conclusion
    when "success"
      "success"
    when "failure", "timed_out", "cancelled"
      "failure"
    else
      nil
    end

    # Store check suite ID if available
    update_hash = {
      outcome: outcome,
      finished_at: workflow_run["updated_at"] ? Time.iso8601(workflow_run["updated_at"]) : Time.current
    }
    update_hash[:github_check_suite_id] = workflow_run["check_suite_id"] if workflow_run["check_suite_id"]

    run.update!(update_hash)
  end

  def update_run_from_check_suite(check_suite)
    # Check suites are GitHub's way of grouping related checks
    # We link runs to check suites via the PR head SHA or commit SHA
    conclusion = check_suite["conclusion"]
    head_sha = check_suite["head_sha"]
    check_suite_id = check_suite["id"]
    pull_requests = check_suite["pull_requests"] || []

    Rails.logger.info(
      "Check suite #{check_suite_id} completed: " \
      "conclusion=#{conclusion}, head_sha=#{head_sha}"
    )

    run = nil

    # Try to find run via PR number (most reliable)
    pull_requests.each do |pr|
      pr_number = pr["number"]
      next unless pr_number

      run = Run.find_by(github_pr_number: pr_number)
      break if run
    end

    # Fall back to head SHA
    run ||= Run.find_by(github_pr_head_sha: head_sha) if head_sha

    # Fall back to check suite ID (if we've stored it before)
    run ||= Run.find_by(github_check_suite_id: check_suite_id) if check_suite_id

    return unless run

    outcome = case conclusion
    when "success"
      "success"
    when "failure", "timed_out", "cancelled"
      "failure"
    else
      nil
    end

    run.update!(
      github_check_suite_id: check_suite_id,
      outcome: outcome,
      finished_at: check_suite["updated_at"] ? Time.iso8601(check_suite["updated_at"]) : Time.current
    )

    true
  end
  # rubocop:enable Naming/PredicateMethod

  def extract_issue_number_from_pr(pull_request)
    body = pull_request["body"] || ""

    # Look for common issue reference patterns
    match = body.match(ISSUE_REFERENCE_PATTERN)

    match ? match[1].to_i : nil
  end
end
