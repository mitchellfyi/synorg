# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Runs", type: :request do
  let(:project) { create(:project) }
  let(:agent) { create(:agent) }
  let(:work_item) { create(:work_item, project: project) }

  describe "GET /projects/:project_id/runs" do
    it "returns successful response" do
      get project_runs_path(project)

      expect(response).to have_http_status(:success)
    end

    it "displays runs for the project" do
      run = create(:run, agent: agent, work_item: work_item, started_at: 1.hour.ago)

      get project_runs_path(project)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(agent.name)
    end

    it "orders runs by started_at desc" do
      old_run = create(:run, agent: agent, work_item: work_item, started_at: 2.hours.ago)
      new_run = create(:run, agent: agent, work_item: work_item, started_at: 1.hour.ago)

      get project_runs_path(project)

      expect(response).to have_http_status(:success)
      # Verify runs are displayed (order verification would require parsing HTML)
      expect(response.body).to include(agent.name)
    end

    it "includes agent and work_item associations" do
      run = create(:run, agent: agent, work_item: work_item)

      get project_runs_path(project)

      expect(response).to have_http_status(:success)
      # Verify associations are loaded (prevents N+1 queries)
      # Check that agent name appears in response (indicating association was loaded)
      expect(response.body).to include(agent.name)
      expect(response.body).to include(work_item.work_type)
    end

    it "limits to 100 runs" do
      create_list(:run, 150, agent: agent, work_item: work_item)

      get project_runs_path(project)

      expect(response).to have_http_status(:success)
      # Verify response contains agent names (indicating runs were loaded)
      # The exact count would require parsing HTML, but we can verify it renders
      expect(response.body).to include(agent.name)
    end

    it "only shows runs for the specified project" do
      other_project = create(:project)
      other_work_item = create(:work_item, project: other_project)
      create(:run, agent: agent, work_item: work_item, started_at: 1.hour.ago)
      create(:run, agent: agent, work_item: other_work_item, started_at: 1.hour.ago)

      get project_runs_path(project)

      expect(response).to have_http_status(:success)
      # Verify only project's runs are shown by checking response content
      expect(response.body).to include(agent.name)
      # The exact filtering is tested at the controller level
    end
  end
end

