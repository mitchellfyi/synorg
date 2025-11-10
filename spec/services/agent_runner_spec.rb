# frozen_string_literal: true

require "rails_helper"
require_relative "../../app/services/execution_strategies/file_write_strategy"

RSpec.describe AgentRunner do
  let(:project) { create(:project) }
  let(:agent) { create(:agent, key: "test-agent", name: "Test Agent", prompt: "Test prompt") }
  let(:work_item) { create(:work_item, project: project, work_type: "gtm", status: "pending") }
  let(:runner) { described_class.new(agent: agent, project: project, work_item: work_item) }

  describe "#initialize" do
    it "sets agent, project, and work_item" do
      expect(runner.agent).to eq(agent)
      expect(runner.project).to eq(project)
      expect(runner.work_item).to eq(work_item)
    end
  end

  describe "#run" do
    let(:mock_llm_service) { instance_double(LlmService, model: "gpt-4") }
    let(:mock_strategy) { instance_double(FileWriteStrategy) }

    before do
      allow(LlmService).to receive(:new).and_return(mock_llm_service)
      allow(FileWriteStrategy).to receive(:new).and_return(mock_strategy)
      allow(runner).to receive(:resolve_strategy).and_return(mock_strategy)
    end

    context "when agent has no prompt" do
      let(:agent) { create(:agent, key: "no-prompt", name: "No Prompt Agent", prompt: nil) }

      it "returns error response" do
        result = runner.run
        expect(result[:success]).to be false
        expect(result[:error]).to include("no prompt configured")
      end
    end

    context "when LLM call succeeds" do
      let(:llm_response) do
        {
          content: '{"type": "file_writes", "files": [{"path": "test.md", "content": "# Test"}]}',
          usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
        }
      end
      let(:strategy_result) { { success: true, message: "Files written", files_written: ["test.md"] } }

      before do
        allow(mock_llm_service).to receive(:chat).and_return(llm_response)
        allow(mock_strategy).to receive(:execute).and_return(strategy_result)
      end

      it "calls LLM service with prompt and context" do
        expect(mock_llm_service).to receive(:chat).with(
          hash_including(
            prompt: "Test prompt",
            context: hash_including(
              project: hash_including(name: project.name),
              work_item: hash_including(id: work_item.id),
              agent: hash_including(key: agent.key)
            )
          )
        )

        runner.run
      end

      it "parses LLM response and executes strategy" do
        expect(mock_strategy).to receive(:execute).with(
          hash_including(type: "file_writes", files: array_including(hash_including(path: "test.md")))
        )

        result = runner.run
        expect(result[:success]).to be true
      end

      it "updates run records on success" do
        result = runner.run
        expect(result[:success]).to be true

        # Verify run was updated
        run = work_item.runs.order(started_at: :desc).first
        expect(run).to be_present
        expect(run.finished_at).to be_present
        expect(run.outcome).to eq("success")
      end

      context "when strategy returns PR info" do
        let(:strategy_result) do
          {
            success: true,
            message: "PR created",
            pr_info: {
              pr_number: 789,
              pr_head_sha: "sha123",
              url: "https://github.com/test/repo/pull/789"
            }
          }
        end

        it "stores PR info in run" do
          result = runner.run
          expect(result[:success]).to be true

          run = work_item.runs.order(started_at: :desc).first
          expect(run.github_pr_number).to eq(789)
          expect(run.github_pr_head_sha).to eq("sha123")
          expect(run.artifacts_url).to eq("https://github.com/test/repo/pull/789")
        end
      end
    end

    context "when LLM call fails" do
      before do
        allow(mock_llm_service).to receive(:chat).and_return(
          { content: nil, error: "API error", usage: {} }
        )
      end

      it "returns error response" do
        result = runner.run
        expect(result[:success]).to be false
        expect(result[:error]).to include("API error")
      end
    end

    context "when LLM returns invalid JSON" do
      before do
        allow(mock_llm_service).to receive(:chat).and_return(
          { content: "not valid json", usage: {} }
        )
      end

      it "returns error response" do
        result = runner.run
        expect(result[:success]).to be false
        expect(result[:error]).to include("Response validation failed")
      end
    end

    context "when strategy execution fails" do
      let(:llm_response) do
        {
          content: '{"type": "file_writes", "files": []}',
          usage: {}
        }
      end

      before do
        allow(mock_llm_service).to receive(:chat).and_return(llm_response)
        allow(mock_strategy).to receive(:execute).and_return(
          { success: false, error: "Strategy failed" }
        )
      end

      it "returns error response" do
        result = runner.run
        expect(result[:success]).to be false
        expect(result[:error]).to include("Response validation failed")
      end
    end

    context "when exception occurs" do
      before do
        allow(mock_llm_service).to receive(:chat).and_raise(StandardError.new("Unexpected error"))
      end

      it "catches exception and returns error response" do
        result = runner.run
        expect(result[:success]).to be false
        expect(result[:error]).to eq("Unexpected error")
      end
    end
  end

  describe "#build_context" do
    it "builds context hash with project, work_item, and agent information" do
      context = runner.send(:build_context)

      expect(context[:project]).to include(
        name: project.name,
        slug: project.slug,
        state: project.state,
        brief: project.brief,
        repo_full_name: project.repo_full_name,
        repo_default_branch: project.repo_default_branch
      )

      expect(context[:work_item]).to include(
        id: work_item.id,
        work_type: work_item.work_type,
        payload: work_item.payload,
        priority: work_item.priority
      )

      expect(context[:agent]).to include(
        key: agent.key,
        name: agent.name,
        capabilities: agent.capabilities
      )
    end
  end

  describe "#resolve_strategy" do
    it "returns GitHubApiStrategy for setup work types" do
      work_item.update!(work_type: "rubocop_setup")
      strategy = runner.send(:resolve_strategy)
      expect(strategy).to be_a(GitHubApiStrategy)
    end

    it "returns FileWriteStrategy for gtm and docs work types" do
      work_item.update!(work_type: "gtm")
      strategy = runner.send(:resolve_strategy)
      expect(strategy).to be_a(FileWriteStrategy)
    end

    it "returns DatabaseStrategy for product_manager and orchestrator work types" do
      work_item.update!(work_type: "product_manager")
      strategy = runner.send(:resolve_strategy)
      expect(strategy).to be_a(DatabaseStrategy)
    end

    it "returns GitHubApiStrategy for issue work type" do
      work_item.update!(work_type: "issue")
      strategy = runner.send(:resolve_strategy)
      expect(strategy).to be_a(GitHubApiStrategy)
    end

    it "raises error for unknown work type" do
      work_item.update!(work_type: "unknown_type")
      expect { runner.send(:resolve_strategy) }.to raise_error(RuntimeError, /Unknown execution strategy/)
    end
  end
end
