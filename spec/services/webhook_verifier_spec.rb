# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookVerifier do
  let(:payload) { '{"action":"opened","number":1}' }
  let(:secret) { "my-secret-key" }

  describe ".verify" do
    it "verifies a valid SHA256 signature" do
      signature = OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
      full_signature = "sha256=#{signature}"

      result = described_class.verify(payload, full_signature, secret)

      expect(result).to be(true)
    end

    it "rejects an invalid signature" do
      invalid_signature = "sha256=invalid"

      result = described_class.verify(payload, invalid_signature, secret)

      expect(result).to be(false)
    end

    it "returns false when signature is nil" do
      result = described_class.verify(payload, nil, secret)

      expect(result).to be(false)
    end

    it "returns false when secret is nil" do
      result = described_class.verify(payload, "sha256=something", nil)

      expect(result).to be(false)
    end
  end
end
