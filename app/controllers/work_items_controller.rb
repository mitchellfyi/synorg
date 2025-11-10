# frozen_string_literal: true

class WorkItemsController < ApplicationController
  before_action :set_project
  before_action :set_work_item, only: [:show, :retry]

  def show
    @runs = @work_item.runs.order(started_at: :desc).includes(:agent)
  end

  def retry
    if @work_item.status != "failed"
      redirect_to [@project, @work_item], alert: "Only failed work items can be retried."
      return
    end

    # Reset work item to pending
    @work_item.update!(
      status: "pending",
      locked_at: nil,
      locked_by_agent: nil
    )

    redirect_to [@project, @work_item], notice: "Work item queued for retry."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_work_item
    @work_item = @project.work_items.find(params[:id])
  end
end
