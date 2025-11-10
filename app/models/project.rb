# frozen_string_literal: true

class Project < ApplicationRecord
  include AASM
  include PublicActivity::Model
  tracked owner: ->(controller, model) { controller&.current_user },
          recipient: ->(controller, model) { model },
          project: ->(controller, model) { model }

  has_many :work_items, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_many :webhook_events, dependent: :destroy
  has_many :activities, class_name: "Activity", foreign_key: :project_id, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :state, presence: true

  # Broadcast Turbo Stream updates
  broadcasts_to ->(project) { "projects" }, inserts_by: :prepend, partial: "projects/project"
  after_update_commit -> { broadcast_replace_to "projects", partial: "projects/project", locals: { project: self } }
  after_create_commit -> { broadcast_prepend_to "projects", partial: "projects/project", locals: { project: self } }
  after_destroy_commit -> { broadcast_remove_to "projects" }

  # Track state changes
  after_transition :scope, on: :scope do
    Activity.create!(
      trackable: self,
      key: Activity::KEYS[:project_state_changed],
      parameters: { from: "draft", to: "scoped" },
      project: self,
      created_at: Time.current
    )
  end

  after_transition :bootstrap_repo, on: :bootstrap_repo do
    Activity.create!(
      trackable: self,
      key: Activity::KEYS[:project_state_changed],
      parameters: { from: "scoped", to: "repo_bootstrapped" },
      project: self,
      created_at: Time.current
    )
  end

  after_transition :start_build, on: :start_build do
    Activity.create!(
      trackable: self,
      key: Activity::KEYS[:project_state_changed],
      parameters: { from: "repo_bootstrapped", to: "in_build" },
      project: self,
      created_at: Time.current
    )
  end

  after_transition :go_live, on: :go_live do
    Activity.create!(
      trackable: self,
      key: Activity::KEYS[:project_state_changed],
      parameters: { from: "in_build", to: "live" },
      project: self,
      created_at: Time.current
    )
  end

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
