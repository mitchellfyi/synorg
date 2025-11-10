# frozen_string_literal: true
# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Skip seeding in test environment to avoid interfering with test specs
return if Rails.env.test?

# Create sample project
project = Project.find_or_create_by!(slug: "demo-app") do |p|
  p.name = "Demo Application"
  p.state = "draft"
  p.brief = "A demonstration project for synorg"
  p.repo_full_name = "example/demo-app"
  p.repo_default_branch = "main"
  p.github_pat_secret_name = "GITHUB_PAT_DEMO"
  p.webhook_secret_name = "WEBHOOK_SECRET_DEMO"
  p.gates_config = {
    "require_review" => true,
    "require_tests" => true,
    "require_linting" => true
  }
  p.e2e_required = true
end

puts "✓ Created project: #{project.name} (#{project.slug})"

# Create sample agents
Agent.find_or_create_by!(key: "code-reviewer") do |a|
  a.name = "Code Reviewer"
  a.description = "Reviews code changes for quality and best practices"
  a.capabilities = {
    "languages" => ["ruby", "javascript", "python"],
    "max_file_size" => 100_000
  }
  a.max_concurrency = 3
  a.enabled = true
end

Agent.find_or_create_by!(key: "test-runner") do |a|
  a.name = "Test Runner"
  a.description = "Runs automated tests on pull requests"
  a.capabilities = {
    "frameworks" => ["rspec", "jest", "pytest"]
  }
  a.max_concurrency = 5
  a.enabled = true
end

Agent.find_or_create_by!(key: "deployer") do |a|
  a.name = "Deployment Agent"
  a.description = "Handles deployment to staging and production"
  a.capabilities = {
    "environments" => ["staging", "production"]
  }
  a.max_concurrency = 1
  a.enabled = false
end

puts "✓ Created agents: #{Agent.count} total"

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
