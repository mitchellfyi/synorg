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
    it "is stubbed for now (requires Git and network)" do
      # This is a stub - full implementation will be tested with integration tests
      pending "Requires Git setup and network access"
    end
  end

  describe "#create_branch" do
    it "is stubbed for now (requires Git repository)" do
      pending "Requires cloned repository"
    end
  end

  describe "#commit_changes" do
    it "is stubbed for now (requires Git repository)" do
      pending "Requires cloned repository"
    end
  end

  describe "#push_branch" do
    it "is stubbed for now (requires Git repository)" do
      pending "Requires cloned repository"
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
