# frozen_string_literal: true

class WorkItem < ApplicationRecord
  belongs_to :project
  belongs_to :assigned_agent, class_name: "Agent", optional: true
  belongs_to :locked_by_agent, class_name: "Agent", optional: true
  has_many :runs, dependent: :destroy

  validates :type, presence: true
  validates :status, presence: true

  scope :pending, -> { where(status: "pending") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :unlocked, -> { where(locked_at: nil) }
  scope :by_priority, -> { order(priority: :desc, created_at: :asc) }
end
