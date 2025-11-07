# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductManagerAgentService do
  describe "#run" do
    let(:project_brief) { "A collaborative task management tool for remote teams" }
    let(:service) { described_class.new(project_brief) }

    it "returns a success response" do
      result = service.run
      expect(result[:success]).to be true
    end

    it "creates work items" do
      expect { service.run }.to change(WorkItem, :count).by_at_least(5)
    end

    it "creates tasks with correct attributes" do
      result = service.run
      work_items = WorkItem.where(id: result[:work_item_ids])

      work_items.each do |item|
        expect(item.type).to eq("task")
        expect(item.title).to be_present
        expect(item.description).to be_present
        expect(item.status).to eq("pending")
      end
    end

    it "returns work item IDs" do
      result = service.run
      expect(result[:work_item_ids]).to be_an(Array)
      expect(result[:work_item_ids].length).to be >= 5
    end

    it "assigns priorities to work items" do
      result = service.run
      work_items = WorkItem.where(id: result[:work_item_ids])

      expect(work_items.pluck(:priority)).to all(be_a(Integer))
    end

    context "when GTM positioning exists" do
      let(:gtm_content) { "Test positioning content" }

      before do
        positioning_path = Rails.root.join("docs", "product", "positioning.md")
        FileUtils.mkdir_p(File.dirname(positioning_path))
        File.write(positioning_path, gtm_content)
      end

      after do
        FileUtils.rm_f(Rails.root.join("docs", "product", "positioning.md"))
      end

      it "reads the GTM positioning" do
        result = service.run
        expect(result[:success]).to be true
      end
    end

    context "when database operation fails" do
      before do
        allow(WorkItem).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)
      end

      it "returns an error response" do
        result = service.run
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end
end
