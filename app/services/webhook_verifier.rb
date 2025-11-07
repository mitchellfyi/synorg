# frozen_string_literal: true

require "openssl"

# Service to verify HMAC signatures of incoming GitHub webhooks
class WebhookVerifier
  # Verify the HMAC signature of a webhook payload
  #
  # @param payload [String] The raw request body
  # @param signature [String] The X-Hub-Signature-256 header value
  # @param secret [String] The webhook secret
  # @return [Boolean] True if signature is valid
  def self.verify(payload, signature, secret)
    return false if signature.nil? || secret.nil?

    # GitHub sends signature as "sha256=<signature>"
    expected_signature = signature.split("=", 2).last
    computed_signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)

    # Use secure comparison to prevent timing attacks
    ActiveSupport::SecurityUtils.secure_compare(computed_signature, expected_signature)
  end

  # Verify using the X-Hub-Signature header (SHA1, legacy)
  #
  # @param payload [String] The raw request body
  # @param signature [String] The X-Hub-Signature header value
  # @param secret [String] The webhook secret
  # @return [Boolean] True if signature is valid
  # rubocop:disable GitHub/InsecureHashAlgorithm
  def self.verify_sha1(payload, signature, secret)
    return false if signature.nil? || secret.nil?

    expected_signature = signature.split("=", 2).last
    computed_signature = OpenSSL::HMAC.hexdigest("SHA1", secret, payload)

    ActiveSupport::SecurityUtils.secure_compare(computed_signature, expected_signature)
  end
  # rubocop:enable GitHub/InsecureHashAlgorithm
end
