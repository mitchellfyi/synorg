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
    @recent_runs = Run.joins(:work_item)
                      .where(work_items: { project_id: @project.id })
                      .order(started_at: :desc)
                      .limit(10)
                      .includes(:agent, :work_item)
    @total_runs_count = Run.joins(:work_item)
                           .where(work_items: { project_id: @project.id })
                           .count
    @activities = Activity.for_project(@project).recent.limit(50).includes(:owner, :trackable)
  end

  def new
    @project = Project.new
  end

  def edit
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


  def update
    # Update all fields including PAT and webhook_secret
    respond_to do |format|
      if @project.update(project_params)
        format.html { redirect_to @project, notice: "Project was successfully updated." }
        format.turbo_stream { redirect_to @project, notice: "Project was successfully updated." }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.turbo_stream { render :edit, status: :unprocessable_content }
      end
    end
  end

  def trigger_orchestrator
    service = OrchestratorTriggerService.new(@project)
    result = service.call

    if result[:success]
      redirect_to @project, notice: result[:message]
    else
      redirect_to @project, alert: result[:message]
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.expect(project: [:name, :slug, :brief, :repo_full_name, :github_pat, :webhook_secret])
  end
end
