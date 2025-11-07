# frozen_string_literal: true

# Service to lease and assign work items to agents using SELECT FOR UPDATE SKIP LOCKED
class AssignmentService
  # Lease the next available work item for the given agent
  # Uses SELECT FOR UPDATE SKIP LOCKED to prevent concurrent assignments
  #
  # @param agent [Agent] The agent requesting work
  # @return [WorkItem, nil] The leased work item or nil if none available
  def self.lease_next_work_item(agent)
    WorkItem.transaction do
      work_item = WorkItem
        .pending
        .unlocked
        .by_priority
        .lock("FOR UPDATE SKIP LOCKED")
        .first

      return nil unless work_item

      work_item.update!(
        status: "in_progress",
        assigned_agent: agent,
        locked_at: Time.current,
        locked_by_agent: agent
      )

      # Create a Run record
      Run.create!(
        agent: agent,
        work_item: work_item,
        started_at: Time.current
      )

      work_item
    end
  end

  # Release a locked work item (on failure or timeout)
  #
  # @param work_item [WorkItem] The work item to release
  def self.release_work_item(work_item)
    work_item.update!(
      locked_at: nil,
      locked_by_agent: nil
    )
  end

  # Complete a work item with outcome
  #
  # @param work_item [WorkItem] The work item to complete
  # @param run [Run] The associated run
  # @param outcome [String] The outcome ('success' or 'failure')
  def self.complete_work_item(work_item, run, outcome:)
    WorkItem.transaction do
      work_item.update!(
        status: outcome == "success" ? "completed" : "failed",
        locked_at: nil,
        locked_by_agent: nil
      )

      run.update!(
        finished_at: Time.current,
        outcome: outcome
      )
    end
  end
end
