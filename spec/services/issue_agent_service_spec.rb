# frozen_string_literal: true

require "rails_helper"

RSpec.describe IssueAgentService do
  describe "#run" do
    let(:project) { create(:project) }
    let(:service) { described_class.new(project) }

    context "with work items needing GitHub issues" do
      let!(:work_items) do
        [
          create(:work_item, project: project, work_type: "task",
                 payload: { title: "Task 1", description: "Description 1" }),
          create(:work_item, project: project, work_type: "task",
                 payload: { title: "Task 2", description: "Description 2" }),
          create(:work_item, project: project, work_type: "task",
                 payload: { title: "Task 3", description: "Description 3" })
        ]
      end

      it "returns a success response" do
        result = service.run
        expect(result[:success]).to be true
      end

      it "updates work items with GitHub issue numbers" do
        service.run
        work_items.each(&:reload)
        expect(work_items.map { |wi| wi.payload["github_issue_number"] }).to all(be_present)
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
        create(:work_item, project: project, work_type: "task",
               payload: { title: "Task", github_issue_number: 123 })
      end

      it "does not create duplicate issues" do
        initial_number = work_item.payload["github_issue_number"]
        service.run
        expect(work_item.reload.payload["github_issue_number"]).to eq(initial_number)
      end
    end

    context "when an error occurs" do
      let(:work_item) do
        create(:work_item, project: project, work_type: "task",
               payload: { title: "Task" })
      end

      before do
        allow(project).to receive(:work_items).and_return(WorkItem.where(id: work_item.id))
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
