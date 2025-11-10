# frozen_string_literal: true

class AddGithubFieldsToRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :runs, bulk: true do |t|
      t.integer :github_pr_number, null: true
      t.string :github_pr_head_sha, null: true
      t.bigint :github_check_suite_id, null: true
    end

    # Add indexes for efficient querying
    add_index :runs, :github_pr_number, name: "index_runs_on_github_pr_number"
    add_index :runs, :github_pr_head_sha, name: "index_runs_on_github_pr_head_sha"
    add_index :runs, :github_check_suite_id, name: "index_runs_on_github_check_suite_id"
  end
end
