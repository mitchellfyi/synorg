# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkspaceService do
  let(:project) do
    Project.create!(
      slug: "test-project",
      repo_full_name: "example/test-repo",
      repo_default_branch: "main"
    )
  end
  let(:service) { described_class.new(project) }

  describe "#provision" do
    it "creates a temporary workspace directory" do
      work_dir = service.provision

      expect(work_dir).to be_a(String)
      expect(work_dir).to include("synorg-workspace")
      expect(File.directory?(work_dir)).to be(true)

      FileUtils.rm_rf(work_dir)
    end
  end

  describe "#clone_repository" do
    it "requires Git and network access" do
      skip "Integration test - requires Git setup and network access"
      # Would test: service.clone_repository(pat)
    end
  end

  describe "#create_branch" do
    it "requires a cloned repository" do
      skip "Integration test - requires cloned repository"
      # Would test: service.create_branch("test-branch")
    end
  end

  describe "#commit_changes" do
    it "requires a cloned repository" do
      skip "Integration test - requires cloned repository"
      # Would test: service.commit_changes("test commit")
    end
  end

  describe "#push_branch" do
    it "requires a cloned repository" do
      skip "Integration test - requires cloned repository"
      # Would test: service.push_branch("test-branch")
    end
  end

  describe "#cleanup" do
    it "removes the workspace directory" do
      work_dir = service.provision
      expect(File.directory?(work_dir)).to be(true)

      service.cleanup
      expect(File.directory?(work_dir)).to be(false)
    end
  end
end
