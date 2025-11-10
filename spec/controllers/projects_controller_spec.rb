# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectsController, type: :controller do
  describe "GET #index" do
    it "assigns all projects to @projects" do
      project1 = create(:project, slug: "project-1")
      project2 = create(:project, slug: "project-2")

      get :index

      expect(assigns(:projects)).to match_array([project1, project2])
    end

    it "orders projects by created_at descending" do
      older_project = create(:project, slug: "older", created_at: 2.days.ago)
      newer_project = create(:project, slug: "newer", created_at: 1.day.ago)

      get :index

      expect(assigns(:projects)).to eq([newer_project, older_project])
    end

    it "includes aggregated work item counts" do
      project = create(:project)
      create(:work_item, project: project, status: "pending")
      create(:work_item, project: project, status: "in_progress")
      create(:work_item, project: project, status: "completed")

      get :index

      project_result = assigns(:projects).find { |p| p.id == project.id }
      expect(project_result.open_count).to eq(2)
      expect(project_result.completed_count).to eq(1)
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template(:index)
    end
  end

  describe "GET #show" do
    let(:project) { create(:project) }
    let(:agent) { create(:agent) }
    let!(:work_item1) { create(:work_item, project: project, status: "pending", priority: 10) }
    let!(:work_item2) { create(:work_item, project: project, status: "in_progress", priority: 5) }
    let!(:work_item3) { create(:work_item, project: project, status: "completed") }
    let!(:run1) { create(:run, work_item: work_item1, agent: agent, started_at: 1.hour.ago) }
    let!(:run2) { create(:run, work_item: work_item2, agent: agent, started_at: 2.hours.ago) }

    before do
      get :show, params: { id: project.id }
    end

    it "assigns the requested project to @project" do
      expect(assigns(:project)).to eq(project)
    end

    it "assigns open work items (pending and in_progress)" do
      expect(assigns(:open_work_items)).to match_array([work_item1, work_item2])
    end

    it "does not include completed work items in @open_work_items" do
      expect(assigns(:open_work_items)).not_to include(work_item3)
    end

    it "orders open work items by priority descending, then created_at ascending" do
      expect(assigns(:open_work_items)).to eq([work_item1, work_item2])
    end

    it "assigns recent runs ordered by started_at descending" do
      expect(assigns(:recent_runs)).to eq([run1, run2])
    end

    it "limits recent runs to 10" do
      # Create more than 10 runs
      11.times do |i|
        create(:run, work_item: work_item1, agent: agent, started_at: (i + 3).hours.ago)
      end

      get :show, params: { id: project.id }

      expect(assigns(:recent_runs).count).to eq(10)
    end

    it "assigns total runs count" do
      expect(assigns(:total_runs_count)).to eq(2)
    end

    it "renders the show template" do
      expect(response).to render_template(:show)
    end
  end

  describe "GET #new" do
    it "assigns a new project to @project" do
      get :new
      expect(assigns(:project)).to be_a_new(Project)
    end

    it "renders the new template" do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe "POST #create" do
    context "with valid parameters" do
      let(:valid_attributes) do
        {
          slug: "test-project",
          name: "Test Project",
          brief: "A test project"
        }
      end

      it "creates a new Project" do
        expect do
          post :create, params: { project: valid_attributes }
        end.to change(Project, :count).by(1)
      end

      it "sets the project state to draft" do
        post :create, params: { project: valid_attributes }
        expect(Project.last.state).to eq("draft")
      end

      it "redirects to the created project" do
        post :create, params: { project: valid_attributes }
        expect(response).to redirect_to(Project.last)
      end

      it "sets a flash notice" do
        post :create, params: { project: valid_attributes }
        expect(flash[:notice]).to eq("Project was successfully created.")
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          slug: "", # slug is required
          name: "Test Project"
        }
      end

      it "does not create a new Project" do
        expect do
          post :create, params: { project: invalid_attributes }
        end.not_to change(Project, :count)
      end

      it "renders the new template" do
        post :create, params: { project: invalid_attributes }
        expect(response).to render_template(:new)
      end

      it "returns unprocessable entity status" do
        post :create, params: { project: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "with duplicate slug" do
      let!(:existing_project) { create(:project, slug: "duplicate") }
      let(:duplicate_attributes) do
        {
          slug: "duplicate",
          name: "Another Project"
        }
      end

      it "does not create a new Project" do
        expect do
          post :create, params: { project: duplicate_attributes }
        end.not_to change(Project, :count)
      end

      it "renders the new template with errors" do
        post :create, params: { project: duplicate_attributes }
        expect(response).to render_template(:new)
        expect(assigns(:project).errors[:slug]).to be_present
      end
    end
  end
end
