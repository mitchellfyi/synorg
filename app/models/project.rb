# frozen_string_literal: true

class Project < ApplicationRecord
  include AASM

  include PublicActivity::Model

  # Disable automatic tracking - we handle activities manually for better control
  # tracked owner: ->(controller, model) { controller&.current_user },
  #         recipient: ->(controller, model) { model },
  #         project: ->(controller, model) { model }

  has_many :work_items, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_many :webhook_events, dependent: :destroy
  has_many :activities, class_name: "Activity", dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :state, presence: true

  # Broadcast Turbo Stream updates
  broadcasts_to ->(project) { "projects" }, inserts_by: :prepend, partial: "projects/project"
  after_update_commit -> { broadcast_replace_to "projects", partial: "projects/project", locals: { project: self } }
  after_create_commit -> { broadcast_prepend_to "projects", partial: "projects/project", locals: { project: self } }
  after_destroy_commit -> { broadcast_remove_to "projects" }

  # Track project lifecycle manually (not using PublicActivity automatic tracking)
  after_create_commit -> { create_project_activity(:project_created) }
  after_update_commit -> { create_project_activity(:project_updated) }
  after_destroy_commit -> { create_project_activity(:project_destroyed) }

  aasm column: :state do
    state :draft, initial: true
    state :scoped
    state :repo_bootstrapped
    state :in_build
    state :live

    event :scope do
      transitions from: :draft, to: :scoped
      after do
        Activity.create!(
          trackable: self,
          key: Activity::KEYS[:project_state_changed],
          parameters: { from: "draft", to: "scoped" },
          project: self,
          created_at: Time.current
        )
      end
    end

    event :bootstrap_repo do
      transitions from: :scoped, to: :repo_bootstrapped
      after do
        Activity.create!(
          trackable: self,
          key: Activity::KEYS[:project_state_changed],
          parameters: { from: "scoped", to: "repo_bootstrapped" },
          project: self,
          created_at: Time.current
        )
      end
    end

    event :start_build do
      transitions from: :repo_bootstrapped, to: :in_build
      after do
        Activity.create!(
          trackable: self,
          key: Activity::KEYS[:project_state_changed],
          parameters: { from: "repo_bootstrapped", to: "in_build" },
          project: self,
          created_at: Time.current
        )
      end
    end

    event :go_live do
      transitions from: :in_build, to: :live
      after do
        Activity.create!(
          trackable: self,
          key: Activity::KEYS[:project_state_changed],
          parameters: { from: "in_build", to: "live" },
          project: self,
          created_at: Time.current
        )
      end
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
    work_items.exists?(["created_at > ?", 10.seconds.ago])
  end

  private

  def create_project_activity(key, parameters: {})
    Activity.create!(
      trackable: self,
      owner: nil, # Projects don't have owners in our system
      recipient: self,
      key: Activity::KEYS[key] || key.to_s,
      parameters: parameters,
      project: self,
      created_at: Time.current
    )
  end
end
