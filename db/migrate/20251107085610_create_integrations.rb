# frozen_string_literal: true
class CreateIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :integrations do |t|
      t.references :project, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.text :value
      t.string :status, default: "active"

      t.timestamps
    end

    add_index :integrations, [:project_id, :kind]
    add_index :integrations, :status
  end
end
