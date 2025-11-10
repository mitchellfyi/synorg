# frozen_string_literal: true

require "rails_helper"
require_relative "../../../app/services/execution_strategies/github_api_strategy"

RSpec.describe GitHubApiStrategy do
  let(:project) { create(:project, github_pat: "test-token", repo_full_name: "test/repo") }
  let(:agent) { create(:agent) }
  let(:work_item) { create(:work_item, project: project) }
  let(:strategy) { described_class.new(project: project, agent: agent, work_item: work_item) }

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

      before do
        # Stub HTTP request for creating issue
        stub_request(:post, "https://api.github.com/repos/test/repo/issues")
          .with(
            headers: {
              "Authorization" => "Bearer test-token",
              "Accept" => "application/vnd.github.v3+json",
              "Content-Type" => "application/json"
            },
            body: hash_including(
              title: "Test Issue",
              body: "Issue body",
              labels: ["agent-created"]
            )
          )
          .to_return(
            status: 201,
            body: {
              number: 123,
              html_url: "https://github.com/test/repo/issues/123",
              title: "Test Issue"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )

        # Stub Copilot assignment
        stub_request(:patch, "https://api.github.com/repos/test/repo/issues/123")
          .with(
            headers: {
              "Authorization" => "Bearer test-token",
              "Accept" => "application/vnd.github.v3+json",
              "Content-Type" => "application/json"
            },
            body: { assignees: ["github-copilot"] }.to_json
          )
          .to_return(
            status: 200,
            body: {
              number: 123,
              html_url: "https://github.com/test/repo/issues/123"
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "processes GitHub operations" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:operations_performed]).to eq(1)
      end

      it "updates work item payload with issue number" do
        strategy.execute(parsed_response)
        expect(work_item.reload.payload["github_issue_number"]).to eq(123)
        expect(work_item.reload.payload["github_issue_url"]).to eq("https://github.com/test/repo/issues/123")
      end

      context "with labels" do
        let(:parsed_response) do
          {
            type: "github_operations",
            operations: [
              {
                operation: "create_issue",
                title: "Test Issue",
                body: "Issue body",
                labels: ["task", "agent-created", "bug"]
              }
            ]
          }
        end

        it "creates issue with custom labels" do
          stub_request(:post, "https://api.github.com/repos/test/repo/issues")
            .with(
              body: hash_including(labels: ["task", "agent-created", "bug"])
            )
            .to_return(
              status: 201,
              body: { number: 123, html_url: "https://github.com/test/repo/issues/123" }.to_json,
              headers: { "Content-Type" => "application/json" }
            )

          stub_request(:patch, "https://api.github.com/repos/test/repo/issues/123")
            .to_return(status: 200, body: { number: 123 }.to_json)

          result = strategy.execute(parsed_response)
          expect(result[:success]).to be true
        end
      end

      context "when Copilot assignment fails" do
        it "still succeeds but logs warning" do
          stub_request(:patch, "https://api.github.com/repos/test/repo/issues/123")
            .to_return(status: 404, body: { message: "Not found" }.to_json)

          expect(Rails.logger).to receive(:warn).with(/Failed to assign issue.*Copilot/)
          result = strategy.execute(parsed_response)
          expect(result[:success]).to be true
        end
      end
    end

    context "with create_pr operation" do
      let(:parsed_response) do
        {
          type: "github_operations",
          operations: [
            {
              operation: "create_pr",
              title: "Test PR",
              body: "PR body",
              head: "feature-branch",
              base: "main"
            }
          ]
        }
      end

      before do
        stub_request(:post, "https://api.github.com/repos/test/repo/pulls")
          .with(
            headers: {
              "Authorization" => "Bearer test-token",
              "Accept" => "application/vnd.github.v3+json",
              "Content-Type" => "application/json"
            },
            body: hash_including(
              title: "Test PR",
              body: "PR body",
              head: "feature-branch",
              base: "main"
            )
          )
          .to_return(
            status: 201,
            body: {
              number: 456,
              html_url: "https://github.com/test/repo/pull/456",
              head: {
                sha: "abc123def456"
              }
            }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "creates PR and returns PR info" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:pr_info]).to be_present
        expect(result[:pr_info][:pr_number]).to eq(456)
        expect(result[:pr_info][:pr_head_sha]).to eq("abc123def456")
      end

      it "updates work item payload with PR information" do
        strategy.execute(parsed_response)
        expect(work_item.reload.payload["github_pr_number"]).to eq(456)
        expect(work_item.reload.payload["github_pr_url"]).to eq("https://github.com/test/repo/pull/456")
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
