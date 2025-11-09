# frozen_string_literal: true
class AddIdempotencyAndLogsToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :idempotency_key, :string
    add_column :runs, :logs, :text
    
    add_index :runs, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
  end
end
