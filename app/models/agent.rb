# frozen_string_literal: true

# Agent model represents autonomous agents that process work items.
# Agents are GLOBAL resources - they are not tied to any specific project.
# Agents can be used by any project through work items. The orchestrator agent
# assigns agents to work items as needed based on work_type and agent capabilities.
class Agent < ApplicationRecord
  has_many :runs, dependent: :destroy
  has_many :assigned_work_items, class_name: "WorkItem", foreign_key: :assigned_agent_id, dependent: :nullify
  has_many :locked_work_items, class_name: "WorkItem", foreign_key: :locked_by_agent_id, dependent: :nullify

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :max_concurrency, numericality: { greater_than: 0 }

  scope :enabled, -> { where(enabled: true) }
end
