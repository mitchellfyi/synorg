# frozen_string_literal: true

# Controller to handle GitHub webhook events
# Verifies HMAC signatures and processes incoming webhooks
class GithubWebhookController < ApplicationController
  # Skip CSRF token verification for webhooks
  # Webhooks are authenticated using HMAC SHA-256 signature verification
  # instead of CSRF tokens, as they originate from external sources (GitHub)
  # and cannot include Rails CSRF tokens in their requests.
  # Security is ensured through the WebhookVerifier service which validates
  # the X-Hub-Signature-256 header against the configured webhook secret.
  skip_before_action :verify_authenticity_token

  # Supported webhook events
  SUPPORTED_EVENTS = %w[issues pull_request push workflow_run check_suite].freeze

  # POST /github/webhook
  def create
    # Get the raw request body for signature verification
    request_body = request.raw_post

    # Get GitHub headers
    event_type = request.headers["X-GitHub-Event"]
    signature = request.headers["X-Hub-Signature-256"]
    delivery_id = request.headers["X-GitHub-Delivery"]

    # Get request metadata for audit logging
    ip_address = request.remote_ip
    request_id = request.request_id

    # Check for missing signature
    unless signature
      Rails.logger.warn("Webhook missing signature for delivery: #{delivery_id}")
      AuditLog.log_webhook(
        event_type: AuditLog::WEBHOOK_MISSING_SIGNATURE,
        status: AuditLog::STATUS_BLOCKED,
        ip_address: ip_address,
        request_id: request_id,
        payload_excerpt: request_body.truncate(500)
      )
      head :bad_request
      return
    end

    # Find the project by webhook signature verification
    project = WebhookProjectFinder.find_by_signature(request_body, signature)

    unless project
      Rails.logger.warn("Webhook signature verification failed for delivery: #{delivery_id}")
      AuditLog.log_webhook(
        event_type: AuditLog::WEBHOOK_INVALID_SIGNATURE,
        status: AuditLog::STATUS_BLOCKED,
        ip_address: ip_address,
        request_id: request_id,
        payload_excerpt: request_body.truncate(500)
      )
      head :bad_request
      return
    end

    # Check if event type is supported
    unless SUPPORTED_EVENTS.include?(event_type)
      Rails.logger.warn("Unsupported webhook event type: #{event_type}")
      head :accepted
      return
    end

    # Parse the payload
    payload = JSON.parse(request_body)

    # Persist the webhook event
    project.webhook_events.create!(
      event_type: event_type,
      delivery_id: delivery_id,
      payload: payload
    )

    # Log successful webhook receipt to audit log
    AuditLog.log_webhook(
      event_type: AuditLog::WEBHOOK_RECEIVED,
      status: AuditLog::STATUS_SUCCESS,
      project: project,
      ip_address: ip_address,
      request_id: request_id,
      payload_excerpt: { event_type: event_type, delivery_id: delivery_id }.to_json
    )

    # Process the event
    WebhookEventProcessor.new(project, event_type, payload).call

    head :accepted
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse webhook payload: #{e.message}")
    head :bad_request
  rescue StandardError => e
    Rails.logger.error("Error processing webhook: #{e.class} - #{e.message}")
    if Rails.env.local?
      Rails.logger.debug(e.backtrace.join("\n"))
    end
    head :internal_server_error
  end
end
