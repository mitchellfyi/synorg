# frozen_string_literal: true

require "rails_helper"
require_relative "../../app/services/execution_strategies/github_api_strategy"

# Integration tests for full agent execution flow
# Tests the complete flow: AgentRunner → LLM → Execution Strategy → Results
RSpec.describe "Agent Execution Integration" do
  let(:project) do
    create(:project,
      name: "Test Project",
      slug: "test-project",
      brief: "A test project for integration testing",
      repo_full_name: "test/repo",
      repo_default_branch: "main")
  end
  let(:mock_llm_service) { instance_double(LlmService, model: "gpt-4o-mini") }

  before do
    # Mock LlmService to avoid real API calls
    allow(LlmService).to receive(:new).and_return(mock_llm_service)
  end


  describe "FileWriteStrategy integration" do
    let(:agent) { create(:agent, key: "gtm", name: "GTM Agent", prompt: "Generate product positioning") }
    let(:work_item) { create(:work_item, project: project, work_type: "gtm", status: "pending") }
    let(:llm_content) do
      {
        type: "file_writes",
        files: [
          { path: "docs/positioning.md", content: "# Product Positioning\n\nTest content" },
          { path: "docs/market.md", content: "# Market Analysis\n\nTest analysis" }
        ]
      }
    end

    it "executes full flow: LLM → FileWriteStrategy → file system" do
      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)

      expect do
        result = runner.run
        expect(result[:success]).to be true
        expect(result[:files_written]).to be_present
      end.to change { work_item.reload.status }.from("pending").to("completed")

      # Verify files were created
      expect(Rails.root.join("docs/positioning.md").exist?).to be true
      expect(Rails.root.join("docs/market.md").exist?).to be true

      # Verify run record was created/updated
      run = work_item.runs.order(started_at: :desc).first
      if run
        expect(run.outcome).to eq("success")
        expect(run.started_at).to be_present
        expect(run.finished_at).to be_present
      end

      # Cleanup
      FileUtils.rm_f(Rails.root.join("docs/positioning.md"))
      FileUtils.rm_f(Rails.root.join("docs/market.md"))
      FileUtils.rm_rf(Rails.root.join("docs")) if Rails.root.join("docs").exist?
    end

    it "updates work item status on failure" do
      # Simulate LLM error
      allow(mock_llm_service).to receive(:chat).and_return(
        content: nil,
        usage: {},
        error: "API error"
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
      expect(work_item.reload.status).to eq("failed")
    end
  end

  describe "DatabaseStrategy integration" do
    let(:agent) { create(:agent, key: "product-manager", name: "Product Manager", prompt: "Create work items") }
    let(:other_agent) { create(:agent, key: "dev-agent", name: "Dev Agent") }
    let(:work_item) { create(:work_item, project: project, work_type: "product_manager", status: "pending") }
    let(:llm_content) do
      {
        type: "work_items",
        work_items: [
          {
            work_type: "task",
            priority: 5,
            agent_key: "dev-agent",
            payload: { title: "Task 1", description: "First task" }
          },
          {
            work_type: "bug",
            priority: 8,
            agent_key: "dev-agent",
            payload: { title: "Bug 1", description: "First bug" }
          }
        ]
      }
    end

    it "executes full flow: LLM → DatabaseStrategy → database" do
      # Ensure agent exists before running
      other_agent

      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)

      expect do
        result = runner.run
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(2)
      end.to change(WorkItem, :count).by(2)
        .and change { work_item.reload.status }.from("pending").to("completed")

      # Verify work items were created
      created_items = WorkItem.last(2)
      expect(created_items.map(&:work_type)).to contain_exactly("task", "bug")
      expect(created_items.all? { |wi| wi.assigned_agent == other_agent }).to be true
      expect(created_items.all? { |wi| wi.project == project }).to be true

      # Verify run record
      run = work_item.runs.last
      expect(run.outcome).to eq("success")
    end

    it "handles invalid agent keys gracefully" do
      llm_content_invalid = {
        type: "work_items",
        work_items: [
          {
            work_type: "task",
            agent_key: "non-existent-agent",
            payload: {}
          }
        ]
      }.to_json

      allow(mock_llm_service).to receive(:chat).and_return(
        content: JSON.parse(llm_content_invalid),
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      # Should succeed but create 0 work items
      expect(result[:success]).to be true
      expect(result[:work_items_created]).to eq(0)
    end
  end

  describe "GitHubApiStrategy integration for issues" do
    let(:agent) { create(:agent, key: "issue", name: "Issue Agent", prompt: "Create GitHub issues") }
    let(:work_item) { create(:work_item, project: project, work_type: "issue", status: "pending") }
    let(:project_with_pat) { create(:project, github_pat: "test-token", repo_full_name: "test/repo") }
    let(:llm_content) do
      {
        type: "github_operations",
        operations: [
          {
            operation: "create_issue",
            title: "Test Issue",
            body: "This is a test issue"
          }
        ]
      }
    end

    before do
      # Mock GitHub API calls
      allow(Net::HTTP).to receive(:start).and_return(
        instance_double(Net::HTTPResponse,
          is_a?: true,
          code: "201",
          body: {
            number: 123,
            html_url: "https://github.com/test/repo/issues/123"
          }.to_json)
      )
    end

    it "executes full flow: LLM → GitHubApiStrategy → GitHub API" do
      work_item.update!(project: project_with_pat)
      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project_with_pat, work_item: work_item)

      result = runner.run

      expect(result[:success]).to be true
      expect(result[:operations_performed]).to eq(1)
      expect(work_item.reload.status).to eq("completed")

      # Verify work item payload was updated
      expect(work_item.payload["github_issue_number"]).to eq(123)
      expect(work_item.payload["github_issue_url"]).to be_present

      # Verify run record
      run = work_item.runs.last
      expect(run.outcome).to eq("success")
    end

    it "handles missing PAT gracefully" do
      # Mock LLM to return a valid response (the strategy will check PAT)
      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to include("No PAT configured")
    end
  end

  describe "GitHubApiStrategy integration for PRs" do
    let(:agent) { create(:agent, key: "rubocop-setup", name: "RuboCop Setup", prompt: "Setup RuboCop") }
    let(:work_item) { create(:work_item, project: project, work_type: "rubocop_setup", status: "pending") }
    let(:project_with_pat) { create(:project, github_pat: "test-token", repo_full_name: "test/repo") }
    let(:llm_content) do
      {
        type: "github_operations",
        operations: [
          {
            operation: "create_files_and_pr",
            pr_title: "Add RuboCop configuration",
            pr_body: "This PR adds RuboCop configuration",
            files: [
              { path: ".rubocop.yml", content: "AllCops:\n  NewCops: enable" }
            ]
          }
        ]
      }
    end

    before do
      # Mock GitHub API calls with WebMock
      stub_request(:get, "https://api.github.com/repos/test/repo/git/ref/heads/main")
        .with(
          headers: {
            "Authorization" => "Bearer test-token",
            "Accept" => "application/vnd.github.v3+json"
          }
        )
        .to_return(
          status: 200,
          body: {
            object: {
              sha: "abc123"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "https://api.github.com/repos/test/repo/git/refs")
        .with(
          headers: {
            "Authorization" => "Bearer test-token",
            "Accept" => "application/vnd.github.v3+json",
            "Content-Type" => "application/json"
          }
        ) do |request|
          body = JSON.parse(request.body)
          body["ref"]&.start_with?("refs/heads/agent/rubocop-setup-") && body["sha"] == "abc123"
        end
        .to_return(
          status: 201,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:get, /https:\/\/api\.github\.com\/repos\/test\/repo\/contents\/.*\?ref=agent\/rubocop-setup-.*/)
        .with(
          headers: {
            "Authorization" => "Bearer test-token",
            "Accept" => "application/vnd.github.v3+json"
          }
        )
        .to_return(
          status: 404,
          body: { message: "Not Found" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:put, /https:\/\/api\.github\.com\/repos\/test\/repo\/contents\/.*/)
        .with(
          headers: {
            "Authorization" => "Bearer test-token",
            "Accept" => "application/vnd.github.v3+json",
            "Content-Type" => "application/json"
          }
        )
        .to_return(
          status: 201,
          body: {}.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      stub_request(:post, "https://api.github.com/repos/test/repo/pulls")
        .with(
          headers: {
            "Authorization" => "Bearer test-token",
            "Accept" => "application/vnd.github.v3+json",
            "Content-Type" => "application/json"
          }
        )
        .to_return(
          status: 201,
          body: {
            number: 1,
            html_url: "https://github.com/test/repo/pull/1",
            head: {
              sha: "def456"
            }
          }.to_json,
          headers: { "Content-Type" => "application/json" }
        )
    end

    it "executes full flow: LLM → GitHubApiStrategy → GitHub API" do
      work_item.update!(project: project_with_pat)
      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project_with_pat, work_item: work_item)

      result = runner.run

      expect(result[:success]).to be true
      expect(work_item.reload.status).to eq("completed")
    end
  end

  describe "end-to-end agent orchestration" do
    let(:orchestrator_agent) { create(:agent, key: "orchestrator", name: "Orchestrator", prompt: "Orchestrate work") }
    let(:gtm_agent) { create(:agent, key: "gtm", name: "GTM Agent") }
    let(:pm_agent) { create(:agent, key: "product-manager", name: "Product Manager") }
    let(:work_item) { create(:work_item, project: project, work_type: "orchestrator", status: "pending") }

    it "simulates orchestrator creating work items for other agents" do
      # Ensure agents exist before running
      gtm_agent
      pm_agent

      llm_content = {
        type: "work_items",
        work_items: [
          {
            work_type: "gtm",
            priority: 5,
            agent_key: "gtm",
            payload: { description: "Run GTM analysis" }
          },
          {
            work_type: "product_manager",
            priority: 5,
            agent_key: "product-manager",
            payload: { description: "Create work items" }
          }
        ]
      }

      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: orchestrator_agent, project: project, work_item: work_item)

      expect do
        result = runner.run
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(2)
      end.to change(WorkItem, :count).by(2)

      # Verify created work items are assigned to correct agents
      created_items = WorkItem.last(2)
      expect(created_items.find { |wi| wi.work_type == "gtm" }.assigned_agent).to eq(gtm_agent)
      expect(created_items.find { |wi| wi.work_type == "product_manager" }.assigned_agent).to eq(pm_agent)
    end
  end

  describe "error handling and recovery" do
    let(:agent) { create(:agent, key: "test-agent", prompt: "Test prompt") }
    let(:work_item) { create(:work_item, project: project, work_type: "gtm", status: "pending") }

    it "handles invalid JSON from LLM" do
      allow(mock_llm_service).to receive(:chat).and_return(
        content: "This is not valid JSON",
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to include("Response validation failed")
      expect(work_item.reload.status).to eq("failed")
    end

    it "handles LLM API errors" do
      allow(mock_llm_service).to receive(:chat).and_return(
        content: nil,
        usage: {},
        error: "API rate limit exceeded"
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to include("API rate limit exceeded")
      expect(work_item.reload.status).to eq("failed")
    end

    it "handles empty LLM response" do
      allow(mock_llm_service).to receive(:chat).and_return(
        content: nil,
        usage: {}
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to be_present
    end
  end

  describe "run record tracking" do
    let(:agent) { create(:agent, key: "test-agent", prompt: "Test prompt") }
    let(:work_item) { create(:work_item, project: project, work_type: "gtm", status: "pending") }
    let(:llm_content) do
      {
        type: "file_writes",
        files: [{ path: "test.md", content: "# Test" }]
      }
    end

    it "updates run record with outcome and timing after execution" do
      allow(mock_llm_service).to receive(:chat).and_return(
        content: llm_content,
        usage: {
          prompt_tokens: 100,
          completion_tokens: 50,
          total_tokens: 150
        }
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      runner.run

      # AgentRunner creates its own run record, so query for it
      run = work_item.runs.order(started_at: :desc).first
      expect(run).to be_present
      expect(run.outcome).to eq("success")
      expect(run.finished_at).to be_present
      expect(run.finished_at).to be > run.started_at
      expect(work_item.reload.status).to eq("completed")

      # Cleanup
      FileUtils.rm_f(Rails.root.join("test.md"))
    end
  end
end
