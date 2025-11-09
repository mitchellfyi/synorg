# frozen_string_literal: true

class RunsController < ApplicationController
  before_action :set_project

  def index
    @runs = Run.joins(:work_item)
               .where(work_items: { project_id: @project.id })
               .includes(:agent, :work_item)
               .order(started_at: :desc)
               .limit(100)
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end
end
