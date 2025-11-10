# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrchestratorTriggerService do
  let(:project) { create(:project) }
  let(:orchestrator_agent) { create(:agent, key: "orchestrator", enabled: true, prompt: "Test prompt", name: "Orchestrator") }

  before do
    allow(Agent).to receive(:find_by).with(key: "orchestrator").and_return(orchestrator_agent)
  end

  describe "#call" do
    context "when orchestrator is already running" do
      before do
        allow(project).to receive(:orchestrator_running?).and_return(true)
      end

      it "returns error result" do
        result = described_class.new(project).call
        expect(result[:success]).to be false
        expect(result[:message]).to include("already running")
      end

      it "does not create work item" do
        expect do
          described_class.new(project).call
        end.not_to change { project.work_items.count }
      end
    end

    context "when orchestrator agent is not found" do
      before do
        allow(project).to receive(:orchestrator_running?).and_return(false)
        allow(Agent).to receive(:find_by).with(key: "orchestrator").and_return(nil)
      end

      it "returns error result" do
        result = described_class.new(project).call
        expect(result[:success]).to be false
        expect(result[:message]).to include("not found or disabled")
      end
    end

    context "when orchestrator agent is disabled" do
      let(:disabled_agent) { create(:agent, key: "disabled-orchestrator", enabled: false) }

      before do
        allow(project).to receive(:orchestrator_running?).and_return(false)
        allow(Agent).to receive(:find_by).with(key: "orchestrator").and_return(disabled_agent)
      end

      it "returns error result" do
        result = described_class.new(project).call
        expect(result[:success]).to be false
        expect(result[:message]).to include("not found or disabled")
      end
    end

    context "when orchestrator runs successfully" do
      let(:mock_runner) { instance_double(AgentRunner) }

      before do
        allow(project).to receive(:orchestrator_running?).and_return(false)
        allow(AgentRunner).to receive(:new).and_return(mock_runner)
        allow(mock_runner).to receive(:run).and_return(
          {
            success: true,
            work_items_created: 5
          }
        )
      end

      it "creates orchestrator work item" do
        expect do
          described_class.new(project).call
        end.to change { project.work_items.where(work_type: "orchestrator").count }.by(1)
      end

      it "creates trigger activity" do
        expect do
          described_class.new(project).call
        end.to change { Activity.where(key: Activity::KEYS[:orchestrator_triggered]).count }.by(1)
      end

      it "creates completion activity" do
        expect do
          described_class.new(project).call
        end.to change { Activity.where(key: Activity::KEYS[:orchestrator_completed]).count }.by(1)
      end

      it "returns success result with work items count" do
        result = described_class.new(project).call
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(5)
        expect(result[:message]).to include("5")
      end
    end

    context "when orchestrator fails" do
      let(:mock_runner) { instance_double(AgentRunner) }

      before do
        allow(project).to receive(:orchestrator_running?).and_return(false)
        allow(AgentRunner).to receive(:new).and_return(mock_runner)
        allow(mock_runner).to receive(:run).and_return(
          {
            success: false,
            error: "Test error"
          }
        )
      end

      it "creates failure activity" do
        expect do
          described_class.new(project).call
        end.to change { Activity.where(key: Activity::KEYS[:orchestrator_failed]).count }.by(1)
      end

      it "returns error result" do
        result = described_class.new(project).call
        expect(result[:success]).to be false
        expect(result[:message]).to include("Failed to trigger orchestrator")
        expect(result[:message]).to include("Test error")
      end
    end
  end
end
