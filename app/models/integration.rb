# frozen_string_literal: true

class Integration < ApplicationRecord
  belongs_to :project

  validates :kind, presence: true
  validates :name, presence: true
  validates :status, presence: true

  scope :active, -> { where(status: "active") }
  scope :inactive, -> { where(status: "inactive") }
end
