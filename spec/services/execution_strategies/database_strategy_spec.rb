# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseStrategy do
  let(:project) { create(:project) }
  let(:agent) { create(:agent, key: "test-agent") }
  let(:other_agent) { create(:agent, key: "other-agent") }
  let(:work_item) { create(:work_item, project: project) }
  let(:strategy) { described_class.new(project: project, agent: agent, work_item: work_item) }

  describe "#execute" do
    context "with valid work_items response" do
      let(:parsed_response) do
        {
          type: "work_items",
          work_items: [
            {
              work_type: "task",
              priority: 5,
              agent_key: "test-agent",
              payload: { title: "Task 1" }
            },
            {
              work_type: "bug",
              priority: 8,
              agent_key: "other-agent",
              payload: { title: "Bug 1" }
            }
          ]
        }
      end

      it "creates work items in database" do
        expect { strategy.execute(parsed_response) }.to change(WorkItem, :count).by(2)

        created_items = WorkItem.last(2)
        expect(created_items.map(&:work_type)).to contain_exactly("task", "bug")
        expect(created_items.map(&:priority)).to contain_exactly(5, 8)
      end

      it "assigns correct agents" do
        result = strategy.execute(parsed_response)
        created_items = WorkItem.last(2)

        expect(created_items.find { |wi| wi.work_type == "task" }.assigned_agent).to eq(agent)
        expect(created_items.find { |wi| wi.work_type == "bug" }.assigned_agent).to eq(other_agent)
      end

      it "returns success with count" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(2)
        expect(result[:work_item_ids]).to have(2).items
      end
    end

    context "with invalid response type" do
      let(:parsed_response) { { type: "invalid" } }

      it "returns error" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be false
        expect(result[:error]).to include("Invalid response type")
      end
    end

    context "with no work items" do
      let(:parsed_response) { { type: "work_items", work_items: [] } }

      it "returns error" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be false
        expect(result[:error]).to include("No work items provided")
      end
    end

    context "with invalid agent key" do
      let(:parsed_response) do
        {
          type: "work_items",
          work_items: [
            {
              work_type: "task",
              agent_key: "non-existent-agent",
              payload: {}
            }
          ]
        }
      end

      it "skips work items with invalid agent" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(0)
      end
    end
  end
end
