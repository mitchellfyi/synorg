# frozen_string_literal: true

# Agent model represents autonomous agents that process work items.
# Agents are GLOBAL resources - they are not tied to any specific project.
# Agents can be used by any project through work items. The orchestrator agent
# assigns agents to work items as needed based on work_type and agent capabilities.
class Agent < ApplicationRecord
  has_many :runs, dependent: :destroy, inverse_of: :agent
  has_many :assigned_work_items, class_name: "WorkItem", foreign_key: :assigned_agent_id, dependent: :nullify, inverse_of: :assigned_agent
  has_many :locked_work_items, class_name: "WorkItem", foreign_key: :locked_by_agent_id, dependent: :nullify, inverse_of: :locked_by_agent

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :max_concurrency, numericality: { greater_than: 0 }

  scope :enabled, -> { where(enabled: true) }

  # Cache agent lookups by key since agents are global and don't change frequently
  # Cache is invalidated when agent is updated or destroyed
  def self.find_by_cached(key)
    Rails.cache.fetch("agent:#{key}", expires_in: 1.hour) do
      find_by(key: key)
    end
  end

  # Clear cache when agent is updated or destroyed
  after_update :clear_cache
  after_destroy :clear_cache

  private

  def clear_cache
    Rails.cache.delete("agent:#{key}")
  end
end
