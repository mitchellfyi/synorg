# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    event_type { AuditLog::WEBHOOK_RECEIVED }
    status { AuditLog::STATUS_SUCCESS }
    actor { "system" }
    ip_address { "192.168.1.1" }
    request_id { SecureRandom.uuid }
    payload_excerpt { { action: "test" }.to_json }
    
    trait :webhook_received do
      event_type { AuditLog::WEBHOOK_RECEIVED }
      status { AuditLog::STATUS_SUCCESS }
    end

    trait :webhook_invalid_signature do
      event_type { AuditLog::WEBHOOK_INVALID_SIGNATURE }
      status { AuditLog::STATUS_BLOCKED }
    end

    trait :webhook_missing_signature do
      event_type { AuditLog::WEBHOOK_MISSING_SIGNATURE }
      status { AuditLog::STATUS_BLOCKED }
    end

    trait :webhook_rate_limited do
      event_type { AuditLog::WEBHOOK_RATE_LIMITED }
      status { AuditLog::STATUS_BLOCKED }
    end

    trait :work_item_assigned do
      event_type { AuditLog::WORK_ITEM_ASSIGNED }
      status { AuditLog::STATUS_SUCCESS }
      association :auditable, factory: :work_item
    end

    trait :run_started do
      event_type { AuditLog::RUN_STARTED }
      status { AuditLog::STATUS_SUCCESS }
      association :auditable, factory: :run
    end

    trait :run_finished do
      event_type { AuditLog::RUN_FINISHED }
      status { AuditLog::STATUS_SUCCESS }
      association :auditable, factory: :run
    end

    trait :run_failed do
      event_type { AuditLog::RUN_FAILED }
      status { AuditLog::STATUS_FAILED }
      association :auditable, factory: :run
    end
  end
end
