# frozen_string_literal: true

require "uri"

class Run < ApplicationRecord
  include PublicActivity::Model
  include ActivityTrackable

  # Disable automatic tracking - we handle activities manually for better control
  # tracked owner: ->(controller, model) { model.agent },
  #         recipient: ->(controller, model) { model.work_item },
  #         project: ->(controller, model) { model.work_item.project }

  belongs_to :agent
  belongs_to :work_item

  scope :successful, -> { where(outcome: "success") }
  scope :failed, -> { where(outcome: "failure") }
  scope :in_progress, -> { where(outcome: nil).where.not(started_at: nil) }

  # Track run lifecycle
  after_create_commit -> { create_activity(:run_started) }
  after_update_commit -> {
    if saved_change_to_outcome?
      case outcome
      when "success"
        create_activity(:run_completed, parameters: { duration: finished_at && started_at ? (finished_at - started_at).to_i : nil })
      when "failure"
        create_activity(:run_failed, parameters: { error: logs })
      end
    end
  }

  # Audit logging for run events
  after_update_commit -> {
    if saved_change_to_started_at? && started_at.present?
      AuditLog.log_run(event_type: AuditLog::RUN_STARTED, run: self)
    end
  }
  after_update_commit -> {
    if saved_change_to_finished_at? && finished_at.present?
      event_type = outcome == "failure" ? AuditLog::RUN_FAILED : AuditLog::RUN_FINISHED
      AuditLog.log_run(event_type: event_type, run: self)
    end
  }

  # Broadcast Turbo Stream updates to project-specific channel
  after_create_commit -> { broadcast_prepend_to "project_#{work_item.project_id}_runs", target: "runs_#{work_item.project_id}", partial: "runs/run_row", locals: { run: self } }
  after_update_commit -> { broadcast_replace_to "project_#{work_item.project_id}_runs", partial: "runs/run_row", locals: { run: self } }
  after_destroy_commit -> { broadcast_remove_to "project_#{work_item.project_id}_runs" }

  # Also broadcast to project show page for recent activity
  after_create_commit -> { broadcast_prepend_to "project_#{work_item.project_id}", target: "recent_runs_#{work_item.project_id}", partial: "runs/run", locals: { run: self, recent_runs: [] } }
  after_update_commit -> { broadcast_replace_to "project_#{work_item.project_id}", partial: "runs/run", locals: { run: self, recent_runs: [] } }

  # Validate URLs to prevent XSS attacks
  def safe_logs_url
    return nil if logs_url.blank?
    return nil unless valid_url?(logs_url)

    logs_url
  end

  def safe_artifacts_url
    return nil if artifacts_url.blank?
    return nil unless valid_url?(artifacts_url)

    artifacts_url
  end

  private

  def valid_url?(url)
    uri = URI.parse(url.to_s)
    uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
  rescue URI::InvalidURIError
    false
  end

  def activity_owner
    agent
  end

  def activity_recipient
    work_item
  end

  def activity_parameters
    {
      agent_name: agent.name,
      agent_key: agent.key,
      work_item_id: work_item.id,
      work_type: work_item.work_type,
      outcome: outcome
    }
  end
end
