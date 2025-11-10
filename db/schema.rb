# frozen_string_literal: true
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_10_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "activities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.bigint "owner_id"
    t.string "owner_type"
    t.jsonb "parameters"
    t.bigint "project_id", null: false
    t.bigint "recipient_id"
    t.string "recipient_type"
    t.bigint "trackable_id", null: false
    t.string "trackable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_activities_on_created_at"
    t.index ["key"], name: "index_activities_on_key"
    t.index ["owner_id", "owner_type"], name: "index_activities_on_owner_id_and_owner_type"
    t.index ["owner_type", "owner_id"], name: "index_activities_on_owner"
    t.index ["project_id"], name: "index_activities_on_project_id"
    t.index ["recipient_id", "recipient_type"], name: "index_activities_on_recipient_id_and_recipient_type"
    t.index ["recipient_type", "recipient_id"], name: "index_activities_on_recipient"
    t.index ["trackable_id", "trackable_type"], name: "index_activities_on_trackable_id_and_trackable_type"
    t.index ["trackable_type", "trackable_id"], name: "index_activities_on_trackable"
  end

  create_table "agents", force: :cascade do |t|
    t.json "capabilities", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.integer "max_concurrency", default: 1
    t.string "name", null: false
    t.text "prompt"
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_agents_on_enabled"
    t.index ["key"], name: "index_agents_on_key", unique: true
  end

  create_table "integrations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.string "status", default: "active"
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["project_id", "kind"], name: "index_integrations_on_project_id_and_kind"
    t.index ["project_id"], name: "index_integrations_on_project_id"
    t.index ["status"], name: "index_integrations_on_status"
  end

  create_table "policies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.json "value", default: {}
    t.index ["project_id", "key"], name: "index_policies_on_project_id_and_key", unique: true
    t.index ["project_id"], name: "index_policies_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.text "brief"
    t.datetime "created_at", null: false
    t.boolean "e2e_required", default: true, null: false
    t.json "gates_config", default: {}
    t.text "github_pat"
    t.string "github_pat_secret_name"
    t.string "name"
    t.string "repo_default_branch"
    t.string "repo_full_name"
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.text "webhook_secret"
    t.index ["created_at"], name: "index_projects_on_created_at"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["state"], name: "index_projects_on_state"
    t.index ["webhook_secret"], name: "index_projects_on_webhook_secret", where: "(webhook_secret IS NOT NULL)"
  end

  create_table "runs", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "artifacts_url"
    t.json "costs", default: {}
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.bigint "github_check_suite_id"
    t.string "github_pr_head_sha"
    t.integer "github_pr_number"
    t.string "idempotency_key"
    t.text "logs"
    t.string "logs_url"
    t.string "outcome"
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.bigint "work_item_id", null: false
    t.index ["agent_id", "started_at"], name: "index_runs_on_agent_id_and_started_at"
    t.index ["agent_id"], name: "index_runs_on_agent_id"
    t.index ["created_at"], name: "index_runs_on_created_at"
    t.index ["github_check_suite_id"], name: "index_runs_on_github_check_suite_id"
    t.index ["github_pr_head_sha"], name: "index_runs_on_github_pr_head_sha"
    t.index ["github_pr_number"], name: "index_runs_on_github_pr_number"
    t.index ["idempotency_key"], name: "index_runs_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["outcome"], name: "index_runs_on_outcome"
    t.index ["work_item_id", "outcome"], name: "index_runs_on_work_item_id_and_outcome"
    t.index ["work_item_id", "started_at"], name: "index_runs_on_work_item_id_and_started_at"
    t.index ["work_item_id"], name: "index_runs_on_work_item_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "delivery_id", null: false
    t.string "event_type", null: false
    t.json "payload", default: {}, null: false
    t.bigint "project_id", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_webhook_events_on_delivery_id", unique: true
    t.index ["event_type"], name: "index_webhook_events_on_event_type"
    t.index ["project_id", "created_at"], name: "index_webhook_events_on_project_id_and_created_at"
    t.index ["project_id", "event_type"], name: "index_webhook_events_on_project_id_and_event_type"
    t.index ["project_id"], name: "index_webhook_events_on_project_id"
  end

  create_table "work_items", force: :cascade do |t|
    t.bigint "assigned_agent_id"
    t.datetime "created_at", null: false
    t.datetime "locked_at"
    t.bigint "locked_by_agent_id"
    t.json "payload", default: {}
    t.integer "priority", default: 0
    t.bigint "project_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.string "work_type", null: false
    t.index ["assigned_agent_id"], name: "index_work_items_on_assigned_agent_id"
    t.index ["created_at"], name: "index_work_items_on_created_at"
    t.index ["locked_by_agent_id"], name: "index_work_items_on_locked_by_agent_id"
    t.index ["priority"], name: "index_work_items_on_priority"
    t.index ["project_id", "work_type"], name: "index_work_items_on_project_id_and_work_type"
    t.index ["project_id"], name: "index_work_items_on_project_id"
    t.index ["status", "priority", "locked_at"], name: "index_work_items_on_status_and_priority_and_locked_at"
    t.index ["status"], name: "index_work_items_on_status"
    t.index ["work_type", "status"], name: "index_work_items_on_work_type_and_status"
    t.index ["work_type"], name: "index_work_items_on_work_type"
  end

  add_foreign_key "activities", "projects"
  add_foreign_key "integrations", "projects"
  add_foreign_key "policies", "projects"
  add_foreign_key "runs", "agents"
  add_foreign_key "runs", "work_items"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "webhook_events", "projects"
  add_foreign_key "work_items", "agents", column: "assigned_agent_id"
  add_foreign_key "work_items", "agents", column: "locked_by_agent_id"
  add_foreign_key "work_items", "projects"
end
