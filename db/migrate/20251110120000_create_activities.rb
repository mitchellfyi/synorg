# frozen_string_literal: true

class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities do |t|
      t.belongs_to :trackable, polymorphic: true, null: false
      t.belongs_to :owner, polymorphic: true
      t.string :key, null: false
      t.jsonb :parameters
      t.belongs_to :recipient, polymorphic: true
      t.belongs_to :project, null: false, foreign_key: true
      t.timestamps
    end

    add_index :activities, [:trackable_id, :trackable_type]
    add_index :activities, [:owner_id, :owner_type]
    add_index :activities, [:recipient_id, :recipient_type]
    # Note: project_id index is automatically created by belongs_to with foreign_key: true
    add_index :activities, :key
    add_index :activities, :created_at
  end
end
