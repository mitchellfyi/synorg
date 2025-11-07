# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookEventProcessor do
  let(:project) { create(:project) }

  describe "#process" do
    context "with issues event" do
      let(:payload) do
        {
          "action" => "opened",
          "issue" => {
            "number" => 123,
            "title" => "Test Issue",
            "body" => "Test body",
            "state" => "open",
            "labels" => [{ "name" => "bug" }],
            "html_url" => "https://github.com/test/repo/issues/123"
          }
        }
      end

      it "creates a work item for opened issue" do
        processor = described_class.new(project, "issues", payload)

        expect { processor.process }.to change(WorkItem, :count).by(1)

        work_item = project.work_items.last
        expect(work_item.work_type).to eq("issue")
        expect(work_item.payload["issue_number"]).to eq(123)
        expect(work_item.payload["title"]).to eq("Test Issue")
        expect(work_item.payload["labels"]).to eq(["bug"])
        expect(work_item.status).to eq("pending")
      end

      it "updates existing work item on labeled action" do
        create(:work_item, project: project, work_type: "issue", payload: { issue_number: 123 })

        payload["action"] = "labeled"
        processor = described_class.new(project, "issues", payload)

        expect { processor.process }.not_to change(WorkItem, :count)

        work_item = project.work_items.last
        expect(work_item.payload["labels"]).to eq(["bug"])
      end

      it "marks work item completed on closed action" do
        work_item = create(:work_item, project: project, work_type: "issue", payload: { issue_number: 123 }, status: "pending")

        payload["action"] = "closed"
        payload["issue"]["state"] = "closed"
        processor = described_class.new(project, "issues", payload)

        processor.process

        work_item.reload
        expect(work_item.status).to eq("completed")
      end
    end

    context "with pull_request event" do
      let(:agent) { create(:agent) }
      let(:work_item) { create(:work_item, project: project, work_type: "issue", payload: { issue_number: 123 }, assigned_agent: agent) }
      let(:payload) do
        {
          "action" => "opened",
          "pull_request" => {
            "number" => 45,
            "title" => "Fix issue",
            "body" => "Fixes #123",
            "state" => "open",
            "merged" => false,
            "html_url" => "https://github.com/test/repo/pull/45"
          }
        }
      end

      before { work_item } # Create the work item

      it "creates a run for opened pull request" do
        processor = described_class.new(project, "pull_request", payload)

        expect { processor.process }.to change(Run, :count).by(1)

        run = work_item.runs.last
        expect(run.agent).to eq(agent)
        expect(run.logs_url).to eq("https://github.com/test/repo/pull/45")
      end

      it "updates run outcome on merged pull request" do
        run = create(:run, agent: agent, work_item: work_item)

        payload["action"] = "closed"
        payload["pull_request"]["merged"] = true
        processor = described_class.new(project, "pull_request", payload)

        processor.process

        run.reload
        expect(run.outcome).to eq("success")
        expect(run.finished_at).not_to be_nil

        work_item.reload
        expect(work_item.status).to eq("completed")
      end

      it "updates run outcome on closed without merge" do
        run = create(:run, agent: agent, work_item: work_item)

        payload["action"] = "closed"
        payload["pull_request"]["merged"] = false
        processor = described_class.new(project, "pull_request", payload)

        processor.process

        run.reload
        expect(run.outcome).to eq("failure")
        expect(run.finished_at).not_to be_nil

        work_item.reload
        expect(work_item.status).not_to eq("completed")
      end
    end

    context "with push event" do
      let(:payload) do
        {
          "ref" => "refs/heads/main",
          "commits" => []
        }
      end

      it "processes push event successfully" do
        processor = described_class.new(project, "push", payload)

        expect(processor.process).to be true
      end
    end

    context "with workflow_run event" do
      let(:agent) { create(:agent) }
      let(:work_item) { create(:work_item, project: project, assigned_agent: agent) }
      let(:run) { create(:run, agent: agent, work_item: work_item, logs_url: "https://github.com/test/repo/actions/runs/123") }
      let(:payload) do
        {
          "action" => "completed",
          "workflow_run" => {
            "id" => 123,
            "conclusion" => "success",
            "html_url" => "https://github.com/test/repo/actions/runs/123",
            "updated_at" => Time.current.iso8601
          }
        }
      end

      before { run }

      it "updates run outcome on completed workflow" do
        processor = described_class.new(project, "workflow_run", payload)

        processor.process

        run.reload
        expect(run.outcome).to eq("success")
        expect(run.finished_at).not_to be_nil
      end
    end

    context "with check_suite event" do
      let(:payload) do
        {
          "action" => "completed",
          "check_suite" => {
            "id" => 456,
            "conclusion" => "success",
            "head_sha" => "abc123"
          }
        }
      end

      it "processes check suite event successfully" do
        processor = described_class.new(project, "check_suite", payload)

        expect(processor.process).to be true
      end
    end

    context "with unsupported event type" do
      it "returns false and logs a warning" do
        processor = described_class.new(project, "unsupported_event", {})

        expect(processor.process).to be false
      end
    end
  end
end
