# frozen_string_literal: true

class AgentsController < ApplicationController
  before_action :set_agent, only: [:show, :edit, :update, :toggle_enabled]

  def index
    @agents = Agent.order(:key).includes(:runs, :assigned_work_items)
  end

  def show
    @recent_runs = @agent.runs.order(started_at: :desc).limit(20).includes(:work_item)
    @assigned_work_items = @agent.assigned_work_items.order(created_at: :desc).limit(20).includes(:project)
    @stats = calculate_agent_stats
  end

  def edit
  end

  def update
    respond_to do |format|
      if @agent.update(agent_params)
        format.html { redirect_to @agent, notice: "Agent was successfully updated." }
        format.turbo_stream { redirect_to @agent, notice: "Agent was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream { render :edit, status: :unprocessable_content }
      end
    end
  end

  def toggle_enabled
    @agent.update!(enabled: !@agent.enabled)
    redirect_to @agent, notice: "Agent #{@agent.enabled? ? 'enabled' : 'disabled'} successfully."
  end

  private

  def set_agent
    @agent = Agent.find(params[:id])
  end

  def agent_params
    params.expect(agent: [:name, :description, :prompt, :enabled, :max_concurrency, capabilities: {}])
  end

  def calculate_agent_stats
    {
      total_runs: @agent.runs.count,
      successful_runs: @agent.runs.successful.count,
      failed_runs: @agent.runs.failed.count,
      in_progress_runs: @agent.runs.in_progress.count,
      assigned_work_items: @agent.assigned_work_items.count,
      pending_work_items: @agent.assigned_work_items.pending.count
    }
  end
end
