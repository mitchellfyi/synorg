# frozen_string_literal: true

require "fileutils"

# Execution Strategy for agents that write files directly to the filesystem
# Handles agents like GTM and Docs that write files locally
class FileWriteStrategy
  attr_reader :project, :agent, :work_item

  def initialize(project:, agent:, work_item:)
    @project = project
    @agent = agent
    @work_item = work_item
  end

  def execute(parsed_response)
    return { success: false, error: "Invalid response type: #{parsed_response[:type]}" } unless parsed_response[:type] == "file_writes"

    files = parsed_response[:files] || []
    return { success: false, error: "No files provided" } if files.empty?

    files_written = []

    files.each do |file_data|
      path = file_data[:path] || file_data["path"]
      content = file_data[:content] || file_data["content"]

      next unless path && content

      full_path = Rails.root.join(path)
      FileUtils.mkdir_p(File.dirname(full_path))
      File.write(full_path, content)
      files_written << path
    end

    {
      success: true,
      message: "Successfully wrote #{files_written.count} files",
      files_written: files_written
    }
  rescue StandardError => e
    Rails.logger.error("FileWriteStrategy failed: #{e.message}")
    {
      success: false,
      error: e.message
    }
  end
end
