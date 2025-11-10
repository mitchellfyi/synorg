# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :trigger_orchestrator]

  def index
    @projects = Project.left_joins(:work_items)
                       .select('projects.*,
                                COUNT(CASE WHEN work_items.status IN (\'pending\', \'in_progress\') THEN 1 END) as open_count,
                                COUNT(CASE WHEN work_items.status = \'completed\' THEN 1 END) as completed_count')
                       .group("projects.id")
                       .order(created_at: :desc)
  end

  def show
    @open_work_items = @project.work_items.where(status: %w[pending in_progress])
                               .order(priority: :desc, created_at: :asc)
                               .includes(:assigned_agent, :runs)
    @recent_work_items = @project.work_items
                                 .order(created_at: :desc)
                                 .limit(10)
                                 .includes(:assigned_agent, :runs)
    @total_runs_count = Run.joins(:work_item)
                           .where(work_items: { project_id: @project.id })
                           .count
    @activities = Activity.for_project(@project).recent.limit(50).includes(:owner, :trackable)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.state = "draft"

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project, notice: "Project was successfully created." }
        format.turbo_stream { redirect_to @project, notice: "Project was successfully created." }
      else
        format.html { render :new, status: :unprocessable_content }
        format.turbo_stream { render :new, status: :unprocessable_content }
      end
    end
  end

  def edit
  end

  def update
    # Don't update PAT or webhook_secret if they're blank (user wants to keep existing values)
    update_params = project_params.dup
    update_params.delete(:github_pat) if update_params[:github_pat].blank?
    update_params.delete(:webhook_secret) if update_params[:webhook_secret].blank?

    respond_to do |format|
      if @project.update(update_params)
        format.html { redirect_to @project, notice: "Project was successfully updated." }
        format.turbo_stream { redirect_to @project, notice: "Project was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream { render :edit, status: :unprocessable_content }
      end
    end
  end

  def trigger_orchestrator
    if @project.orchestrator_running?
      redirect_to @project, alert: "Orchestrator is already running for this project."
      return
    end

    # Find orchestrator agent
    orchestrator_agent = Agent.find_by_cached("orchestrator")
    unless orchestrator_agent&.enabled?
      redirect_to @project, alert: "Orchestrator agent not found or disabled."
      return
    end

    # Track orchestrator trigger activity
    Activity.create!(
      trackable: @project,
      owner: orchestrator_agent,
      recipient: @project,
      key: Activity::KEYS[:orchestrator_triggered],
      parameters: {
        agent_name: orchestrator_agent.name,
        agent_key: orchestrator_agent.key
      },
      project: @project,
      created_at: Time.current
    )

    # Create work item for orchestrator
    work_item = @project.work_items.create!(
      work_type: "orchestrator",
      status: "pending",
      priority: 10,
      payload: {
        "title" => "Run Orchestrator",
        "description" => "Orchestrator agent execution triggered manually"
      }
    )

    # Run orchestrator via AgentRunner (this will create a Run record)
    runner = AgentRunner.new(agent: orchestrator_agent, project: @project, work_item: work_item)
    result = runner.run

    # Track orchestrator completion activity
    if result[:success]
      work_items_created = result[:work_items_created] || 0
      Activity.create!(
        trackable: @project,
        owner: orchestrator_agent,
        recipient: @project,
        key: Activity::KEYS[:orchestrator_completed],
        parameters: {
          agent_name: orchestrator_agent.name,
          agent_key: orchestrator_agent.key,
          work_items_created: work_items_created
        },
        project: @project,
        created_at: Time.current
      )
      redirect_to @project, notice: "Orchestrator triggered successfully. #{work_items_created} work items created."
    else
      Activity.create!(
        trackable: @project,
        owner: orchestrator_agent,
        recipient: @project,
        key: Activity::KEYS[:orchestrator_failed],
        parameters: {
          agent_name: orchestrator_agent.name,
          agent_key: orchestrator_agent.key,
          error: result[:error]
        },
        project: @project,
        created_at: Time.current
      )
      redirect_to @project, alert: "Failed to trigger orchestrator: #{result[:error]}"
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :slug, :brief, :repo_full_name, :github_pat, :webhook_secret)
  end
end
