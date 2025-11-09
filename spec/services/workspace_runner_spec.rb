# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkspaceRunner do
  let(:project) do
    Project.create!(
      slug: "test-project",
      repo_full_name: "example/test-repo",
      repo_default_branch: "main"
    )
  end
  let(:agent) { Agent.create!(key: "test-agent", name: "Test Agent") }
  let(:work_item) do
    WorkItem.create!(
      project: project,
      work_type: "code_update",
      status: "in_progress",
      assigned_agent: agent
    )
  end
  let(:runner) { described_class.new(project: project, agent: agent, work_item: work_item) }

  describe "#initialize" do
    it "creates a new workspace runner with required dependencies" do
      expect(runner.project).to eq(project)
      expect(runner.agent).to eq(agent)
      expect(runner.work_item).to eq(work_item)
      expect(runner.workspace_service).to be_a(WorkspaceService)
    end
  end

  describe "#generate_idempotency_key" do
    it "generates a consistent idempotency key for the same inputs" do
      key1 = runner.send(:generate_idempotency_key)
      key2 = runner.send(:generate_idempotency_key)

      expect(key1).to eq(key2)
      expect(key1).to include("run:#{work_item.id}:#{agent.key}")
    end

    it "generates different keys for different work items" do
      work_item2 = WorkItem.create!(
        project: project,
        work_type: "different_work",
        status: "in_progress",
        assigned_agent: agent
      )
      runner2 = described_class.new(project: project, agent: agent, work_item: work_item2)

      key1 = runner.send(:generate_idempotency_key)
      key2 = runner2.send(:generate_idempotency_key)

      expect(key1).not_to eq(key2)
    end
  end

  describe "#run_already_executed?" do
    it "returns false when no run with the key exists" do
      key = "test-key-#{SecureRandom.hex}"
      expect(runner.send(:run_already_executed?, key)).to be false
    end

    it "returns false when run exists but failed" do
      key = "test-key-#{SecureRandom.hex}"
      Run.create!(
        agent: agent,
        work_item: work_item,
        started_at: Time.current,
        finished_at: Time.current,
        idempotency_key: key,
        outcome: "failure"
      )

      expect(runner.send(:run_already_executed?, key)).to be false
    end

    it "returns true when successful run with the key exists" do
      key = "test-key-#{SecureRandom.hex}"
      Run.create!(
        agent: agent,
        work_item: work_item,
        started_at: Time.current,
        finished_at: Time.current,
        idempotency_key: key,
        outcome: "success"
      )

      expect(runner.send(:run_already_executed?, key)).to be true
    end
  end

  describe "#generate_branch_name" do
    it "follows the agent/<agent-key>-<timestamp> convention" do
      branch_name = runner.send(:generate_branch_name)

      expect(branch_name).to match(%r{^agent/test-agent-\d{8}-\d{6}$})
    end

    it "generates unique branch names for different timestamps" do
      travel_to(Time.zone.local(2024, 6, 1, 12, 0, 0)) do
        branch1 = runner.send(:generate_branch_name)
        travel 1.second
        branch2 = runner.send(:generate_branch_name)
        expect(branch1).not_to eq(branch2)
      end
    end

    it "parameterizes agent keys with special characters" do
      agent_with_special_chars = Agent.create!(key: "test_agent.v2", name: "Test Agent V2")
      runner_special = described_class.new(
        project: project,
        agent: agent_with_special_chars,
        work_item: work_item
      )

      branch_name = runner_special.send(:generate_branch_name)
      expect(branch_name).to match(%r{^agent/test-agent-v2-\d{8}-\d{6}$})
    end
  end

  describe "#apply_changes" do
    it "writes files to the workspace" do
      runner.workspace_service.provision
      
      # Create a fake repo directory
      repo_path = File.join(runner.workspace_service.work_dir, "repo")
      FileUtils.mkdir_p(repo_path)

      changes = {
        files: [
          { path: "test.txt", content: "Hello, World!" },
          { path: "nested/file.txt", content: "Nested content" }
        ]
      }

      result = runner.send(:apply_changes, changes)
      
      expect(result).to be true
      expect(File.read(File.join(repo_path, "test.txt"))).to eq("Hello, World!")
      expect(File.read(File.join(repo_path, "nested/file.txt"))).to eq("Nested content")

      runner.workspace_service.cleanup
    end

    it "returns true when no files are provided" do
      changes = { message: "Test commit" }
      
      result = runner.send(:apply_changes, changes)
      expect(result).to be true
    end
  end

  describe "#build_default_pr_body" do
    it "includes agent and work item information" do
      pr_body = runner.send(:build_default_pr_body)

      expect(pr_body).to include("Test Agent")
      expect(pr_body).to include("test-agent")
      expect(pr_body).to include("##{work_item.id}")
      expect(pr_body).to include("code_update")
    end

    it "includes work item description if present" do
      work_item.update!(payload: { "description" => "Fix critical bug" })
      
      pr_body = runner.send(:build_default_pr_body)
      expect(pr_body).to include("Fix critical bug")
    end
  end

  describe "#execute", :skip_integration do
    # Integration tests would require Git and GitHub access
    # These are marked as pending/skipped for unit test runs

    it "creates a Run record" do
      allow(runner).to receive(:fetch_project_pat).and_return(nil)
      
      changes = { message: "test commit" }
      
      expect {
        runner.execute(changes: changes)
      }.to change { Run.count }.by(1)
    end

    it "skips execution if already run successfully" do
      key = runner.send(:generate_idempotency_key)
      Run.create!(
        agent: agent,
        work_item: work_item,
        started_at: Time.current,
        finished_at: Time.current,
        idempotency_key: key,
        outcome: "success"
      )

      changes = { message: "test commit" }
      
      # Should return true without creating a new run
      expect {
        result = runner.execute(changes: changes)
        expect(result).to be true
      }.not_to change { Run.count }
    end
  end

  describe "idempotency" do
    it "ensures duplicate runs with same inputs are prevented" do
      # Create first run
      key = runner.send(:generate_idempotency_key)
      Run.create!(
        agent: agent,
        work_item: work_item,
        started_at: Time.current,
        finished_at: Time.current,
        idempotency_key: key,
        outcome: "success"
      )

      # Attempt to create second run with same key should be prevented
      expect(runner.send(:run_already_executed?, key)).to be true
    end

    it "allows retry of failed runs" do
      key = runner.send(:generate_idempotency_key)
      Run.create!(
        agent: agent,
        work_item: work_item,
        started_at: Time.current,
        finished_at: Time.current,
        idempotency_key: key,
        outcome: "failure"
      )

      # Failed runs should be retryable
      expect(runner.send(:run_already_executed?, key)).to be false
    end
  end

  describe "cleanup" do
    it "cleans up workspace after execution" do
      allow(runner).to receive(:fetch_project_pat).and_return(nil)
      
      runner.workspace_service.provision
      work_dir = runner.workspace_service.work_dir

      expect(File.directory?(work_dir)).to be true

      changes = { message: "test commit" }
      runner.execute(changes: changes)

      expect(File.directory?(work_dir)).to be false
    end

    it "cleans up workspace even on failure" do
      allow(runner).to receive(:fetch_project_pat).and_return(nil)
      
      runner.workspace_service.provision
      work_dir = runner.workspace_service.work_dir

      changes = { message: "test commit" }
      runner.execute(changes: changes)

      expect(File.directory?(work_dir)).to be false
    end
  end
end
