# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentService do
  let(:agent) { Agent.create!(key: "test-agent", name: "Test Agent") }
  let(:project) { Project.create!(slug: "test-project") }

  describe ".lease_next_work_item" do
    it "leases a pending work item" do
      work_item = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "pending",
        priority: 10
      )

      result = described_class.lease_next_work_item(agent)

      expect(result).to eq(work_item)
      expect(result.status).to eq("in_progress")
      expect(result.assigned_agent).to eq(agent)
      expect(result.locked_by_agent).to eq(agent)
      expect(result.locked_at).not_to be_nil
    end

    it "creates a Run record when leasing" do
      work_item = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "pending"
      )

      expect {
        described_class.lease_next_work_item(agent)
      }.to change { Run.count }.by(1)

      run = Run.last
      expect(run.agent).to eq(agent)
      expect(run.work_item).to eq(work_item)
      expect(run.started_at).not_to be_nil
    end

    it "returns nil when no work items are available" do
      result = described_class.lease_next_work_item(agent)
      expect(result).to be_nil
    end

    it "skips locked work items" do
      locked_item = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "pending",
        locked_at: Time.current
      )
      available_item = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "pending"
      )

      result = described_class.lease_next_work_item(agent)

      expect(result).to eq(available_item)
    end

    it "prioritizes higher priority work items" do
      low_priority = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "pending",
        priority: 1
      )
      high_priority = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "pending",
        priority: 10
      )

      result = described_class.lease_next_work_item(agent)

      expect(result).to eq(high_priority)
    end
  end

  describe ".release_work_item" do
    it "releases a locked work item" do
      work_item = WorkItem.create!(
        project: project,
        type: "test_work",
        status: "in_progress",
        locked_at: Time.current,
        locked_by_agent: agent
      )

      described_class.release_work_item(work_item)

      work_item.reload
      expect(work_item.locked_at).to be_nil
      expect(work_item.locked_by_agent).to be_nil
    end
  end

  describe ".complete_work_item" do
    let(:work_item) do
      WorkItem.create!(
        project: project,
        type: "test_work",
        status: "in_progress",
        locked_at: Time.current,
        locked_by_agent: agent
      )
    end
    let(:run) { Run.create!(agent: agent, work_item: work_item, started_at: Time.current) }

    it "marks work item as completed on success" do
      described_class.complete_work_item(work_item, run, outcome: "success")

      work_item.reload
      expect(work_item.status).to eq("completed")
      expect(work_item.locked_at).to be_nil
      expect(work_item.locked_by_agent).to be_nil

      run.reload
      expect(run.outcome).to eq("success")
      expect(run.finished_at).not_to be_nil
    end

    it "marks work item as failed on failure" do
      described_class.complete_work_item(work_item, run, outcome: "failure")

      work_item.reload
      expect(work_item.status).to eq("failed")

      run.reload
      expect(run.outcome).to eq("failure")
    end
  end
end
