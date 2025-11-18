# frozen_string_literal: true

# Migration to deprecate direct PAT storage and encourage secret references
class DeprecateDirectPatStorage < ActiveRecord::Migration[8.1]
  def change
    # Add comment to github_pat column to indicate it's deprecated
    # We don't remove it yet for backwards compatibility
    change_column_comment :projects, :github_pat, 
      "DEPRECATED: Use github_pat_secret_name instead. This column will be removed in a future version."
    
    # Add comment to github_pat_secret_name to document its purpose
    change_column_comment :projects, :github_pat_secret_name,
      "Name of the environment variable or GitHub Secret containing the PAT (e.g., 'SYNORG_GITHUB_PAT')"
  end
end
