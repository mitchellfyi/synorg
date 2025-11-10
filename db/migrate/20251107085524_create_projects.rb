# frozen_string_literal: true
class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name
      t.string :slug, null: false
      t.string :state, null: false, default: "draft"
      t.text :brief
      t.string :repo_full_name
      t.string :repo_default_branch
      t.text :github_pat
      t.string :github_pat_secret_name
      t.text :webhook_secret
      t.json :gates_config, default: {}
      t.boolean :e2e_required, default: true, null: false

      t.timestamps
    end

    add_index :projects, :slug, unique: true
    add_index :projects, :state
  end
end
