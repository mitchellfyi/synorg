# frozen_string_literal: true

# Model for storing GitHub webhook events
# Used for debugging and auditing webhook deliveries
class WebhookEvent < ApplicationRecord
  belongs_to :project

  validates :event_type, presence: true
  validates :delivery_id, presence: true, uniqueness: true
  validates :payload, presence: true

  scope :by_event_type, ->(event_type) { where(event_type: event_type) }
  scope :recent, -> { order(created_at: :desc) }
end
