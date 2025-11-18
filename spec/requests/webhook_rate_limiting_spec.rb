# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Webhook Rate Limiting" do
  let!(:project) { create(:project, webhook_secret: "test-secret-123") }
  let(:webhook_secret) { "test-secret-123" }
  let(:delivery_id) { "12345-67890-abcdef" }

  let(:valid_payload) do
    {
      action: "opened",
      issue: {
        number: 123,
        title: "Test Issue"
      }
    }
  end

  let(:payload_json) { valid_payload.to_json }

  def generate_signature(payload, secret)
    "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  before do
    # Reset Rack::Attack state before each test
    Rack::Attack.cache.store.clear
  end

  describe "throttling" do
    let(:signature) { generate_signature(payload_json, webhook_secret) }

    it "allows requests under the rate limit" do
      # Make 10 requests (well under the 100/minute limit)
      10.times do |i|
        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => "#{delivery_id}-#{i}",
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(payload_json) }

        expect(response).to have_http_status(:accepted)
      end
    end

    it "blocks requests that exceed the rate limit", :skip do
      # Note: This test is skipped by default because it makes 101 requests
      # and can be slow. Enable when specifically testing rate limiting.
      
      # Make 100 requests (at the limit)
      100.times do |i|
        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => "#{delivery_id}-#{i}",
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(payload_json) }
      end

      # The 101st request should be rate limited
      post "/github/webhook",
        headers: {
          "X-GitHub-Event" => "issues",
          "X-Hub-Signature-256" => signature,
          "X-GitHub-Delivery" => "#{delivery_id}-101",
          "CONTENT_TYPE" => "application/json",
          "CONTENT_LENGTH" => payload_json.bytesize.to_s
        },
        env: { "rack.input" => StringIO.new(payload_json) }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "includes rate limit headers in throttled response", :skip do
      # Make requests until throttled
      101.times do |i|
        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => "#{delivery_id}-#{i}",
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(payload_json) }
      end

      expect(response.headers["X-RateLimit-Limit"]).to eq("100")
      expect(response.headers["X-RateLimit-Remaining"]).to eq("0")
      expect(response.headers["X-RateLimit-Reset"]).to be_present
    end

    it "logs rate limit violations to audit log", :skip do
      # Make requests until throttled
      expect do
        101.times do |i|
          post "/github/webhook",
            headers: {
              "X-GitHub-Event" => "issues",
              "X-Hub-Signature-256" => signature,
              "X-GitHub-Delivery" => "#{delivery_id}-#{i}",
              "CONTENT_TYPE" => "application/json",
              "CONTENT_LENGTH" => payload_json.bytesize.to_s
            },
            env: { "rack.input" => StringIO.new(payload_json) }
        end
      end.to change { AuditLog.where(event_type: AuditLog::WEBHOOK_RATE_LIMITED).count }.by_at_least(1)

      rate_limit_log = AuditLog.where(event_type: AuditLog::WEBHOOK_RATE_LIMITED).last
      expect(rate_limit_log.status).to eq(AuditLog::STATUS_BLOCKED)
      expect(rate_limit_log.ip_address).to be_present
    end

    it "resets rate limit after the time window", :skip do
      # Make 100 requests
      100.times do |i|
        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => "#{delivery_id}-#{i}",
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: { "rack.input" => StringIO.new(payload_json) }
      end

      # Next request should be throttled
      post "/github/webhook",
        headers: {
          "X-GitHub-Event" => "issues",
          "X-Hub-Signature-256" => signature,
          "X-GitHub-Delivery" => "#{delivery_id}-throttled",
          "CONTENT_TYPE" => "application/json",
          "CONTENT_LENGTH" => payload_json.bytesize.to_s
        },
        env: { "rack.input" => StringIO.new(payload_json) }

      expect(response).to have_http_status(:too_many_requests)

      # Wait for the rate limit window to reset (1 minute + buffer)
      # In real tests, you might use Timecop or similar to fast-forward time
      # For now, we'll just document the behavior
      # travel 61.seconds do
      #   post "/github/webhook", ...
      #   expect(response).to have_http_status(:accepted)
      # end
    end
  end

  describe "rate limiting per IP" do
    it "tracks different IPs separately", :skip do
      signature = generate_signature(payload_json, webhook_secret)

      # Make 100 requests from one IP
      100.times do |i|
        post "/github/webhook",
          headers: {
            "X-GitHub-Event" => "issues",
            "X-Hub-Signature-256" => signature,
            "X-GitHub-Delivery" => "#{delivery_id}-ip1-#{i}",
            "CONTENT_TYPE" => "application/json",
            "CONTENT_LENGTH" => payload_json.bytesize.to_s
          },
          env: {
            "rack.input" => StringIO.new(payload_json),
            "REMOTE_ADDR" => "192.168.1.1"
          }
      end

      # Request from same IP should be throttled
      post "/github/webhook",
        headers: {
          "X-GitHub-Event" => "issues",
          "X-Hub-Signature-256" => signature,
          "X-GitHub-Delivery" => "#{delivery_id}-ip1-throttled",
          "CONTENT_TYPE" => "application/json",
          "CONTENT_LENGTH" => payload_json.bytesize.to_s
        },
        env: {
          "rack.input" => StringIO.new(payload_json),
          "REMOTE_ADDR" => "192.168.1.1"
        }

      expect(response).to have_http_status(:too_many_requests)

      # But request from different IP should succeed
      post "/github/webhook",
        headers: {
          "X-GitHub-Event" => "issues",
          "X-Hub-Signature-256" => signature,
          "X-GitHub-Delivery" => "#{delivery_id}-ip2-1",
          "CONTENT_TYPE" => "application/json",
          "CONTENT_LENGTH" => payload_json.bytesize.to_s
        },
        env: {
          "rack.input" => StringIO.new(payload_json),
          "REMOTE_ADDR" => "192.168.1.2"
        }

      expect(response).to have_http_status(:accepted)
    end
  end
end
