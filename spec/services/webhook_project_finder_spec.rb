# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookProjectFinder do
  describe ".find_by_signature" do
    let(:request_body) { '{"action":"opened"}' }
    let(:webhook_secret) { "test-secret-123" }
    let!(:project_with_secret) { create(:project, webhook_secret: webhook_secret) }
    let!(:project_without_secret) { create(:project, webhook_secret: nil) }

    def generate_signature(payload, secret)
      "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
    end

    context "with valid signature" do
      let(:signature) { generate_signature(request_body, webhook_secret) }

      it "returns the matching project" do
        result = described_class.find_by_signature(request_body, signature)
        expect(result).to eq(project_with_secret)
      end

      it "returns full project object, not just selected fields" do
        result = described_class.find_by_signature(request_body, signature)
        expect(result).to respond_to(:name)
        expect(result).to respond_to(:slug)
        expect(result).to respond_to(:brief)
      end
    end

    context "with invalid signature" do
      let(:signature) { "sha256=invalid" }

      it "returns nil" do
        result = described_class.find_by_signature(request_body, signature)
        expect(result).to be_nil
      end
    end

    context "with nil signature" do
      it "returns nil" do
        result = described_class.find_by_signature(request_body, nil)
        expect(result).to be_nil
      end
    end

    context "with multiple projects" do
      let(:other_secret) { "other-secret-456" }
      let!(:other_project) { create(:project, webhook_secret: other_secret) }
      let(:signature) { generate_signature(request_body, webhook_secret) }

      it "returns the project with matching secret" do
        result = described_class.find_by_signature(request_body, signature)
        expect(result).to eq(project_with_secret)
        expect(result).not_to eq(other_project)
      end
    end

    context "when no projects have webhook secrets" do
      before do
        Project.find_each { |p| p.update!(webhook_secret: nil) }
      end

      let(:signature) { generate_signature(request_body, webhook_secret) }

      it "returns nil" do
        result = described_class.find_by_signature(request_body, signature)
        expect(result).to be_nil
      end
    end
  end
end
