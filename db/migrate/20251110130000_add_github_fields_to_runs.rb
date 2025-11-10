# frozen_string_literal: true

class AddGithubFieldsToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :github_pr_number, :integer, null: true
    add_column :runs, :github_pr_head_sha, :string, null: true
    add_column :runs, :github_check_suite_id, :bigint, null: true

    # Add indexes for efficient querying
    add_index :runs, :github_pr_number, name: "index_runs_on_github_pr_number"
    add_index :runs, :github_pr_head_sha, name: "index_runs_on_github_pr_head_sha"
    add_index :runs, :github_check_suite_id, name: "index_runs_on_github_check_suite_id"
  end
end

