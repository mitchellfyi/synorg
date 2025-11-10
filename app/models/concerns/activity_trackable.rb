# frozen_string_literal: true

# Concern for models that track activities
# Provides a consistent interface for creating activities
module ActivityTrackable
  extend ActiveSupport::Concern

  # Create an activity record for this model
  #
  # @param key [Symbol, String] Activity key (will be looked up in Activity::KEYS)
  # @param parameters [Hash] Additional parameters to store with the activity
  # @param owner [Object, nil] Owner of the activity (e.g., agent, user)
  # @param recipient [Object, nil] Recipient of the activity (defaults to self or project)
  def create_activity(key, parameters: {}, owner: nil, recipient: nil)
    project = activity_project
    return unless project&.persisted? # Skip activity creation if project is not available or not persisted

    Activity.create!(
      trackable: self,
      owner: owner || activity_owner,
      recipient: recipient || activity_recipient,
      key: Activity::KEYS[key] || key.to_s,
      parameters: activity_parameters.merge(parameters),
      project: project,
      created_at: Time.current
    )
  end

  private

  # Override in including classes to customize activity owner
  def activity_owner
    nil
  end

  # Override in including classes to customize activity recipient
  def activity_recipient
    respond_to?(:project) ? project : self
  end

  # Override in including classes to customize activity project
  def activity_project
    if respond_to?(:project)
      project
    elsif respond_to?(:work_item)
      work_item&.project
    else
      nil
    end
  end

  # Override in including classes to customize default parameters
  def activity_parameters
    {}
  end
end
