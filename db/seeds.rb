# frozen_string_literal: true
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Skip seeding in test environment to avoid interfering with test specs
return if Rails.env.test?

# Load agent seed files (each agent has its own seed file)
# NOTE: Agents are GLOBAL resources - they are not tied to any specific project.
# Agents can be used by any project through work items. The orchestrator agent
# can assign agents to work items as needed.
Dir[Rails.root.join("db/seeds/agents/*.rb")].sort.each do |file|
  # Skip helpers.rb as it's loaded by individual seed files
  next if file.include?("helpers.rb")

  load file
end

# Create demo project with real GitHub repository
# The PAT and webhook secret are loaded from Rails credentials
project = Project.find_or_create_by!(slug: "synorg-demo") do |p|
  p.name = "Synorg Demo"
  p.state = "draft"
  p.brief = <<~BRIEF
    A demonstration project for synorg using the synorg-demo repository.
    This project showcases synorg's capabilities for managing AI agent workflows
    and GitHub integration.

    Features to demonstrate:
    - Project lifecycle management
    - Work item creation and tracking
    - Agent execution and assignment
    - GitHub issue synchronization
    - GitHub API operations (create issues, PRs, files)
    - CI/CD integration
  BRIEF
  p.repo_full_name = "mitchellfyi/synorg-demo"
  p.repo_default_branch = "main"
  p.gates_config = {
    "require_review" => true,
    "require_tests" => true,
    "require_linting" => true,
    "require_e2e" => false
  }
  p.e2e_required = false
end

# Always update PAT and webhook secret from credentials (even if project already exists)
# This ensures the demo project always has the latest values from Rails credentials
demo_pat = Rails.application.credentials.dig(:demo, :pat)
demo_webhook_secret = Rails.application.credentials.dig(:demo, :webhook_secret)

if demo_pat.present?
  project.update_column(:github_pat, demo_pat)
end

if demo_webhook_secret.present?
  project.update_column(:webhook_secret, demo_webhook_secret)
end

puts "✓ Created project: #{project.name} (#{project.slug})"

# Agents are global resources seeded above (not project-specific)
# They can be used by any project through work items assigned by the orchestrator
puts "✓ Available agents: #{Agent.count} total"
puts "   - #{Agent.enabled.pluck(:key).join(', ')}"

# Orchestrator agent will create work items based on project state
# No need to manually create work items here
puts "✓ Work items will be created by orchestrator agent based on project state"

# Create sample integrations
Integration.find_or_create_by!(
  project: project,
  kind: "slack",
  name: "Team Notifications"
) do |i|
  i.value = "https://hooks.slack.com/services/EXAMPLE"
  i.status = "active"
end

Integration.find_or_create_by!(
  project: project,
  kind: "github",
  name: "Repository Integration"
) do |i|
  i.value = "https://github.com/example/demo-app"
  i.status = "active"
end

puts "✓ Created integrations: #{Integration.count} total"

# Create sample policies
Policy.find_or_create_by!(project: project, key: "require_approval") do |p|
  p.value = {
    "min_approvals" => 2,
    "auto_merge" => false
  }
end

Policy.find_or_create_by!(project: project, key: "ci_timeout") do |p|
  p.value = {
    "timeout_seconds" => 3600
  }
end

puts "✓ Created policies: #{Policy.count} total"

puts "\n🎉 Seed data created successfully!"
puts "   - Project: #{project.name}"
puts "   - Agents: #{Agent.count}"
puts "   - Work Items: #{WorkItem.count}"
puts "   - Integrations: #{Integration.count}"
puts "   - Policies: #{Policy.count}"
