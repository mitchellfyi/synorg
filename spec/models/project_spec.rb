# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project, type: :model do
  subject { build(:project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:slug) }
    it { is_expected.to validate_uniqueness_of(:slug) }
    it { is_expected.to validate_presence_of(:state) }
  end

  describe "associations" do
    it { is_expected.to have_many(:work_items).dependent(:destroy) }
    it { is_expected.to have_many(:integrations).dependent(:destroy) }
    it { is_expected.to have_many(:policies).dependent(:destroy) }
  end

  describe "state machine" do
    let(:project) { described_class.create!(slug: "test-project") }

    it "starts in draft state" do
      expect(project.state).to eq("draft")
    end

    it "can transition from draft to scoped" do
      expect { project.scope! }.to change { project.state }.from("draft").to("scoped")
    end

    it "can transition from scoped to repo_bootstrapped" do
      project.scope!
      expect { project.bootstrap_repo! }.to change { project.state }.from("scoped").to("repo_bootstrapped")
    end

    it "can transition from repo_bootstrapped to in_build" do
      project.scope!
      project.bootstrap_repo!
      expect { project.start_build! }.to change { project.state }.from("repo_bootstrapped").to("in_build")
    end

    it "can transition from in_build to live" do
      project.scope!
      project.bootstrap_repo!
      project.start_build!
      expect { project.go_live! }.to change { project.state }.from("in_build").to("live")
    end

    it "can revert from live to in_build" do
      project.scope!
      project.bootstrap_repo!
      project.start_build!
      project.go_live!
      expect { project.revert_to_build! }.to change { project.state }.from("live").to("in_build")
    end

    it "cannot skip states" do
      expect { project.bootstrap_repo! }.to raise_error(AASM::InvalidTransition)
    end
  end
end
