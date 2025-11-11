# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkItemsController do
  let(:project) { create(:project) }
  let(:agent) { create(:agent) }

  describe "GET #show" do
    let(:work_item) { create(:work_item, project: project) }
    let!(:older_run) { create(:run, work_item: work_item, agent: agent, started_at: 2.hours.ago) }
    let!(:newer_run) { create(:run, work_item: work_item, agent: agent, started_at: 1.hour.ago) }

    before do
      get :show, params: { project_id: project.id, id: work_item.id }
    end

    it "assigns the project to @project" do
      expect(assigns(:project)).to eq(project)
    end

    it "assigns the work item to @work_item" do
      expect(assigns(:work_item)).to eq(work_item)
    end

    it "assigns runs ordered by started_at descending" do
      expect(assigns(:runs)).to eq([newer_run, older_run])
    end

    it "includes agent association for runs" do
      run_result = assigns(:runs).first
      expect(run_result.association(:agent).loaded?).to be true
    end

    it "renders the show template" do
      expect(response).to render_template(:show)
    end

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #retry" do
    let(:work_item) { create(:work_item, project: project, status: "failed", locked_at: 1.hour.ago, locked_by_agent: agent) }

    context "when work item is failed" do
      it "resets work item to pending" do
        post :retry, params: { project_id: project.id, id: work_item.id }
        work_item.reload
        expect(work_item.status).to eq("pending")
        expect(work_item.locked_at).to be_nil
        expect(work_item.locked_by_agent).to be_nil
      end

      it "redirects to the work item" do
        post :retry, params: { project_id: project.id, id: work_item.id }
        expect(response).to redirect_to([project, work_item])
      end

      it "sets a flash notice" do
        post :retry, params: { project_id: project.id, id: work_item.id }
        expect(flash[:notice]).to eq("Work item queued for retry.")
      end
    end

    context "when work item is not failed" do
      it "does not change the work item status" do
        work_item.update!(status: "pending")
        original_status = work_item.status
        post :retry, params: { project_id: project.id, id: work_item.id }
        work_item.reload
        expect(work_item.status).to eq(original_status)
      end

      it "redirects with alert" do
        work_item.update!(status: "pending")
        post :retry, params: { project_id: project.id, id: work_item.id }
        expect(response).to redirect_to([project, work_item])
        expect(flash[:alert]).to eq("Only failed work items can be retried.")
      end
    end

    context "when work item belongs to different project" do
      let(:other_project) { create(:project) }

      it "raises ActiveRecord::RecordNotFound" do
        expect do
          post :retry, params: { project_id: other_project.id, id: work_item.id }
        end.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
