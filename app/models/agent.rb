# frozen_string_literal: true

class Agent < ApplicationRecord
  has_many :runs, dependent: :destroy
  has_many :assigned_work_items, class_name: "WorkItem", foreign_key: :assigned_agent_id, dependent: :nullify
  has_many :locked_work_items, class_name: "WorkItem", foreign_key: :locked_by_agent_id, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :max_concurrency, numericality: { greater_than: 0 }

  scope :enabled, -> { where(enabled: true) }
end
