# frozen_string_literal: true

require "rails_helper"

RSpec.describe GithubWebhookController, type: :controller do
  let(:project) { create(:project, webhook_secret_name: "TEST_WEBHOOK_SECRET") }
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

  before do
    # Mock the secret fetch
    allow_any_instance_of(described_class).to receive(:fetch_secret).with("TEST_WEBHOOK_SECRET").and_return(webhook_secret)
  end

  def generate_signature(payload, secret)
    "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  describe "POST #create" do
    # NOTE: These tests are currently pending due to controller test limitations with raw POST bodies in Rails 8.
    # Controller tests don't properly support raw request bodies needed for webhook testing.
    # TODO: Convert these to request specs which handle raw POST bodies correctly.

    context "with valid signature" do
      let(:signature) { generate_signature(payload_json, webhook_secret) }

      before do
        # Mock raw_post to return the payload for all tests in this context
        allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(payload_json)
      end

      xit "accepts the webhook and creates a webhook event" do
        request.headers["X-GitHub-Event"] = "issues"
        request.headers["X-Hub-Signature-256"] = signature
        request.headers["X-GitHub-Delivery"] = delivery_id

        expect do
          post :create, body: payload_json
        end.to change(WebhookEvent, :count).by(1)

        expect(response).to have_http_status(:accepted)

        webhook_event = WebhookEvent.last
        expect(webhook_event.project).to eq(project)
        expect(webhook_event.event_type).to eq("issues")
        expect(webhook_event.delivery_id).to eq(delivery_id)
        expect(webhook_event.payload["action"]).to eq("opened")
      end

      xit "processes the event" do
        request.headers["X-GitHub-Event"] = "issues"
        request.headers["X-Hub-Signature-256"] = signature
        request.headers["X-GitHub-Delivery"] = delivery_id

        expect_any_instance_of(WebhookEventProcessor).to receive(:process)

        post :create, body: payload_json
      end
    end

    context "with invalid signature" do
      xit "rejects the webhook" do
        request.headers["X-GitHub-Event"] = "issues"
        request.headers["X-Hub-Signature-256"] = "sha256=invalid"
        request.headers["X-GitHub-Delivery"] = delivery_id

        expect do
          post :create, body: payload_json
        end.not_to change(WebhookEvent, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with missing signature" do
      xit "rejects the webhook" do
        request.headers["X-GitHub-Event"] = "issues"
        request.headers["X-GitHub-Delivery"] = delivery_id

        expect do
          post :create, body: payload_json
        end.not_to change(WebhookEvent, :count)

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with unsupported event type" do
      let(:signature) { generate_signature(payload_json, webhook_secret) }

      before do
        allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(payload_json)
      end

      xit "rejects unsupported event type before persistence" do
        request.headers["X-GitHub-Event"] = "unsupported_event"
        request.headers["X-Hub-Signature-256"] = signature
        request.headers["X-GitHub-Delivery"] = delivery_id

        expect do
          post :create, body: payload_json
        end.not_to change(WebhookEvent, :count)

        expect(response).to have_http_status(:accepted)
      end
    end

    context "with invalid JSON" do
      let(:invalid_json) { "invalid json" }
      let(:signature) { generate_signature(invalid_json, webhook_secret) }

      before do
        allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(invalid_json)
      end

      xit "returns bad request" do
        request.headers["X-GitHub-Event"] = "issues"
        request.headers["X-Hub-Signature-256"] = signature
        request.headers["X-GitHub-Delivery"] = delivery_id

        post :create, body: invalid_json

        expect(response).to have_http_status(:bad_request)
      end
    end

    context "when an error occurs during processing" do
      let(:signature) { generate_signature(payload_json, webhook_secret) }

      before do
        allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(payload_json)
      end

      xit "returns internal server error" do
        request.headers["X-GitHub-Event"] = "issues"
        request.headers["X-Hub-Signature-256"] = signature
        request.headers["X-GitHub-Delivery"] = delivery_id

        allow_any_instance_of(WebhookEventProcessor).to receive(:process).and_raise(StandardError, "Processing failed")

        post :create, body: payload_json

        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
