# frozen_string_literal: true

require "rails_helper"

RSpec.describe Agent, type: :model do
  describe "validations" do
    subject { described_class.new(key: "test-agent", name: "Test Agent") }

    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_numericality_of(:max_concurrency).is_greater_than(0) }
  end

  describe "associations" do
    it { is_expected.to have_many(:runs).dependent(:destroy) }
    it { is_expected.to have_many(:assigned_work_items).dependent(:nullify) }
    it { is_expected.to have_many(:locked_work_items).dependent(:nullify) }
  end

  describe "scopes" do
    let!(:enabled_agent) { described_class.create!(key: "enabled", name: "Enabled", enabled: true) }
    let!(:disabled_agent) { described_class.create!(key: "disabled", name: "Disabled", enabled: false) }

    describe ".enabled" do
      it "returns only enabled agents" do
        expect(described_class.enabled).to include(enabled_agent)
        expect(described_class.enabled).not_to include(disabled_agent)
      end
    end
  end
end
