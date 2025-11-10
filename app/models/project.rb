# frozen_string_literal: true

class Project < ApplicationRecord
  include AASM

  has_many :work_items, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_many :webhook_events, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :state, presence: true

  aasm column: :state do
    state :draft, initial: true
    state :scoped
    state :repo_bootstrapped
    state :in_build
    state :live

    event :scope do
      transitions from: :draft, to: :scoped
    end

    event :bootstrap_repo do
      transitions from: :scoped, to: :repo_bootstrapped
    end

    event :start_build do
      transitions from: :repo_bootstrapped, to: :in_build
    end

    event :go_live do
      transitions from: :in_build, to: :live
    end

    event :revert_to_build do
      transitions from: :live, to: :in_build
    end
  end

  # Check if orchestrator is currently running
  # Since orchestrator runs synchronously and creates work items quickly,
  # we check if work items were created very recently (within last 10 seconds)
  # which would indicate orchestrator just ran or is running
  def orchestrator_running?
    # Check if work items were created very recently (within last 10 seconds)
    # This is a proxy for orchestrator running since orchestrator creates work items synchronously
    work_items.where("created_at > ?", 10.seconds.ago).exists?
  end
end
