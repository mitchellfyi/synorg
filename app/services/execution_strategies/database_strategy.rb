# frozen_string_literal: true

# Execution Strategy for agents that create work items in the database
# Handles agents like Product Manager and Orchestrator
class DatabaseStrategy
  attr_reader :project, :agent, :work_item

  def initialize(project:, agent:, work_item:)
    @project = project
    @agent = agent
    @work_item = work_item
  end

  def execute(parsed_response)
    return { success: false, error: "Invalid response type: #{parsed_response[:type]}" } unless parsed_response[:type] == "work_items"

    work_items_data = parsed_response[:work_items] || []
    return { success: false, error: "No work items provided" } if work_items_data.empty?

    created_work_items = []

    work_items_data.each do |wi_data|
      assigned_agent = find_agent(wi_data[:agent_key] || wi_data["agent_key"])
      next unless assigned_agent

      work_type = wi_data[:work_type] || wi_data["work_type"]
      created_wi = WorkItem.find_or_initialize_by(
        project: project,
        work_type: work_type
      )
      created_wi.status = "pending"
      created_wi.priority = wi_data[:priority] || wi_data["priority"] || 5
      created_wi.assigned_agent = assigned_agent
      created_wi.payload = wi_data[:payload] || wi_data["payload"] || {}
      created_wi.save!

      created_work_items << created_wi
    end

    {
      success: true,
      message: "Successfully created #{created_work_items.count} work items",
      work_items_created: created_work_items.count,
      work_item_ids: created_work_items.map(&:id)
    }
  rescue StandardError => e
    Rails.logger.error("DatabaseStrategy failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  def find_agent(agent_key)
    return nil unless agent_key

    Agent.find_by_cached(agent_key)
  end
end
