# frozen_string_literal: true

require "rails_helper"

RSpec.describe DocsAgentService do
  describe "#run" do
    let(:project_brief) { "A collaborative task management tool for remote teams" }
    let(:service) { described_class.new(project_brief) }
    let(:docs_dir) { Rails.root.join("docs") }
    let(:stack_path) { docs_dir.join("stack.md") }
    let(:setup_path) { docs_dir.join("setup.md") }

    before do
      FileUtils.mkdir_p(docs_dir)
    end

    after do
      FileUtils.rm_f([stack_path, setup_path])
    end

    it "returns a success response" do
      result = service.run
      expect(result[:success]).to be true
    end

    it "updates documentation files" do
      result = service.run
      expect(result[:files_updated]).to include("docs/stack.md", "docs/setup.md")
    end

    it "creates stack.md file" do
      service.run
      expect(File.exist?(stack_path)).to be true
    end

    it "creates setup.md file" do
      service.run
      expect(File.exist?(setup_path)).to be true
    end

    it "includes relevant content in stack.md" do
      service.run
      content = File.read(stack_path)
      expect(content).to include("Technology Stack")
      expect(content).to include("Rails")
      expect(content).to include("PostgreSQL")
    end

    it "includes setup instructions in setup.md" do
      service.run
      content = File.read(setup_path)
      expect(content).to include("Development Setup")
      expect(content).to include("bin/setup")
      expect(content).to include("Prerequisites")
    end

    context "with GTM positioning" do
      let(:gtm_content) { "Test positioning" }

      before do
        positioning_path = Rails.root.join("docs", "product", "positioning.md")
        FileUtils.mkdir_p(File.dirname(positioning_path))
        File.write(positioning_path, gtm_content)
      end

      after do
        FileUtils.rm_f(Rails.root.join("docs", "product", "positioning.md"))
      end

      it "reads GTM positioning" do
        result = service.run
        expect(result[:success]).to be true
      end
    end

    context "when file write fails" do
      before do
        allow(File).to receive(:write).and_raise(Errno::EACCES, "Permission denied")
      end

      it "returns an error response" do
        result = service.run
        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end
    end
  end
end
