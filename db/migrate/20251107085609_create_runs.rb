# frozen_string_literal: true
class CreateRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :runs do |t|
      t.references :agent, null: false, foreign_key: true
      t.references :work_item, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :finished_at
      t.string :outcome
      t.string :logs_url
      t.string :artifacts_url
      t.json :costs, default: {}

      t.timestamps
    end

    add_index :runs, :outcome
    add_index :runs, [:agent_id, :started_at]
  end
end
