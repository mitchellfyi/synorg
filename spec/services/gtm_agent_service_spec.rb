# frozen_string_literal: true

require "rails_helper"

RSpec.describe GtmAgentService do
  describe "#run" do
    let(:project_brief) { "A collaborative task management tool for remote teams" }
    let(:service) { described_class.new(project_brief) }
    let(:output_path) { Rails.root.join("tmp", "test_positioning.md") }

    before do
      FileUtils.mkdir_p(File.dirname(output_path))
    end

    after do
      FileUtils.rm_f(output_path)
    end

    it "returns a success response" do
      result = service.run
      expect(result[:success]).to be true
    end

    it "creates a positioning document" do
      result = service.run
      expect(File.exist?(result[:file_path])).to be true
    end

    it "includes project brief in the document" do
      result = service.run
      content = File.read(result[:file_path])
      expect(content).to include(project_brief.truncate(500))
    end

    context "with custom output path" do
      let(:service) { described_class.new(project_brief, output_path: output_path) }

      it "writes to the specified path" do
        result = service.run
        expect(result[:file_path]).to eq(output_path)
        expect(File.exist?(output_path)).to be true
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
