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

    # Find the project by webhook signature verification
    project = find_project_by_signature(request_body, signature)

    unless project
      Rails.logger.warn("Webhook signature verification failed for delivery: #{delivery_id}")
      head :unauthorized
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

    # Process the event
    WebhookEventProcessorJob.perform_later(project.id, event_type, payload)

    head :accepted
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse webhook payload: #{e.message}")
    head :bad_request
  rescue StandardError => e
    Rails.logger.error("Error processing webhook: #{e.class} - #{e.message}")
    if Rails.env.development? || Rails.env.test?
      Rails.logger.debug(e.backtrace.join("\n"))
    end
    head :internal_server_error
  end

  private

  # Find the project by verifying the webhook signature
  # Tries each project's webhook secret until one matches
  #
  # NOTE: This implementation is acceptable for small to medium deployments.
  # For production at scale, consider:
  # 1. Using a custom header (e.g., X-Project-ID) to identify the project
  # 2. Using webhook URLs with project identifiers (e.g., /github/webhook/:project_id)
  # 3. Caching webhook secrets in memory (Redis/Memcached)
  # 4. Using a database index on webhook_secret_name
  #
  # @param request_body [String] The raw request body
  # @param signature [String] The X-Hub-Signature-256 header value
  # @return [Project, nil] The project if signature matches, nil otherwise
  def find_project_by_signature(request_body, signature)
    return nil unless signature

    Project.where.not(webhook_secret_name: nil).find_each do |project|
      # Get the secret from Rails credentials or environment
      secret = fetch_secret(project.webhook_secret_name)
      next unless secret

      # Verify the signature
      if WebhookVerifier.verify(request_body, signature, secret)
        return project
      end
    end

    nil
  end

  # Fetch a secret from Rails credentials
  #
  # @param secret_name [String] The name of the secret in credentials
  # @return [String, nil] The secret value or nil
  def fetch_secret(secret_name)
    # In production, secrets would be stored in Rails.application.credentials
    # or environment variables. For now, we'll check ENV first, then credentials.
    ENV[secret_name] || Rails.application.credentials.dig(:github, secret_name.to_sym)
  end
end
