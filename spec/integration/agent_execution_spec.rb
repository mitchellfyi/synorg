# frozen_string_literal: true

require "rails_helper"

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

  let(:mock_llm_client) { instance_double(OpenAI::Client) }
  let(:mock_llm_response) do
    {
      "choices" => [
        {
          "message" => {
            "content" => llm_content
          }
        }
      ],
      "usage" => {
        "prompt_tokens" => 100,
        "completion_tokens" => 50,
        "total_tokens" => 150
      }
    }
  end

  before do
    # Mock OpenAI client to avoid real API calls
    allow(OpenAI::Client).to receive(:new).and_return(mock_llm_client)
    allow(mock_llm_client).to receive(:chat).and_return(mock_llm_response)
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
      }.to_json
    end

    it "executes full flow: LLM → FileWriteStrategy → file system" do
      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)

      expect do
        result = runner.run
        expect(result[:success]).to be true
        expect(result[:files_written]).to be_present
      end.to change { work_item.reload.status }.from("pending").to("completed")

      # Verify files were created
      expect(File.exist?(Rails.root.join("docs/positioning.md"))).to be true
      expect(File.exist?(Rails.root.join("docs/market.md"))).to be true

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
      FileUtils.rm_rf(Rails.root.join("docs")) if Dir.exist?(Rails.root.join("docs"))
    end

    it "updates work item status on failure" do
      # Simulate LLM error
      allow(mock_llm_client).to receive(:chat).and_raise(StandardError.new("API error"))

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
      }.to_json
    end

    it "executes full flow: LLM → DatabaseStrategy → database" do
      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)

      expect do
        result = runner.run
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(2)
      end.to change { WorkItem.count }.by(2)
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

      allow(mock_llm_client).to receive(:chat).and_return(
        mock_llm_response.merge(
          "choices" => [
            {
              "message" => {
                "content" => llm_content_invalid
              }
            }
          ]
        )
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      # Should succeed but create 0 work items
      expect(result[:success]).to be true
      expect(result[:work_items_created]).to eq(0)
    end
  end

  describe "GitHubApiStrategy integration" do
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
      }.to_json
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
      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to include("No PAT configured")
    end
  end

  describe "GitHubApiStrategy integration" do
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
      }.to_json
    end

    before do
      # Mock GitHub API calls
      allow_any_instance_of(GitHubApiStrategy).to receive(:get_branch_sha).and_return("abc123")
      allow_any_instance_of(GitHubApiStrategy).to receive(:create_branch).and_return(true)
      allow_any_instance_of(GitHubApiStrategy).to receive(:create_file_in_branch).and_return(true)
      allow_any_instance_of(GithubService).to receive(:create_pull_request).and_return({
        "number" => 1,
        "html_url" => "https://github.com/test/repo/pull/1"
      })
    end

    it "executes full flow: LLM → GitHubApiStrategy → GitHub API" do
      work_item.update!(project: project_with_pat)
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
      }.to_json

      allow(mock_llm_client).to receive(:chat).and_return(
        mock_llm_response.merge(
          "choices" => [
            {
              "message" => {
                "content" => llm_content
              }
            }
          ]
        )
      )

      runner = AgentRunner.new(agent: orchestrator_agent, project: project, work_item: work_item)

      expect do
        result = runner.run
        expect(result[:success]).to be true
        expect(result[:work_items_created]).to eq(2)
      end.to change { WorkItem.count }.by(2)

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
      allow(mock_llm_client).to receive(:chat).and_return(
        mock_llm_response.merge(
          "choices" => [
            {
              "message" => {
                "content" => "This is not valid JSON"
              }
            }
          ]
        )
      )

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to include("Failed to parse LLM response")
      expect(work_item.reload.status).to eq("failed")
    end

    it "handles LLM API errors" do
      allow(mock_llm_client).to receive(:chat).and_raise(StandardError.new("API rate limit exceeded"))

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      result = runner.run

      expect(result[:success]).to be false
      expect(result[:error]).to include("API rate limit exceeded")
      expect(work_item.reload.status).to eq("failed")
    end

    it "handles empty LLM response" do
      allow(mock_llm_client).to receive(:chat).and_return(
        {
          "choices" => [],
          "usage" => {}
        }
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
      }.to_json
    end

    it "updates run record with outcome and timing after execution" do
      # Create initial run record (simulating what execution strategy would do)
      run = create(:run, agent: agent, work_item: work_item, started_at: Time.current)

      runner = AgentRunner.new(agent: agent, project: project, work_item: work_item)
      runner.run

      run.reload
      expect(run.outcome).to eq("success")
      expect(run.finished_at).to be_present
      expect(run.finished_at).to be > run.started_at
      expect(work_item.reload.status).to eq("completed")

      # Cleanup
      FileUtils.rm_f(Rails.root.join("test.md"))
    end
  end
end

