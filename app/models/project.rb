# frozen_string_literal: true

class Project < ApplicationRecord
  include AASM
  include PublicActivity::Model
  include ActivityTrackable

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

  # Custom validation: warn if github_pat is set directly (deprecated)
  validate :warn_deprecated_pat_storage, if: -> { github_pat.present? }

  # Broadcast Turbo Stream updates
  broadcasts_to ->(project) { "projects" }, inserts_by: :prepend, partial: "projects/project"
  after_update_commit -> { broadcast_replace_to "projects", partial: "projects/project", locals: { project: self } }
  after_create_commit -> { broadcast_prepend_to "projects", partial: "projects/project", locals: { project: self } }
  after_destroy_commit -> { broadcast_remove_to "projects" }

  # Track project lifecycle manually (not using PublicActivity automatic tracking)
  after_create_commit -> { create_activity(:project_created) }
  after_update_commit -> { create_activity(:project_updated) }
  after_destroy_commit -> { create_activity(:project_destroyed) }

  aasm column: :state do
    state :draft, initial: true
    state :scoped
    state :repo_bootstrapped
    state :in_build
    state :live

    event :scope do
      transitions from: :draft, to: :scoped
      after { create_activity(:project_state_changed, parameters: { from: "draft", to: "scoped" }) }
    end

    event :bootstrap_repo do
      transitions from: :scoped, to: :repo_bootstrapped
      after { create_activity(:project_state_changed, parameters: { from: "scoped", to: "repo_bootstrapped" }) }
    end

    event :start_build do
      transitions from: :repo_bootstrapped, to: :in_build
      after { create_activity(:project_state_changed, parameters: { from: "repo_bootstrapped", to: "in_build" }) }
    end

    event :go_live do
      transitions from: :in_build, to: :live
      after { create_activity(:project_state_changed, parameters: { from: "in_build", to: "live" }) }
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

  # Load GitHub PAT from environment using the configured secret name
  # Returns nil if no secret name is configured or secret is not found
  # This is the preferred way to access PATs instead of storing them directly
  def github_token
    return nil unless github_pat_secret_name.present?

    token = ENV[github_pat_secret_name]
    
    # Fall back to direct storage if environment variable not found (deprecated path)
    if token.blank? && github_pat.present?
      Rails.logger.warn("Using deprecated direct PAT storage for project #{slug}. " \
                       "Please migrate to github_pat_secret_name.")
      return github_pat
    end

    token
  end

  private

  # Projects don't have owners in our system
  def activity_owner
    nil
  end

  def activity_recipient
    self
  end

  # Validation to warn about deprecated PAT storage
  def warn_deprecated_pat_storage
    Rails.logger.warn(
      "Project #{slug} is using deprecated direct PAT storage. " \
      "Please migrate to github_pat_secret_name for better security."
    )
  end
end
