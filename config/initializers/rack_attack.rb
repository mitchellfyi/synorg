# frozen_string_literal: true

# Rack::Attack configuration for rate limiting and throttling
# https://github.com/rack/rack-attack

class Rack::Attack
  ### Configure Cache ###

  # Use Rails cache for storing rate limit data
  # In production, use Redis for better performance across multiple instances
  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

  ### Throttle Webhook Endpoints ###

  # Throttle webhook endpoints to 100 requests per minute per IP
  throttle("webhooks/ip", limit: 100, period: 1.minute) do |req|
    if req.path == "/github/webhook" && req.post?
      req.ip
    end
  end

  ### Custom Response for Throttled Requests ###

  # Log rate limit violations to audit logs
  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"]
    now = match_data[:epoch_time]

    # Log to audit log
    AuditLog.log_webhook(
      event_type: AuditLog::WEBHOOK_RATE_LIMITED,
      status: AuditLog::STATUS_BLOCKED,
      ip_address: request.ip,
      request_id: request.env["action_dispatch.request_id"],
      payload_excerpt: "Rate limit exceeded: #{match_data[:count]} requests in #{match_data[:period]} seconds"
    )

    headers = {
      "Content-Type" => "application/json",
      "X-RateLimit-Limit" => match_data[:limit].to_s,
      "X-RateLimit-Remaining" => "0",
      "X-RateLimit-Reset" => (now + (match_data[:period] - (now % match_data[:period]))).to_s
    }

    [429, headers, [{ error: "Rate limit exceeded. Try again later." }.to_json]]
  end

  ### Logging ###

  # Log blocked requests
  ActiveSupport::Notifications.subscribe("rack.attack") do |name, start, finish, request_id, payload|
    req = payload[:request]
    if [:throttle, :blocklist, :blocklist].include?(req.env["rack.attack.match_type"])
      Rails.logger.warn(
        "[Rack::Attack] #{req.env['rack.attack.match_type']} #{req.ip} #{req.request_method} #{req.fullpath}"
      )
    end
  end
end
