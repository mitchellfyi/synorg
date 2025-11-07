#!/usr/bin/env ruby
# frozen_string_literal: true

# Agent Demonstration Script
#
# This script demonstrates how to use the five core agents in Synorg.
# Run this from the Rails console or as a standalone script.
#
# Usage:
#   bin/rails runner script/demo_agents.rb
#   OR
#   bin/rails console
#   > load 'script/demo_agents.rb'

require "fileutils"

puts "\n" + "=" * 80
puts "SYNORG AGENTS DEMONSTRATION"
puts "=" * 80

# Sample project brief
PROJECT_BRIEF = <<~TEXT
  Build a collaborative task management application for remote teams called "AsyncFlow".
  The application should help distributed teams coordinate work across time zones with
  async-first task management that keeps everyone aligned without constant meetings.

  Key features:
  - Real-time task updates with Hotwire
  - Time zone awareness for all timestamps
  - Asynchronous comments with Markdown support
  - Team collaboration and member management
  - Background job processing for notifications

  Target users:
  - Remote-first companies with 10-50 employees
  - Distributed teams across multiple time zones
  - Teams seeking to reduce synchronous meetings

  Tech stack:
  - Ruby on Rails 8.1
  - PostgreSQL
  - Hotwire (Turbo + Stimulus)
  - Tailwind CSS
  - Solid Queue for background jobs
TEXT

puts "\nProject Brief:"
puts "-" * 80
puts PROJECT_BRIEF
puts "-" * 80

# Create a demo project
puts "\nCreating demo project..."
project = Project.find_or_create_by!(slug: "asyncflow-demo") do |p|
  p.state = "draft"
end
puts "✓ Project created: #{project.slug} (state: #{project.state})"

# 1. GTM Agent
puts "\n\n1. Running GTM Agent..."
puts "-" * 80

gtm_service = GtmAgentService.new(PROJECT_BRIEF)
gtm_result = gtm_service.run

if gtm_result[:success]
  puts "✓ GTM Agent completed successfully"
  puts "  - File created: #{gtm_result[:file_path]}"
  puts "  - Content length: #{gtm_result[:content_length]} bytes"

  # Show a preview of the positioning document
  if File.exist?(gtm_result[:file_path])
    content = File.read(gtm_result[:file_path])
    puts "\n  Preview:"
    puts "  " + content.lines.first(10).join("  ")
    puts "  ... (see #{gtm_result[:file_path]} for full content)"
  end
else
  puts "✗ GTM Agent failed: #{gtm_result[:error]}"
end

# 2. Product Manager Agent
puts "\n\n2. Running Product Manager Agent..."
puts "-" * 80

pm_service = ProductManagerAgentService.new(project)
pm_result = pm_service.run

if pm_result[:success]
  puts "✓ Product Manager Agent completed successfully"
  puts "  - Work items created: #{pm_result[:work_items_created]}"

  # Show the created work items
  work_items = WorkItem.where(id: pm_result[:work_item_ids])
  puts "\n  Created work items:"
  work_items.each_with_index do |item, index|
    title = item.payload["title"] || "No title"
    puts "  #{index + 1}. [#{item.status.upcase}] #{title}"
    puts "     Priority: #{item.priority}, Type: #{item.work_type}"
  end
else
  puts "✗ Product Manager Agent failed: #{pm_result[:error]}"
end

# 3. Issue Agent
puts "\n\n3. Running Issue Agent..."
puts "-" * 80

issue_service = IssueAgentService.new(project)
issue_result = issue_service.run

if issue_result[:success]
  puts "✓ Issue Agent completed successfully"
  puts "  - GitHub issues created: #{issue_result[:issues_created]}"

  if issue_result[:issues_created] > 0
    puts "  - Issue numbers: #{issue_result[:issue_numbers].join(', ')}"
    puts "\n  Note: GitHub integration is stubbed. In production, these would be real issues."
  end
else
  puts "✗ Issue Agent failed: #{issue_result[:error]}"
end

# 4. Docs Agent
puts "\n\n4. Running Docs Agent..."
puts "-" * 80

docs_service = DocsAgentService.new(PROJECT_BRIEF)
docs_result = docs_service.run

if docs_result[:success]
  puts "✓ Docs Agent completed successfully"
  puts "  - Files updated: #{docs_result[:files_updated].count}"

  docs_result[:files_updated].each do |file|
    puts "    - #{file}"
  end

  # Show preview of stack.md
  stack_path = Rails.root.join("docs", "stack.md")
  if File.exist?(stack_path)
    puts "\n  Preview of docs/stack.md:"
    content = File.read(stack_path)
    puts "  " + content.lines.first(8).join("  ")
    puts "  ... (see #{stack_path} for full content)"
  end
else
  puts "✗ Docs Agent failed: #{docs_result[:error]}"
end

# 5. Dev Tooling Agent
puts "\n\n5. Running Dev Tooling Agent..."
puts "-" * 80

dev_service = DevToolingAgentService.new
dev_result = dev_service.run

if dev_result[:success]
  puts "✓ Dev Tooling Agent completed successfully"
  puts "  - Recommendations found: #{dev_result[:recommendations_count]}"

  if dev_result[:recommendations_count] > 0
    puts "\n  Recommendations:"
    dev_result[:recommendations].each_with_index do |rec, index|
      puts "  #{index + 1}. [#{rec[:priority].upcase}] #{rec[:title]}"
      puts "     Category: #{rec[:category]}"
      puts "     #{rec[:description]}"
    end
  else
    puts "\n  No recommendations - repository is in good shape!"
  end
else
  puts "✗ Dev Tooling Agent failed: #{dev_result[:error]}"
end

# Summary
puts "\n\n" + "=" * 80
puts "SUMMARY"
puts "=" * 80

results = [
  ["GTM Agent", gtm_result[:success]],
  ["Product Manager Agent", pm_result[:success]],
  ["Issue Agent", issue_result[:success]],
  ["Docs Agent", docs_result[:success]],
  ["Dev Tooling Agent", dev_result[:success]]
]

results.each do |name, success|
  status = success ? "✓ PASSED" : "✗ FAILED"
  puts "#{status.ljust(10)} #{name}"
end

successful_count = results.count { |_, success| success }
puts "\n#{successful_count}/#{results.count} agents completed successfully"

puts "\nProject state:"
puts "- Project: #{project.slug} (#{project.state})"
puts "- Work items created: #{project.work_items.count}"
puts "- Files generated: docs/product/positioning.md, docs/stack.md, docs/setup.md"

puts "\nNext steps:"
puts "- Review generated files in docs/product/ and docs/"
puts "- Check work_items: WorkItem.where(project: Project.find_by(slug: 'asyncflow-demo'))"
puts "- See docs/ai/agents-overview.md for detailed documentation"
puts "- To re-run: bin/rails runner script/demo_agents.rb"

puts "\n" + "=" * 80
puts "END OF DEMONSTRATION"
puts "=" * 80 + "\n"
