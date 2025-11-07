# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkItem, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:work_type) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:assigned_agent).optional }
    it { is_expected.to belong_to(:locked_by_agent).optional }
    it { is_expected.to have_many(:runs).dependent(:destroy) }
  end

  describe "scopes" do
    let(:project) { Project.create!(slug: "test") }
    let!(:pending_item) { described_class.create!(project: project, work_type: "test", status: "pending") }
    let!(:in_progress_item) { described_class.create!(project: project, work_type: "test", status: "in_progress") }
    let!(:completed_item) { described_class.create!(project: project, work_type: "test", status: "completed") }
    let!(:failed_item) { described_class.create!(project: project, work_type: "test", status: "failed") }
    let!(:locked_item) { described_class.create!(project: project, work_type: "test", status: "pending", locked_at: Time.current) }

    describe ".pending" do
      it "returns only pending work items" do
        expect(described_class.pending).to include(pending_item, locked_item)
        expect(described_class.pending).not_to include(in_progress_item, completed_item, failed_item)
      end
    end

    describe ".unlocked" do
      it "returns only unlocked work items" do
        expect(described_class.unlocked).to include(pending_item, in_progress_item, completed_item, failed_item)
        expect(described_class.unlocked).not_to include(locked_item)
      end
    end

    describe ".by_priority" do
      let!(:low_priority) { described_class.create!(project: project, work_type: "test", status: "pending", priority: 1) }
      let!(:high_priority) { described_class.create!(project: project, work_type: "test", status: "pending", priority: 10) }

      it "orders by priority descending, then created_at ascending" do
        results = described_class.by_priority.to_a
        expect(results.first).to eq(high_priority)
        expect(results.second).to eq(low_priority)
      end
    end
  end
end
