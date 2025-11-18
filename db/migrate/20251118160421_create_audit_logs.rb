# frozen_string_literal: true

# Migration to create audit_logs table for comprehensive event tracking
# Captures webhook events, assignment/claim events, run events, and security events
class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.string :event_type, null: false, index: true
      t.string :actor, index: true
      t.string :ip_address
      t.string :request_id
      t.text :payload_excerpt
      t.string :status, null: false, index: true
      t.references :project, foreign_key: true, index: true
      t.references :auditable, polymorphic: true, index: true

      t.timestamps
    end

    add_index :audit_logs, :created_at
    add_index :audit_logs, [:project_id, :event_type]
    add_index :audit_logs, [:event_type, :status]
  end
end
