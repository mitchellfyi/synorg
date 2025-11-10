# frozen_string_literal: true

# Service to find a project by webhook signature verification
# Extracted from GithubWebhookController to improve testability and follow SOLID
class WebhookProjectFinder
  # Find the project by verifying the webhook signature
  # Tries each project's webhook secret until one matches
  #
  # NOTE: This implementation is acceptable for small to medium deployments.
  # For production at scale, consider:
  # 1. Using a custom header (e.g., X-Project-ID) to identify the project
  # 2. Using webhook URLs with project identifiers (e.g., /github/webhook/:project_id)
  # 3. Caching webhook secrets in memory (Redis/Memcached)
  # 4. Using a database index on webhook_secret
  #
  # @param request_body [String] The raw request body
  # @param signature [String] The X-Hub-Signature-256 header value
  # @return [Project, nil] The project if signature matches, nil otherwise
  def self.find_by_signature(request_body, signature)
    return nil unless signature

    # Optimize by only loading necessary fields and filtering out null webhook_secret
    Project.where.not(webhook_secret: nil)
      .select(:id, :webhook_secret)
      .find_each do |project|
      # Get the secret directly from the project record
      secret = project.webhook_secret
      next unless secret

      # Verify the signature
      if WebhookVerifier.verify(request_body, signature, secret)
        # Reload full project object since we only selected specific fields
        return Project.find(project.id)
      end
    end

    nil
  end
end
