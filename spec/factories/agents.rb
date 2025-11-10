# frozen_string_literal: true

FactoryBot.define do
  factory :agent do
    sequence(:key) { |n| "agent-#{n}" }
    sequence(:name) { |n| "Agent #{n}" }
    description { "A test agent" }
    capabilities { {} }
    max_concurrency { 1 }
    enabled { true }
    prompt { "Test prompt for agent" }
  end
end
