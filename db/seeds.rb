# frozen_string_literal: true
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Skip seeding in test environment to avoid interfering with test specs
return if Rails.env.test?

# Load agent seed files (each agent has its own seed file)
Dir[Rails.root.join("db/seeds/agents/*.rb")].sort.each do |file|
  # Skip helpers.rb as it's loaded by individual seed files
  next if file.include?("helpers.rb")

  load file
end

# Create demo project with real GitHub repository
# The PAT is stored in Rails credentials under demo:pat and accessed via project.github_pat_secret_name
# The webhook secret is stored in Rails credentials under demo:webhook_secret
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
    - Workspace operations (clone, branch, commit, PR)
    - CI/CD integration
  BRIEF
  p.repo_full_name = "mitchellfyi/synorg-demo"
  p.repo_default_branch = "main"
  p.github_pat_secret_name = "demo:pat"
  p.webhook_secret = Rails.application.credentials.dig(:demo, :webhook_secret)
  p.gates_config = {
    "require_review" => true,
    "require_tests" => true,
    "require_linting" => true,
    "require_e2e" => false
  }
  p.e2e_required = false
end

puts "✓ Created project: #{project.name} (#{project.slug})"

# Agents are seeded from db/seeds/agents/*.rb files
puts "✓ Available agents: #{Agent.count} total"
puts "   - #{Agent.enabled.pluck(:key).join(', ')}"

# Create repo bootstrap work item for demo project
repo_bootstrap_agent = Agent.find_by(key: "repo-bootstrap")
if repo_bootstrap_agent
  WorkItem.find_or_initialize_by(
    project: project,
    work_type: "repo_bootstrap"
  ).tap do |wi|
    wi.payload = {
      "title" => "Bootstrap Rails application",
      "description" => "Initialize Rails 8.1 application with PostgreSQL, Solid Queue, Tailwind CSS v4, TypeScript, and esbuild"
    }
    wi.status = "pending"
    wi.priority = 1
    wi.assigned_agent = repo_bootstrap_agent
    wi.save!
  end
end

# Create sample work items
WorkItem.find_or_initialize_by(
  project: project,
  work_type: "code_review"
).tap do |wi|
  wi.payload = {
    "pr_number" => 123,
    "files_changed" => 5
  }
  wi.status = "pending"
  wi.priority = 10
  wi.save!
end

WorkItem.find_or_initialize_by(
  project: project,
  work_type: "run_tests"
).tap do |wi|
  wi.payload = {
    "branch" => "feature/new-feature",
    "commit_sha" => "abc123"
  }
  wi.status = "pending"
  wi.priority = 20
  wi.save!
end

WorkItem.find_or_initialize_by(
  project: project,
  work_type: "deploy"
).tap do |wi|
  wi.payload = {
    "environment" => "staging",
    "version" => "1.0.0"
  }
  wi.status = "pending"
  wi.priority = 5
  wi.save!
end

puts "✓ Created work items: #{WorkItem.count} total"

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
