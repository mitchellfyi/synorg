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

ActiveRecord::Schema[8.1].define(version: 2025_11_09_125535) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agents", force: :cascade do |t|
    t.json "capabilities", default: {}
    t.datetime "created_at", null: false
    t.text "description"
    t.boolean "enabled", default: true, null: false
    t.string "key", null: false
    t.integer "max_concurrency", default: 1
    t.string "name", null: false
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
    t.string "github_pat_secret_name"
    t.string "name"
    t.string "repo_default_branch"
    t.string "repo_full_name"
    t.string "slug", null: false
    t.string "state", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.string "webhook_secret_name"
    t.index ["slug"], name: "index_projects_on_slug", unique: true
    t.index ["state"], name: "index_projects_on_state"
  end

  create_table "runs", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.string "artifacts_url"
    t.json "costs", default: {}
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.string "idempotency_key"
    t.text "logs"
    t.string "logs_url"
    t.string "outcome"
    t.datetime "started_at"
    t.datetime "updated_at", null: false
    t.bigint "work_item_id", null: false
    t.index ["agent_id", "started_at"], name: "index_runs_on_agent_id_and_started_at"
    t.index ["agent_id"], name: "index_runs_on_agent_id"
    t.index ["idempotency_key"], name: "index_runs_on_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["outcome"], name: "index_runs_on_outcome"
    t.index ["work_item_id"], name: "index_runs_on_work_item_id"
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
    t.index ["locked_by_agent_id"], name: "index_work_items_on_locked_by_agent_id"
    t.index ["priority"], name: "index_work_items_on_priority"
    t.index ["project_id"], name: "index_work_items_on_project_id"
    t.index ["status", "priority", "locked_at"], name: "index_work_items_on_status_and_priority_and_locked_at"
    t.index ["status"], name: "index_work_items_on_status"
  end

  add_foreign_key "integrations", "projects"
  add_foreign_key "policies", "projects"
  add_foreign_key "runs", "agents"
  add_foreign_key "runs", "work_items"
  add_foreign_key "webhook_events", "projects"
  add_foreign_key "work_items", "agents", column: "assigned_agent_id"
  add_foreign_key "work_items", "agents", column: "locked_by_agent_id"
  add_foreign_key "work_items", "projects"
end
