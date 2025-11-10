# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: [:show]

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
    @recent_runs = Run.joins(:work_item)
                      .where(work_items: { project_id: @project.id })
                      .includes(:agent, :work_item)
                      .order(started_at: :desc)
                      .limit(10)
    @total_runs_count = Run.joins(:work_item)
                           .where(work_items: { project_id: @project.id })
                           .count
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    @project.state = "draft"

    if @project.save
      redirect_to @project, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :slug, :brief, :repo_full_name, :github_pat_secret_name)
  end
end
