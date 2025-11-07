# frozen_string_literal: true

# Product Manager Agent Service
#
# This service interprets the project brief and GTM output to create
# an initial project scope with actionable work items.
#
# Example usage:
#   project_brief = "A collaborative task management tool..."
#   service = ProductManagerAgentService.new(project_brief)
#   result = service.run
#   # => { success: true, work_items_created: 5, ... }
#
class ProductManagerAgentService
  attr_reader :project_brief, :gtm_positioning

  def initialize(project_brief, gtm_positioning: nil)
    @project_brief = project_brief
    @gtm_positioning = gtm_positioning || read_gtm_positioning
  end

  def run
    Rails.logger.info("Product Manager Agent: Creating work items from project brief")

    # Read the agent prompt for context
    prompt = read_prompt

    # Stub: In production, this would call an LLM API to generate tasks
    # For now, create basic work items
    work_items = create_work_items

    Rails.logger.info("Product Manager Agent: Created #{work_items.count} work items")

    {
      success: true,
      work_items_created: work_items.count,
      work_item_ids: work_items.map(&:id),
      message: "Successfully created #{work_items.count} work items"
    }
  rescue StandardError => e
    Rails.logger.error("Product Manager Agent failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end

  private

  def read_prompt
    prompt_path = Rails.root.join("agents", "product_manager", "prompt.md")
    File.read(prompt_path)
  rescue Errno::ENOENT
    Rails.logger.warn("Product Manager Agent: Prompt file not found at #{prompt_path}")
    nil
  end

  def read_gtm_positioning
    positioning_path = Rails.root.join("docs", "product", "positioning.md")
    File.read(positioning_path)
  rescue Errno::ENOENT
    Rails.logger.warn("Product Manager Agent: GTM positioning not found")
    nil
  end

  def create_work_items
    # Stub implementation - in production, this would use an LLM to generate tasks
    tasks = [
      {
        title: "Set up project infrastructure",
        description: "Initialize the project with necessary configuration, dependencies, and basic structure. " \
                    "This includes setting up the Rails application, database, and essential gems.",
        priority: 1
      },
      {
        title: "Implement user authentication",
        description: "Create user model and implement authentication system. Include sign up, sign in, " \
                    "sign out, and password reset functionality.",
        priority: 2
      },
      {
        title: "Design and implement core data models",
        description: "Create database schema and ActiveRecord models for the core entities identified in " \
                    "the project brief. Include validations and associations.",
        priority: 3
      },
      {
        title: "Build primary user interface",
        description: "Implement the main user interface with key user flows. Use Hotwire for interactivity " \
                    "and Tailwind for styling.",
        priority: 4
      },
      {
        title: "Add background job processing",
        description: "Set up Solid Queue for background job processing. Implement jobs for async operations " \
                    "identified in the project requirements.",
        priority: 5
      },
      {
        title: "Implement testing suite",
        description: "Add comprehensive RSpec tests for models, controllers, and key user flows. " \
                    "Set up test fixtures and factories.",
        priority: 6
      }
    ]

    tasks.map do |task_attrs|
      WorkItem.create!(
        type: "task",
        title: task_attrs[:title],
        description: task_attrs[:description],
        status: "pending",
        priority: task_attrs[:priority]
      )
    end
  end
end
