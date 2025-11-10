# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:user) { nil } # No authentication required for now
  let(:project) { create(:project) }

  describe "GET /projects" do
    it "returns successful response" do
      create_list(:project, 3)
      get projects_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Projects")
    end

    it "displays projects with work item counts" do
      project_with_items = create(:project)
      create_list(:work_item, 2, project: project_with_items, status: "pending")
      create_list(:work_item, 3, project: project_with_items, status: "completed")

      get projects_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(project_with_items.name)
    end

    it "orders projects by created_at desc" do
      old_project = create(:project, created_at: 2.days.ago)
      new_project = create(:project, created_at: 1.day.ago)

      get projects_path

      expect(response).to have_http_status(:success)
      # Newer project should appear first
      expect(response.body.index(new_project.name)).to be < response.body.index(old_project.name)
    end
  end

  describe "GET /projects/:id" do
    it "returns successful response" do
      get project_path(project)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(project.name)
    end

    it "displays open work items" do
      open_item = create(:work_item, project: project, status: "pending")
      completed_item = create(:work_item, project: project, status: "completed")

      get project_path(project)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(open_item.work_type)
      # Completed items may or may not be shown depending on view
    end

    it "displays recent runs" do
      agent = create(:agent)
      work_item = create(:work_item, project: project)
      run = create(:run, agent: agent, work_item: work_item, started_at: 1.hour.ago)

      get project_path(project)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(agent.name)
    end

    it "displays total runs count" do
      agent = create(:agent)
      work_item = create(:work_item, project: project)
      create_list(:run, 5, agent: agent, work_item: work_item)

      get project_path(project)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("5") # Total runs count
    end
  end

  describe "GET /projects/new" do
    it "returns successful response" do
      get new_project_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("New Project")
    end
  end

  describe "POST /projects" do
    let(:valid_attributes) do
      {
        name: "Test Project",
        slug: "test-project",
        brief: "A test project",
        repo_full_name: "test/repo"
      }
    end

    it "creates a new project" do
      expect do
        post projects_path, params: { project: valid_attributes }
      end.to change(Project, :count).by(1)

      expect(response).to redirect_to(project_path(Project.last))
      follow_redirect!
      expect(response.body).to include("successfully created")
    end

    it "sets project state to draft" do
      post projects_path, params: { project: valid_attributes }

      expect(Project.last.state).to eq("draft")
    end

    it "renders errors for invalid project" do
      invalid_attributes = valid_attributes.merge(slug: "")

      expect do
        post projects_path, params: { project: invalid_attributes }
      end.not_to change(Project, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("errors")
    end
  end

  describe "GET /projects/:id/edit" do
    it "returns successful response" do
      get edit_project_path(project)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Edit Project")
    end
  end

  describe "PATCH /projects/:id" do
    it "updates project" do
      patch project_path(project), params: { project: { name: "Updated Name" } }

      expect(response).to redirect_to(project_path(project))
      expect(project.reload.name).to eq("Updated Name")
    end

    it "renders errors for invalid update" do
      patch project_path(project), params: { project: { slug: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("errors")
    end
  end

  describe "POST /projects/:id/trigger_orchestrator" do
    let(:orchestrator_agent) { create(:agent, key: "orchestrator", enabled: true, prompt: "Test prompt") }

    before do
      allow(Agent).to receive(:find_by_cached).with("orchestrator").and_return(orchestrator_agent)
    end

    context "when orchestrator is not running" do
      before do
        allow(project).to receive(:orchestrator_running?).and_return(false)
      end

      it "triggers orchestrator successfully" do
        mock_runner = instance_double(AgentRunner)
        allow(AgentRunner).to receive(:new).and_return(mock_runner)
        allow(mock_runner).to receive(:run).and_return(
          {
            success: true,
            work_items_created: 3
          }
        )

        expect do
          post trigger_orchestrator_project_path(project)
        end.to change { project.work_items.count }.by(1)

        expect(response).to redirect_to(project_path(project))
        follow_redirect!
        expect(response.body).to include("successfully")
      end

      it "handles orchestrator failure" do
        mock_runner = instance_double(AgentRunner)
        allow(AgentRunner).to receive(:new).and_return(mock_runner)
        allow(mock_runner).to receive(:run).and_return(
          {
            success: false,
            error: "LLM API error"
          }
        )

        post trigger_orchestrator_project_path(project)

        expect(response).to redirect_to(project_path(project))
        follow_redirect!
        expect(response.body).to include("Failed")
      end
    end

    context "when orchestrator is already running" do
      before do
        allow(project).to receive(:orchestrator_running?).and_return(true)
      end

      it "redirects with alert" do
        post trigger_orchestrator_project_path(project)

        expect(response).to redirect_to(project_path(project))
        follow_redirect!
        expect(response.body).to include("already running")
      end
    end

    context "when orchestrator agent is not found or disabled" do
      before do
        allow(project).to receive(:orchestrator_running?).and_return(false)
        allow(Agent).to receive(:find_by_cached).with("orchestrator").and_return(nil)
      end

      it "redirects with alert" do
        post trigger_orchestrator_project_path(project)

        expect(response).to redirect_to(project_path(project))
        follow_redirect!
        expect(response.body).to include("not found or disabled")
      end
    end
  end
end

