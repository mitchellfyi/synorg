# frozen_string_literal: true

class Run < ApplicationRecord
  belongs_to :agent
  belongs_to :work_item

  validates :agent, presence: true
  validates :work_item, presence: true

  scope :successful, -> { where(outcome: "success") }
  scope :failed, -> { where(outcome: "failure") }
  scope :in_progress, -> { where(outcome: nil).where.not(started_at: nil) }
end
