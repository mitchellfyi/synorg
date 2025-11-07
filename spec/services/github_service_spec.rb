# frozen_string_literal: true

require "rails_helper"

RSpec.describe GithubService do
  let(:repo_full_name) { "example/test-repo" }
  let(:token) { "fake-token" }
  let(:service) { described_class.new(repo_full_name, token) }

  # Note: These tests are stubs and will require proper mocking or VCR cassettes
  # for full implementation. For now, we're just verifying the interface exists.

  describe "#get_issue" do
    it "is defined" do
      expect(service).to respond_to(:get_issue)
    end
  end

  describe "#list_issues" do
    it "is defined" do
      expect(service).to respond_to(:list_issues)
    end
  end

  describe "#create_issue_comment" do
    it "is defined" do
      expect(service).to respond_to(:create_issue_comment)
    end
  end

  describe "#get_pull_request" do
    it "is defined" do
      expect(service).to respond_to(:get_pull_request)
    end
  end

  describe "#create_pull_request" do
    it "is defined" do
      expect(service).to respond_to(:create_pull_request)
    end
  end

  describe "#list_pull_request_files" do
    it "is defined" do
      expect(service).to respond_to(:list_pull_request_files)
    end
  end
end
