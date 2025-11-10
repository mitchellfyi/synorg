# frozen_string_literal: true
class AddIdempotencyAndLogsToRuns < ActiveRecord::Migration[8.1]
  def change
    change_table :runs, bulk: true do |t|
      t.string :idempotency_key
      t.text :logs
    end

    add_index :runs, :idempotency_key, unique: true, where: "idempotency_key IS NOT NULL"
  end
end
