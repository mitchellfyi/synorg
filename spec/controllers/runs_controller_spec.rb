# frozen_string_literal: true

require "rails_helper"

RSpec.describe RunsController, type: :controller do
  let(:project) { create(:project) }
  let(:agent) { create(:agent) }
  let(:work_item1) { create(:work_item, project: project) }
  let(:work_item2) { create(:work_item, project: project) }
  let(:other_project) { create(:project, slug: "other-project") }
  let(:other_work_item) { create(:work_item, project: other_project) }

  describe "GET #index" do
    let!(:run1) { create(:run, work_item: work_item1, agent: agent, started_at: 1.hour.ago) }
    let!(:run2) { create(:run, work_item: work_item2, agent: agent, started_at: 2.hours.ago) }
    let!(:other_run) { create(:run, work_item: other_work_item, agent: agent, started_at: 30.minutes.ago) }

    before do
      get :index, params: { project_id: project.id }
    end

    it "assigns the project to @project" do
      expect(assigns(:project)).to eq(project)
    end

    it "assigns runs for the project to @runs" do
      expect(assigns(:runs)).to match_array([run1, run2])
    end

    it "does not include runs from other projects" do
      expect(assigns(:runs)).not_to include(other_run)
    end

    it "orders runs by started_at descending" do
      expect(assigns(:runs)).to eq([run1, run2])
    end

    it "limits runs to 100" do
      # Create more than 100 runs for the project
      105.times do |i|
        create(:run, work_item: work_item1, agent: agent, started_at: (i + 3).hours.ago)
      end

      get :index, params: { project_id: project.id }

      expect(assigns(:runs).count).to eq(100)
    end

    it "renders the index template" do
      expect(response).to render_template(:index)
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end

  context "when project not found" do
    it "raises ActiveRecord::RecordNotFound" do
      expect do
        get :index, params: { project_id: 99999 }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
