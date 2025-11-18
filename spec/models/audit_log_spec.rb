# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog do
  describe "associations" do
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:auditable).optional }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "scopes" do
    let!(:webhook_received) { create(:audit_log, :webhook_received) }
    let!(:webhook_invalid) { create(:audit_log, :webhook_invalid_signature) }
    let!(:webhook_rate_limited) { create(:audit_log, :webhook_rate_limited) }
    let!(:run_started) { create(:audit_log, :run_started) }

    describe ".recent" do
      it "orders by created_at descending" do
        expect(described_class.recent.first).to eq(run_started)
      end
    end

    describe ".by_event_type" do
      it "filters by event type" do
        results = described_class.by_event_type(AuditLog::WEBHOOK_RECEIVED)
        expect(results).to contain_exactly(webhook_received)
      end
    end

    describe ".by_status" do
      it "filters by status" do
        results = described_class.by_status(AuditLog::STATUS_BLOCKED)
        expect(results).to contain_exactly(webhook_invalid, webhook_rate_limited)
      end
    end

    describe ".security_events" do
      it "returns security-related events" do
        results = described_class.security_events
        expect(results).to contain_exactly(webhook_invalid, webhook_rate_limited)
      end
    end

    describe ".webhook_events" do
      it "returns all webhook events" do
        results = described_class.webhook_events
        expect(results).to contain_exactly(webhook_received, webhook_invalid, webhook_rate_limited)
      end
    end

    describe ".run_events" do
      it "returns all run events" do
        results = described_class.run_events
        expect(results).to contain_exactly(run_started)
      end
    end
  end

  describe "#sanitized_payload_excerpt" do
    it "returns nil for blank payload" do
      audit_log = build(:audit_log, payload_excerpt: nil)
      expect(audit_log.sanitized_payload_excerpt).to be_nil
    end

    it "redacts tokens from payload" do
      payload = '{"token": "ghp_1234567890123456789012345678901234567890"}'
      audit_log = build(:audit_log, payload_excerpt: payload)
      expect(audit_log.sanitized_payload_excerpt).to include("***REDACTED***")
      expect(audit_log.sanitized_payload_excerpt).not_to include("ghp_")
    end

    it "redacts fine-grained tokens" do
      payload = '{"token": "github_pat_1234567890ABCDEFGH_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"}'
      audit_log = build(:audit_log, payload_excerpt: payload)
      expect(audit_log.sanitized_payload_excerpt).to include("***REDACTED***")
      expect(audit_log.sanitized_payload_excerpt).not_to include("github_pat_")
    end

    it "redacts bearer tokens" do
      payload = '{"auth": "Bearer abc123xyz"}'
      audit_log = build(:audit_log, payload_excerpt: payload)
      expect(audit_log.sanitized_payload_excerpt).to include("***REDACTED***")
    end

    it "redacts secret keys" do
      payload = '{"secret": "mysecret123"}'
      audit_log = build(:audit_log, payload_excerpt: payload)
      expect(audit_log.sanitized_payload_excerpt).to include("***REDACTED***")
    end
  end

  describe ".log_webhook" do
    it "creates a webhook audit log" do
      expect do
        described_class.log_webhook(
          event_type: AuditLog::WEBHOOK_RECEIVED,
          status: AuditLog::STATUS_SUCCESS,
          ip_address: "1.2.3.4",
          request_id: "req-123"
        )
      end.to change(described_class, :count).by(1)

      log = described_class.last
      expect(log.event_type).to eq(AuditLog::WEBHOOK_RECEIVED)
      expect(log.ip_address).to eq("1.2.3.4")
      expect(log.request_id).to eq("req-123")
    end
  end

  describe ".log_work_item" do
    it "creates a work item audit log" do
      work_item = create(:work_item)
      agent = create(:agent)

      expect do
        described_class.log_work_item(
          event_type: AuditLog::WORK_ITEM_ASSIGNED,
          work_item: work_item,
          agent: agent
        )
      end.to change(described_class, :count).by(1)

      log = described_class.last
      expect(log.event_type).to eq(AuditLog::WORK_ITEM_ASSIGNED)
      expect(log.auditable).to eq(work_item)
      expect(log.actor).to eq(agent.name)
      expect(log.project).to eq(work_item.project)
    end
  end

  describe ".log_run" do
    it "creates a run audit log" do
      run = create(:run)

      expect do
        described_class.log_run(
          event_type: AuditLog::RUN_STARTED,
          run: run
        )
      end.to change(described_class, :count).by(1)

      log = described_class.last
      expect(log.event_type).to eq(AuditLog::RUN_STARTED)
      expect(log.auditable).to eq(run)
      expect(log.actor).to eq(run.agent.name)
      expect(log.project).to eq(run.work_item.project)
    end
  end
end
