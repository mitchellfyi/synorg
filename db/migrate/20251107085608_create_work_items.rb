# frozen_string_literal: true
class CreateWorkItems < ActiveRecord::Migration[8.1]
  def change
    create_table :work_items do |t|
      t.references :project, null: false, foreign_key: true
      t.string :type, null: false
      t.json :payload, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :priority, default: 0
      t.references :assigned_agent, foreign_key: { to_table: :agents }
      t.datetime :locked_at
      t.references :locked_by_agent, foreign_key: { to_table: :agents }

      t.timestamps
    end

    add_index :work_items, :status
    add_index :work_items, :priority
    add_index :work_items, [:status, :priority, :locked_at]
  end
end
