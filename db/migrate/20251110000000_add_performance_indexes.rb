# frozen_string_literal: true

class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # Work Items indexes
    # work_type is frequently queried (e.g., where(work_type: "issue"))
    # Check if index already exists before adding
    unless index_exists?(:work_items, :work_type)
      add_index :work_items, :work_type, name: "index_work_items_on_work_type"
    end

    # Composite index for project + work_type queries (common in webhook processor)
    unless index_exists?(:work_items, [:project_id, :work_type])
      add_index :work_items, [:project_id, :work_type], name: "index_work_items_on_project_id_and_work_type"
    end

    # Composite index for work_type + status queries
    unless index_exists?(:work_items, [:work_type, :status])
      add_index :work_items, [:work_type, :status], name: "index_work_items_on_work_type_and_status"
    end

    # created_at for ordering queries
    unless index_exists?(:work_items, :created_at)
      add_index :work_items, :created_at, name: "index_work_items_on_created_at"
    end

    # Runs indexes
    # Composite index for work_item + started_at ordering (common in controllers)
    # Note: index_runs_on_agent_id_and_started_at already exists, but we need work_item_id version
    unless index_exists?(:runs, [:work_item_id, :started_at])
      add_index :runs, [:work_item_id, :started_at], name: "index_runs_on_work_item_id_and_started_at"
    end

    # Composite index for work_item + outcome filtering
    unless index_exists?(:runs, [:work_item_id, :outcome])
      add_index :runs, [:work_item_id, :outcome], name: "index_runs_on_work_item_id_and_outcome"
    end

    # created_at for ordering queries
    unless index_exists?(:runs, :created_at)
      add_index :runs, :created_at, name: "index_runs_on_created_at"
    end

    # Projects indexes
    # Partial index for webhook_secret queries (only non-null values)
    # This is more efficient than a full index since most projects won't have webhooks
    unless index_exists?(:projects, :webhook_secret)
      add_index :projects, :webhook_secret, name: "index_projects_on_webhook_secret", where: "webhook_secret IS NOT NULL"
    end

    # created_at for ordering queries
    unless index_exists?(:projects, :created_at)
      add_index :projects, :created_at, name: "index_projects_on_created_at"
    end

    # Webhook Events indexes
    # Composite index for project + created_at ordering (common in controllers)
    unless index_exists?(:webhook_events, [:project_id, :created_at])
      add_index :webhook_events, [:project_id, :created_at], name: "index_webhook_events_on_project_id_and_created_at"
    end
  end
end

