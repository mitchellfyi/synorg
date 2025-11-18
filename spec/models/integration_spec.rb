# frozen_string_literal: true

require "rails_helper"

RSpec.describe Integration do
  describe "validations" do
    it { is_expected.to validate_presence_of(:kind) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:status) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "scopes" do
    let(:project) { Project.create!(slug: "test") }
    let!(:active_integration) { described_class.create!(project: project, kind: "slack", name: "Active", status: "active") }
    let!(:inactive_integration) { described_class.create!(project: project, kind: "github", name: "Inactive", status: "inactive") }

    describe ".active" do
      it "returns only active integrations" do
        expect(described_class.active).to include(active_integration)
        expect(described_class.active).not_to include(inactive_integration)
      end
    end

    describe ".inactive" do
      it "returns only inactive integrations" do
        expect(described_class.inactive).to include(inactive_integration)
        expect(described_class.inactive).not_to include(active_integration)
      end
    end
  end

  describe "#credential" do
    let(:project) { Project.create!(slug: "test") }

    context "when value is blank" do
      it "returns nil" do
        integration = described_class.create!(
          project: project,
          kind: "github",
          name: "Test",
          status: "active",
          value: nil
        )

        expect(integration.credential).to be_nil
      end
    end

    context "when value references an environment variable" do
      it "returns the environment variable value" do
        ENV["TEST_SECRET"] = "secret_value_123"

        integration = described_class.create!(
          project: project,
          kind: "github",
          name: "Test",
          status: "active",
          value: "TEST_SECRET"
        )

        expect(integration.credential).to eq("secret_value_123")

        ENV.delete("TEST_SECRET")
      end
    end

    context "when environment variable is not set" do
      it "returns nil" do
        integration = described_class.create!(
          project: project,
          kind: "github",
          name: "Test",
          status: "active",
          value: "NONEXISTENT_VAR"
        )

        expect(integration.credential).to be_nil
      end
    end
  end
end
