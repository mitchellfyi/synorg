class WorkItem < ApplicationRecord
  validates :type, presence: true
  validates :title, presence: true
  validates :status, presence: true

  scope :tasks, -> { where(type: "task") }
  scope :pending, -> { where(status: "pending") }
  scope :without_github_issue, -> { where(github_issue_number: nil) }
end
