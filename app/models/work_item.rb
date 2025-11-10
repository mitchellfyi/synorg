# frozen_string_literal: true

class WorkItem < ApplicationRecord
  include PublicActivity::Model
  tracked owner: ->(controller, model) { model.assigned_agent },
          recipient: ->(controller, model) { model.project },
          project: ->(controller, model) { model.project },
          key: "work_item.update"

  belongs_to :project
  belongs_to :assigned_agent, class_name: "Agent", optional: true
  belongs_to :locked_by_agent, class_name: "Agent", optional: true
  has_many :runs, dependent: :destroy

  validates :work_type, presence: true
  validates :status, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :unlocked, -> { where(locked_at: nil) }
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
  scope :tasks, -> { where(work_type: "task") }

  # Track status changes
  after_create_commit -> { create_activity(:work_item_created) }
  after_update_commit -> {
    if saved_change_to_status?
      case status
      when "completed"
        create_activity(:work_item_completed)
      when "failed"
        create_activity(:work_item_failed)
      else
        create_activity(:work_item_updated, parameters: { status: status })
      end
    else
      create_activity(:work_item_updated)
    end
  }

  # Broadcast Turbo Stream updates to project-specific channel
  after_create_commit -> { broadcast_prepend_to "project_#{project_id}_work_items", target: "work_items_#{project_id}", partial: "work_items/work_item", locals: { work_item: self } }
  after_update_commit -> { broadcast_replace_to "project_#{project_id}_work_items", partial: "work_items/work_item", locals: { work_item: self } }
  after_destroy_commit -> { broadcast_remove_to "project_#{project_id}_work_items" }

  # Also broadcast to project show page (both open and recent work items)
  after_create_commit -> { 
    broadcast_prepend_to "project_#{project_id}", target: "work_items_#{project_id}", partial: "work_items/work_item", locals: { work_item: self }
    broadcast_prepend_to "project_#{project_id}", target: "recent_work_items_#{project_id}", partial: "work_items/work_item", locals: { work_item: self }
  }
  after_update_commit -> { 
    broadcast_replace_to "project_#{project_id}", partial: "work_items/work_item", locals: { work_item: self }
  }

  private

  def create_activity(key, parameters: {})
    Activity.create!(
      trackable: self,
      owner: assigned_agent,
      recipient: project,
      key: Activity::KEYS[key] || key.to_s,
      parameters: parameters.merge(
        work_type: work_type,
        status: status,
        priority: priority
      ),
      project: project,
      created_at: Time.current
    )
  end
end
