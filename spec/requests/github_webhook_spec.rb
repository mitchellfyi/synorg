# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GitHub Webhooks" do
  let!(:project) { create(:project, webhook_secret: "test-secret-123") }
  let(:webhook_secret) { "test-secret-123" }
  let(:delivery_id) { "12345-67890-abcdef" }

  let(:valid_payload) do
    {
      action: "opened",
      issue: {
        number: 123,
        title: "Test Issue",
        body: "Test body",
        state: "open",
        labels: [],
        html_url: "https://github.com/test/repo/issues/123"
      }
    }
  end

  let(:payload_json) { valid_payload.to_json }

  def generate_signature(payload, secret)
    "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  describe "POST /github/webhook" do
    context "with valid signature" do
      let(:signature) { generate_signature(payload_json, webhook_secret) }

      it "accepts the webhook and creates a webhook event" do
        expect do
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "issues",
              "X-Hub-Signature-256" => signature,
              "X-GitHub-Delivery" => delivery_id,
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end.to change(WebhookEvent, :count).by(1)
          .and change(AuditLog, :count).by(1)

        expect(response).to have_http_status(:accepted)

        webhook_event = WebhookEvent.last
        expect(webhook_event.project).to eq(project)
        expect(webhook_event.event_type).to eq("issues")
        expect(webhook_event.delivery_id).to eq(delivery_id)
        expect(webhook_event.payload["action"]).to eq("opened")

        audit_log = AuditLog.last
        expect(audit_log.event_type).to eq(AuditLog::WEBHOOK_RECEIVED)
        expect(audit_log.status).to eq(AuditLog::STATUS_SUCCESS)
        expect(audit_log.project).to eq(project)
      end

      it "processes the event" do
        expect_any_instance_of(WebhookEventProcessor).to receive(:call)

        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => delivery_id,
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(payload_json) }
      end
    end

    context "with invalid signature" do
      it "rejects the webhook with 400 Bad Request" do
        expect do
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "issues",
              "X-Hub-Signature-256" => "sha256=invalid",
              "X-GitHub-Delivery" => delivery_id,
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end.not_to change(WebhookEvent, :count)

        expect(response).to have_http_status(:bad_request)
      end

      it "logs invalid signature to audit log" do
        expect do
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "issues",
              "X-Hub-Signature-256" => "sha256=invalid",
              "X-GitHub-Delivery" => delivery_id,
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.event_type).to eq(AuditLog::WEBHOOK_INVALID_SIGNATURE)
        expect(audit_log.status).to eq(AuditLog::STATUS_BLOCKED)
        expect(audit_log.ip_address).to be_present
      end
    end

    context "with missing signature" do
      it "rejects the webhook with 400 Bad Request" do
        expect do
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "issues",
              "X-GitHub-Delivery" => delivery_id,
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end.not_to change(WebhookEvent, :count)

        expect(response).to have_http_status(:bad_request)
      end

      it "logs missing signature to audit log" do
        expect do
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "issues",
              "X-GitHub-Delivery" => delivery_id,
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end.to change(AuditLog, :count).by(1)

        audit_log = AuditLog.last
        expect(audit_log.event_type).to eq(AuditLog::WEBHOOK_MISSING_SIGNATURE)
        expect(audit_log.status).to eq(AuditLog::STATUS_BLOCKED)
        expect(audit_log.ip_address).to be_present
      end
    end

    context "with unsupported event type" do
      let(:signature) { generate_signature(payload_json, webhook_secret) }

      it "rejects unsupported event type before persistence" do
        expect do
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "unsupported_event",
              "X-Hub-Signature-256" => signature,
              "X-GitHub-Delivery" => delivery_id,
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end.not_to change(WebhookEvent, :count)

        expect(response).to have_http_status(:accepted)
      end
    end

    context "with invalid JSON" do
      let(:invalid_json) { "invalid json" }
      let(:signature) { generate_signature(invalid_json, webhook_secret) }

      it "returns bad request" do
        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => delivery_id,
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => invalid_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(invalid_json) }

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when an error occurs during processing" do
      let(:signature) { generate_signature(payload_json, webhook_secret) }

      it "returns internal server error" do
        allow_any_instance_of(WebhookEventProcessor).to receive(:call).and_raise(StandardError, "Processing failed")

        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => delivery_id,
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(payload_json) }

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
