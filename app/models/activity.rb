# frozen_string_literal: true

class Activity < PublicActivity::Activity
  include Turbo::Broadcastable

  belongs_to :project

  # Scopes for filtering activities
  scope :for_project, ->(project) { where(project: project) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_key, ->(key) { where(key: key) }

  # Activity keys
  KEYS = {
    project_created: "project.create",
    project_updated: "project.update",
    project_destroyed: "project.destroy",
    project_state_changed: "project.state_changed",
    orchestrator_triggered: "orchestrator.triggered",
    orchestrator_completed: "orchestrator.completed",
    orchestrator_failed: "orchestrator.failed",
    llm_request: "llm.request",
    llm_response: "llm.response",
    llm_error: "llm.error",
    work_item_created: "work_item.create",
    work_item_updated: "work_item.update",
    work_item_completed: "work_item.completed",
    work_item_failed: "work_item.failed",
    run_started: "run.started",
    run_completed: "run.completed",
    run_failed: "run.failed"
  }.freeze

  # Helper methods for activity display
  def activity_icon
    case key
    when /project\./
      "📁"
    when /orchestrator\./
      "🎯"
    when /llm\./
      "🤖"
    when /work_item\./
      "📋"
    when /run\./
      "⚡"
    else
      "📝"
    end
  end

  def activity_color
    case key
    when /\.completed$/, /\.success/
      "text-green-600"
    when /\.failed$/, /\.error/
      "text-red-600"
    when /\.started$/, /\.triggered$/
      "text-blue-600"
    else
      "text-gray-600"
    end
  end

  # Ensure parameters is always a hash
  def parameters
    super || {}
  end

  # Broadcast Turbo Stream updates to project-specific channel
  after_create_commit -> { broadcast_prepend_to "project_#{project_id}_activities", target: "activities_#{project_id}", partial: "activities/activity", locals: { activity: self } }
  after_create_commit -> { broadcast_prepend_to "project_#{project_id}", target: "activities_#{project_id}", partial: "activities/activity", locals: { activity: self } }
end
