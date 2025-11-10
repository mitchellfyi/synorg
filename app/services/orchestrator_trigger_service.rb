# frozen_string_literal: true

# Service to handle orchestrator triggering
# Extracted from ProjectsController to follow Single Responsibility Principle
class OrchestratorTriggerService
  attr_reader :project, :orchestrator_agent

  def initialize(project)
    @project = project
    @orchestrator_agent = Agent.find_by(key: "orchestrator")
  end

  def call
    return error_result("Orchestrator is already running for this project.") if project.orchestrator_running?
    return error_result("Orchestrator agent not found or disabled.") unless orchestrator_agent&.enabled?

    # Track orchestrator trigger activity
    project.create_activity(
      :orchestrator_triggered,
      owner: orchestrator_agent,
      parameters: {
        agent_name: orchestrator_agent.name,
        agent_key: orchestrator_agent.key
      }
    )

    # Create work item for orchestrator
    work_item = project.work_items.create!(
      work_type: "orchestrator",
      status: "pending",
      priority: 10,
      payload: {
        "title" => "Run Orchestrator",
        "description" => "Orchestrator agent execution triggered manually"
      }
    )

    # Run orchestrator via AgentRunner
    runner = AgentRunner.new(agent: orchestrator_agent, project: project, work_item: work_item)
    result = runner.run

    # Track orchestrator completion activity
    if result[:success]
      work_items_created = result[:work_items_created] || 0
      project.create_activity(
        :orchestrator_completed,
        owner: orchestrator_agent,
        parameters: {
          agent_name: orchestrator_agent.name,
          agent_key: orchestrator_agent.key,
          work_items_created: work_items_created
        }
      )
      success_result("Orchestrator triggered successfully. #{work_items_created} work items created.", work_items_created)
    else
      project.create_activity(
        :orchestrator_failed,
        owner: orchestrator_agent,
        parameters: {
          agent_name: orchestrator_agent.name,
          agent_key: orchestrator_agent.key,
          error: result[:error]
        }
      )
      error_result("Failed to trigger orchestrator: #{result[:error]}")
    end
  end

  private

  def success_result(message, work_items_created = 0)
    {
      success: true,
      message: message,
      work_items_created: work_items_created
    }
  end

  def error_result(message)
    {
      success: false,
      message: message
    }
  end
end
