# frozen_string_literal: true

require "rails_helper"

RSpec.describe Project do
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
      expect { project.scope! }.to change(project, :state).from("draft").to("scoped")
    end

    it "can transition from scoped to repo_bootstrapped" do
      project.scope!
      expect { project.bootstrap_repo! }.to change(project, :state).from("scoped").to("repo_bootstrapped")
    end

    it "can transition from repo_bootstrapped to in_build" do
      project.scope!
      project.bootstrap_repo!
      expect { project.start_build! }.to change(project, :state).from("repo_bootstrapped").to("in_build")
    end

    it "can transition from in_build to live" do
      project.scope!
      project.bootstrap_repo!
      project.start_build!
      expect { project.go_live! }.to change(project, :state).from("in_build").to("live")
    end

    it "can revert from live to in_build" do
      project.scope!
      project.bootstrap_repo!
      project.start_build!
      project.go_live!
      expect { project.revert_to_build! }.to change(project, :state).from("live").to("in_build")
    end

    it "cannot skip states" do
      expect { project.bootstrap_repo! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#github_token" do
    let(:project) { described_class.create!(slug: "test-project") }

    context "when github_pat_secret_name is not set" do
      it "returns nil" do
        expect(project.github_token).to be_nil
      end
    end

    context "when github_pat_secret_name references an environment variable" do
      it "returns the environment variable value" do
        ENV["TEST_GITHUB_PAT"] = "ghp_1234567890123456789012345678901234567890"
        project.update!(github_pat_secret_name: "TEST_GITHUB_PAT")

        expect(project.github_token).to eq("ghp_1234567890123456789012345678901234567890")

        ENV.delete("TEST_GITHUB_PAT")
      end
    end

    context "when environment variable is not set but github_pat is set (deprecated)" do
      it "falls back to github_pat and logs a warning" do
        project.update!(
          github_pat_secret_name: "MISSING_VAR",
          github_pat: "ghp_deprecated_token"
        )

        expect(Rails.logger).to receive(:warn).with(/deprecated direct PAT storage/)
        expect(project.github_token).to eq("ghp_deprecated_token")
      end
    end

    context "when github_pat_secret_name is blank" do
      it "returns nil even if github_pat is set" do
        project.update!(github_pat: "some_token", github_pat_secret_name: nil)
        expect(project.github_token).to be_nil
      end
    end
  end

  describe "deprecated PAT storage validation" do
    let(:project) { described_class.new(slug: "test-project") }

    context "when github_pat is set directly" do
      it "logs a deprecation warning" do
        project.github_pat = "ghp_some_token"

        expect(Rails.logger).to receive(:warn).with(/deprecated direct PAT storage/)
        project.valid?
      end
    end

    context "when github_pat is not set" do
      it "does not log a warning" do
        expect(Rails.logger).not_to receive(:warn)
        project.valid?
      end
    end
  end
end
