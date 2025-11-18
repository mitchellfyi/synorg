# frozen_string_literal: true

# Model for audit logs
# Captures all security-relevant events including webhooks, assignments, runs, and violations
class AuditLog < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :event_type, presence: true
  validates :status, presence: true

  # Event types
  WEBHOOK_RECEIVED = "webhook.received"
  WEBHOOK_INVALID_SIGNATURE = "webhook.invalid_signature"
  WEBHOOK_MISSING_SIGNATURE = "webhook.missing_signature"
  WEBHOOK_RATE_LIMITED = "webhook.rate_limited"
  WORK_ITEM_ASSIGNED = "work_item.assigned"
  WORK_ITEM_CLAIMED = "work_item.claimed"
  RUN_STARTED = "run.started"
  RUN_FINISHED = "run.finished"
  RUN_FAILED = "run.failed"

  # Statuses
  STATUS_SUCCESS = "success"
  STATUS_FAILED = "failed"
  STATUS_BLOCKED = "blocked"

  scope :recent, -> { order(created_at: :desc) }
  scope :by_event_type, ->(event_type) { where(event_type: event_type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :security_events, -> { where(event_type: [WEBHOOK_INVALID_SIGNATURE, WEBHOOK_MISSING_SIGNATURE, WEBHOOK_RATE_LIMITED]) }
  scope :webhook_events, -> { where("event_type LIKE ?", "webhook.%") }
  scope :run_events, -> { where("event_type LIKE ?", "run.%") }
  scope :work_item_events, -> { where("event_type LIKE ?", "work_item.%") }

  # Sanitize payload excerpt to never contain secrets
  # Remove common secret patterns from the payload
  def sanitized_payload_excerpt
    return nil if payload_excerpt.blank?

    sanitized = payload_excerpt.dup
    # Remove potential tokens, secrets, and credentials
    sanitized.gsub!(/["']?(?:token|secret|password|api_key|auth|credential)["']?\s*[:=]\s*["'][^"']+["']/i, '"***REDACTED***"')
    sanitized.gsub!(/Bearer\s+[A-Za-z0-9\-._~+\/]+=*/i, "Bearer ***REDACTED***")
    sanitized.gsub!(/ghp_[A-Za-z0-9]{36}/i, "***REDACTED***")
    sanitized.gsub!(/ghs_[A-Za-z0-9]{36}/i, "***REDACTED***")
    sanitized.gsub!(/github_pat_[A-Za-z0-9]{22}_[A-Za-z0-9]{59}/i, "***REDACTED***")
    sanitized
  end

  # Create audit log for webhook event
  def self.log_webhook(event_type:, status:, project: nil, ip_address: nil, request_id: nil, payload_excerpt: nil, actor: nil)
    create!(
      event_type: event_type,
      status: status,
      project: project,
      ip_address: ip_address,
      request_id: request_id,
      payload_excerpt: payload_excerpt,
      actor: actor
    )
  end

  # Create audit log for work item event
  def self.log_work_item(event_type:, work_item:, agent: nil)
    create!(
      event_type: event_type,
      status: STATUS_SUCCESS,
      project: work_item.project,
      auditable: work_item,
      actor: agent&.name
    )
  end

  # Create audit log for run event
  def self.log_run(event_type:, run:)
    create!(
      event_type: event_type,
      status: run.outcome == "failure" ? STATUS_FAILED : STATUS_SUCCESS,
      project: run.work_item.project,
      auditable: run,
      actor: run.agent.name
    )
  end
end
