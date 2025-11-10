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
end
