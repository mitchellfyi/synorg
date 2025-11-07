# frozen_string_literal: true

require "rails_helper"

RSpec.describe WebhookEvent, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end

  describe "validations" do
    subject { build(:webhook_event) }

    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_presence_of(:delivery_id) }
    it { is_expected.to validate_presence_of(:payload) }
    it { is_expected.to validate_uniqueness_of(:delivery_id) }
  end

  describe "scopes" do
    let(:project) { create(:project) }
    let!(:issue_event) { create(:webhook_event, project: project, event_type: "issues") }
    let!(:pr_event) { create(:webhook_event, project: project, event_type: "pull_request") }
    let!(:old_event) { create(:webhook_event, project: project, created_at: 1.day.ago) }

    describe ".by_event_type" do
      it "filters events by type" do
        expect(described_class.by_event_type("issues")).to include(issue_event)
        expect(described_class.by_event_type("issues")).not_to include(pr_event)
      end
    end

    describe ".recent" do
      it "orders events by created_at descending" do
        recent_events = described_class.recent
        expect(recent_events.first.created_at).to be > recent_events.last.created_at
      end
    end
  end
end
