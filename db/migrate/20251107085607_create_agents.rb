# frozen_string_literal: true
class CreateAgents < ActiveRecord::Migration[8.1]
  def change
    create_table :agents do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.json :capabilities, default: {}
      t.integer :max_concurrency, default: 1
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :agents, :key, unique: true
    add_index :agents, :enabled
  end
end
