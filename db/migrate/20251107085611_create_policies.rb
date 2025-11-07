# frozen_string_literal: true
class CreatePolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :policies do |t|
      t.references :project, null: false, foreign_key: true
      t.string :key, null: false
      t.json :value, default: {}

      t.timestamps
    end

    add_index :policies, [:project_id, :key], unique: true
  end
end
