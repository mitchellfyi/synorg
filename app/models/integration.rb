# frozen_string_literal: true

# Integration model for storing external service configurations
# For GitHub PATs and other sensitive credentials:
# - Store only the SECRET NAME in the 'value' field (e.g., "SYNORG_GITHUB_PAT")
# - Never store the actual token/secret value in the database
# - Load actual credentials from ENV at runtime using the stored name
class Integration < ApplicationRecord
  belongs_to :project

  validates :kind, presence: true
  validates :name, presence: true
  validates :status, presence: true

  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }

  # Load the actual credential value from environment
  # Returns nil if the integration doesn't have a value or ENV var not found
  def credential
    return nil if value.blank?
    ENV[value]
  end
end
