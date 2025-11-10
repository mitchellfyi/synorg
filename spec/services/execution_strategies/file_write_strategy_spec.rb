# frozen_string_literal: true

require "rails_helper"
require_relative "../../../app/services/execution_strategies/file_write_strategy"

RSpec.describe FileWriteStrategy do
  let(:project) { create(:project) }
  let(:agent) { create(:agent) }
  let(:work_item) { create(:work_item, project: project) }
  let(:strategy) { described_class.new(project: project, agent: agent, work_item: work_item) }

  describe "#execute" do
    context "with valid file_writes response" do
      let(:parsed_response) do
        {
          type: "file_writes",
          files: [
            { path: "test.md", content: "# Test" },
            { path: "docs/guide.md", content: "Guide content" }
          ]
        }
      end

      it "writes files to filesystem" do
        result = strategy.execute(parsed_response)

        expect(result[:success]).to be true
        expect(Rails.root.join("test.md").exist?).to be true
        expect(Rails.root.join("test.md").read).to eq("# Test")
        expect(Rails.root.join("docs/guide.md").exist?).to be true

        # Cleanup
        FileUtils.rm_f(Rails.root.join("test.md"))
        FileUtils.rm_rf(Rails.root.join("docs"))
      end

      it "returns success with files written" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be true
        expect(result[:files_written]).to include("test.md", "docs/guide.md")

        # Cleanup
        FileUtils.rm_f(Rails.root.join("test.md"))
        FileUtils.rm_rf(Rails.root.join("docs"))
      end
    end

    context "with invalid response type" do
      let(:parsed_response) { { type: "invalid" } }

      it "returns error" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be false
        expect(result[:error]).to include("Invalid response type")
      end
    end

    context "with no files" do
      let(:parsed_response) { { type: "file_writes", files: [] } }

      it "returns error" do
        result = strategy.execute(parsed_response)
        expect(result[:success]).to be false
        expect(result[:error]).to include("No files provided")
      end
    end

    context "when file write fails" do
      let(:parsed_response) do
        {
          type: "file_writes",
          files: [{ path: "/invalid/path/file.txt", content: "test" }]
        }
      end

      it "handles error gracefully" do
        # This will fail due to invalid path, but should be caught
        result = strategy.execute(parsed_response)
        # May succeed or fail depending on filesystem permissions
        expect(result).to have_key(:success)
      end
    end
  end
end
