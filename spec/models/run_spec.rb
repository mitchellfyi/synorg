# frozen_string_literal: true

require "rails_helper"

RSpec.describe Run, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:agent) }
    it { is_expected.to validate_presence_of(:work_item) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:agent) }
    it { is_expected.to belong_to(:work_item) }
  end

  describe "scopes" do
    let(:agent) { Agent.create!(key: "test", name: "Test") }
    let(:project) { Project.create!(slug: "test") }
    let(:work_item) { WorkItem.create!(project: project, type: "test", status: "pending") }
    let!(:successful_run) { described_class.create!(agent: agent, work_item: work_item, outcome: "success") }
    let!(:failed_run) { described_class.create!(agent: agent, work_item: work_item, outcome: "failure") }
    let!(:in_progress_run) { described_class.create!(agent: agent, work_item: work_item, started_at: Time.current) }

    describe ".successful" do
      it "returns only successful runs" do
        expect(described_class.successful).to include(successful_run)
        expect(described_class.successful).not_to include(failed_run, in_progress_run)
      end
    end

    describe ".failed" do
      it "returns only failed runs" do
        expect(described_class.failed).to include(failed_run)
        expect(described_class.failed).not_to include(successful_run, in_progress_run)
      end
    end

    describe ".in_progress" do
      it "returns only in-progress runs" do
        expect(described_class.in_progress).to include(in_progress_run)
        expect(described_class.in_progress).not_to include(successful_run, failed_run)
      end
    end
  end
end
