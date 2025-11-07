# frozen_string_literal: true
class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.references :project, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :delivery_id, null: false
      t.json :payload, default: {}, null: false

      t.timestamps
    end

    add_index :webhook_events, :event_type
    add_index :webhook_events, :delivery_id, unique: true
    add_index :webhook_events, [:project_id, :event_type]
  end
end
