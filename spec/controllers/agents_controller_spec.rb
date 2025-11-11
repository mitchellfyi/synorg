# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentsController do
  describe "GET #index" do
    it "assigns all agents to @agents" do
      # Clean up any existing agents from other tests
      Agent.where.not(id: []).destroy_all
      agent1 = create(:agent, key: "agent-1")
      agent2 = create(:agent, key: "agent-2")

      get :index

      expect(assigns(:agents).to_a).to contain_exactly(agent1, agent2)
    end

    it "orders agents by key" do
      # Clean up any existing agents from other tests
      Agent.where.not(id: []).destroy_all
      agent_b = create(:agent, key: "b-agent")
      agent_a = create(:agent, key: "a-agent")

      get :index

      expect(assigns(:agents).to_a).to eq([agent_a, agent_b])
    end

    it "includes runs and assigned_work_items associations" do
      agent = create(:agent)
      create(:run, agent: agent)
      create(:work_item, assigned_agent: agent)

      get :index

      agent_result = assigns(:agents).find { |a| a.id == agent.id }
      expect(agent_result.association(:runs).loaded?).to be true
      expect(agent_result.association(:assigned_work_items).loaded?).to be true
    end

    it "renders the index template" do
      get :index
      expect(response).to render_template(:index)
    end
  end

  describe "GET #show" do
    let(:agent) { create(:agent) }
    let(:project) { create(:project) }
    let!(:older_run) { create(:run, agent: agent, started_at: 2.hours.ago) }
    let!(:newer_run) { create(:run, agent: agent, started_at: 1.hour.ago) }
    let!(:older_work_item) { create(:work_item, assigned_agent: agent, created_at: 2.days.ago) }
    let!(:newer_work_item) { create(:work_item, assigned_agent: agent, created_at: 1.day.ago) }

    before do
      get :show, params: { id: agent.id }
    end

    it "assigns the requested agent to @agent" do
      expect(assigns(:agent)).to eq(agent)
    end

    it "assigns recent runs ordered by started_at descending" do
      expect(assigns(:recent_runs)).to eq([newer_run, older_run])
    end

    it "limits recent runs to 20" do
      25.times { create(:run, agent: agent) }
      get :show, params: { id: agent.id }
      expect(assigns(:recent_runs).count).to eq(20)
    end

    it "includes work_item association for runs" do
      run_result = assigns(:recent_runs).first
      expect(run_result.association(:work_item).loaded?).to be true
    end

    it "assigns assigned work items ordered by created_at descending" do
      expect(assigns(:assigned_work_items)).to eq([newer_work_item, older_work_item])
    end

    it "limits assigned work items to 20" do
      25.times { create(:work_item, assigned_agent: agent) }
      get :show, params: { id: agent.id }
      expect(assigns(:assigned_work_items).count).to eq(20)
    end

    it "includes project association for work items" do
      work_item_result = assigns(:assigned_work_items).first
      expect(work_item_result.association(:project).loaded?).to be true
    end

    it "calculates agent stats" do
      # Use a fresh agent to avoid interference from other tests
      fresh_agent = create(:agent)
      create(:run, agent: fresh_agent, outcome: "success")
      create(:run, agent: fresh_agent, outcome: "failure")
      create(:run, agent: fresh_agent, finished_at: nil)
      create(:work_item, assigned_agent: fresh_agent, status: "pending")

      get :show, params: { id: fresh_agent.id }

      stats = assigns(:stats)
      expect(stats[:total_runs]).to eq(3)
      expect(stats[:successful_runs]).to eq(1)
      expect(stats[:failed_runs]).to eq(1)
      expect(stats[:in_progress_runs]).to eq(1)
      expect(stats[:assigned_work_items]).to eq(1)
      expect(stats[:pending_work_items]).to eq(1)
    end

    it "renders the show template" do
      expect(response).to render_template(:show)
    end
  end

  describe "GET #edit" do
    let(:agent) { create(:agent) }

    before do
      get :edit, params: { id: agent.id }
    end

    it "assigns the requested agent to @agent" do
      expect(assigns(:agent)).to eq(agent)
    end

    it "renders the edit template" do
      expect(response).to render_template(:edit)
    end
  end

  describe "PATCH #update" do
    let(:agent) { create(:agent, name: "Original Name", description: "Original Description") }

    context "with valid parameters" do
      it "updates the agent" do
        patch :update, params: { id: agent.id, agent: { name: "Updated Name", description: "Updated Description" } }
        agent.reload
        expect(agent.name).to eq("Updated Name")
        expect(agent.description).to eq("Updated Description")
      end

      it "redirects to the agent" do
        patch :update, params: { id: agent.id, agent: { name: "Updated Name" } }
        expect(response).to redirect_to(agent)
      end

      it "sets a flash notice" do
        patch :update, params: { id: agent.id, agent: { name: "Updated Name" } }
        expect(flash[:notice]).to eq("Agent was successfully updated.")
      end

      it "responds to turbo_stream format" do
        patch :update, params: { id: agent.id, agent: { name: "Updated Name" } }, format: :turbo_stream
        expect(response).to redirect_to(agent)
      end
    end

    context "with invalid parameters" do
      it "does not update the agent" do
        original_name = agent.name
        patch :update, params: { id: agent.id, agent: { name: "" } }
        agent.reload
        expect(agent.name).to eq(original_name)
      end

      it "renders the edit template" do
        patch :update, params: { id: agent.id, agent: { name: "" } }
        expect(response).to render_template(:edit)
      end

      it "returns unprocessable entity status" do
        patch :update, params: { id: agent.id, agent: { name: "" } }
        expect(response).to have_http_status(:unprocessable_content)
      end

      it "responds to turbo_stream format with redirect" do
        # Turbo stream format should redirect even on errors for consistency
        patch :update, params: { id: agent.id, agent: { name: "" } }, format: :turbo_stream
        expect(response).to redirect_to(agent)
      end
    end
  end

  describe "POST #toggle_enabled" do
    let(:agent) { create(:agent, enabled: true) }

    it "toggles enabled status" do
      post :toggle_enabled, params: { id: agent.id }
      agent.reload
      expect(agent.enabled).to be false

      post :toggle_enabled, params: { id: agent.id }
      agent.reload
      expect(agent.enabled).to be true
    end

    it "redirects to the agent" do
      post :toggle_enabled, params: { id: agent.id }
      expect(response).to redirect_to(agent)
    end

    it "sets appropriate flash notice when enabling" do
      agent.update!(enabled: false)
      post :toggle_enabled, params: { id: agent.id }
      expect(flash[:notice]).to eq("Agent enabled successfully.")
    end

    it "sets appropriate flash notice when disabling" do
      agent.update!(enabled: true)
      post :toggle_enabled, params: { id: agent.id }
      expect(flash[:notice]).to eq("Agent disabled successfully.")
    end
  end
end
