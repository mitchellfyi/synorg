# frozen_string_literal: true

require "rails_helper"

RSpec.describe GitHubApiStrategy do
  let(:project) { create(:project, github_pat: "test-token", repo_full_name: "test/repo") }
  let(:agent) { create(:agent) }
  let(:work_item) { create(:work_item, project: project) }
  let(:strategy) { described_class.new(project: project, agent: agent, work_item: work_item) }
  let(:mock_github_service) { instance_double(GithubService) }

  before do
    allow(GithubService).to receive(:new).and_return(mock_github_service)
  end

  describe "#execute" do
    context "with valid github_operations response" do
      let(:parsed_response) do
        {
          type: "github_operations",
          operations: [
            {
              operation: "create_issue",
              title: "Test Issue",
              body: "Issue body"
            }
          ]
        }
      end

      it "processes GitHub operations" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:operations_performed]).to eq(1)
      end

      it "updates work item payload with issue number" do
        strategy.execute(parsed_response)
        expect(work_item.reload.payload["github_issue_number"]).to be_present
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

    context "with no operations" do
      let(:parsed_response) { { type: "github_operations", operations: [] } }

      it "returns error" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be false
        expect(result[:error]).to include("No operations provided")
      end
    end

    context "when project has no PAT" do
      let(:project) { create(:project, github_pat: nil) }

      it "returns error" do
        parsed_response = { type: "github_operations", operations: [{ operation: "create_issue" }] }
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be false
        expect(result[:error]).to include("No PAT configured")
      end
    end

    context "with unknown operation type" do
      let(:parsed_response) do
        {
          type: "github_operations",
          operations: [
            { operation: "unknown_operation" }
          ]
        }
      end

      it "logs warning and continues" do
        expect(Rails.logger).to receive(:warn).with(/Unknown GitHub operation/)
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:operations_performed]).to eq(0)
      end
    end
  end
end

