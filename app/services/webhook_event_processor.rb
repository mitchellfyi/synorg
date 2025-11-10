# frozen_string_literal: true

# rubocop:disable Naming/PredicateMethod

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
      Rails.logger.debug("Ignoring issue action: #{action}")
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
      Rails.logger.debug("Ignoring pull request action: #{action}")
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
    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'issue_number' = ?", issue_number.to_s)
      .first_or_initialize

    work_item.payload = (work_item.payload || {}).merge({
      issue_number: issue["number"],
      title: issue["title"],
      body: issue["body"],
      labels: issue["labels"]&.map { |l| l["name"] } || [],
      state: issue["state"],
      html_url: issue["html_url"]
    })

    work_item.status = issue["state"] == "open" ? "pending" : "completed"

    work_item.save!
    work_item
  end

  def mark_work_item_completed(issue)
    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'issue_number' = ?", issue["number"].to_s)
      .first

    return unless work_item

    work_item.update!(status: "completed")
  end

  def create_run_from_pull_request(pull_request)
    # Find the associated work item from the PR body or linked issue
    # For now, we'll look for issue references in the PR body
    issue_number = extract_issue_number_from_pr(pull_request)

    return unless issue_number

    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'issue_number' = ?", issue_number.to_s)
      .first

    return unless work_item
    return unless work_item.assigned_agent

    # Find existing run or create new one, handling potential race conditions
    begin
      run = work_item.runs.find_or_create_by!(agent: work_item.assigned_agent) do |r|
        r.started_at = Time.current
      end
    rescue ActiveRecord::RecordNotUnique
      # If a duplicate is attempted due to race, fetch the existing run
      run = work_item.runs.find_by(agent: work_item.assigned_agent)
    end

    run.update!(
      logs_url: pull_request["html_url"]
    )

    run
  end

  def update_run_outcome(pull_request)
    issue_number = extract_issue_number_from_pr(pull_request)

    return unless issue_number

    work_item = project.work_items
      .where(work_type: "issue")
      .where("payload->>'issue_number' = ?", issue_number.to_s)
      .first

    return unless work_item

    # Find the run associated with this PR by matching the logs_url
    # which was set to the PR URL when the run was created
    pr_url = pull_request["html_url"]
    run = work_item.runs.find_by(logs_url: pr_url)

    # If no run found by URL, fall back to the most recent run
    # This handles cases where the run was created before the PR was opened
    run ||= work_item.runs.order(created_at: :desc).first

    return unless run

    outcome = pull_request["merged"] ? "success" : "failure"
    run.update!(
      outcome: outcome,
      finished_at: Time.current
    )

    # Mark work item as completed if PR was merged
    work_item.update!(status: "completed") if pull_request["merged"]
  end

  def update_run_from_workflow(workflow_run)
    # Find runs by logs_url or other identifier
    # This is a simplified implementation
    conclusion = workflow_run["conclusion"]
    logs_url = workflow_run["html_url"]

    run = Run.find_by(logs_url: logs_url)

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
      outcome: outcome,
      finished_at: workflow_run["updated_at"] ? Time.iso8601(workflow_run["updated_at"]) : Time.current
    )
  end

  def update_run_from_check_suite(check_suite)
    # Check suites are GitHub's way of grouping related checks
    # For now, we just log them as the mapping to runs is complex
    # In production, you'd need a strategy to link check suites to runs
    # (e.g., via PR head SHA, commit SHA, or check suite metadata)
    conclusion = check_suite["conclusion"]
    head_sha = check_suite["head_sha"]

    Rails.logger.info(
      "Check suite #{check_suite['id']} completed: " \
      "conclusion=#{conclusion}, head_sha=#{head_sha}"
    )

    # TODO: Implement run linking strategy when requirements are clearer
    # Possible approaches:
    # 1. Add head_sha field to runs table
    # 2. Link via pull request association
    # 3. Store check suite ID in run metadata
    true
  end

  def extract_issue_number_from_pr(pull_request)
    body = pull_request["body"] || ""

    # Look for common issue reference patterns
    match = body.match(ISSUE_REFERENCE_PATTERN)

    match ? match[1].to_i : nil
  end
end
