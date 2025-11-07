# frozen_string_literal: true

require "rails_helper"

RSpec.describe IssueAgentService do
  describe "#run" do
    let(:service) { described_class.new }

    context "with work items needing GitHub issues" do
      let!(:work_items) do
        [
          create(:work_item, type: "task", title: "Task 1", github_issue_number: nil),
          create(:work_item, type: "task", title: "Task 2", github_issue_number: nil),
          create(:work_item, type: "task", title: "Task 3", github_issue_number: nil)
        ]
      end

      it "returns a success response" do
        result = service.run
        expect(result[:success]).to be true
      end

      it "updates work items with GitHub issue numbers" do
        service.run
        work_items.each(&:reload)
        expect(work_items.map(&:github_issue_number)).to all(be_present)
      end

      it "returns the count of created issues" do
        result = service.run
        expect(result[:issues_created]).to eq(3)
      end

      it "returns work item IDs" do
        result = service.run
        expect(result[:work_item_ids]).to match_array(work_items.map(&:id))
      end

      it "returns issue numbers" do
        result = service.run
        expect(result[:issue_numbers]).to all(be_a(Integer))
      end
    end

    context "when no work items need GitHub issues" do
      it "returns zero issues created" do
        result = service.run
        expect(result[:issues_created]).to eq(0)
        expect(result[:success]).to be true
      end
    end

    context "with work items that already have GitHub issues" do
      let!(:work_item) do
        create(:work_item, type: "task", github_issue_number: 123)
      end

      it "does not create duplicate issues" do
        expect { service.run }.not_to change { work_item.reload.github_issue_number }
      end
    end

    context "when an error occurs" do
      let(:work_item) { create(:work_item, type: "task", github_issue_number: nil) }

      before do
        allow(WorkItem).to receive(:tasks).and_return(WorkItem.where(id: work_item.id))
        allow(work_item).to receive(:update!).and_raise(StandardError, "Test error")
      end

      it "returns an error response" do
        result = service.run
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Test error")
      end
    end
  end
end
