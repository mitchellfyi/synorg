# frozen_string_literal: true
FactoryBot.define do
  factory :work_item do
    type { "task" }
    title { "Sample Task" }
    description { "A detailed description of the work item" }
    status { "pending" }
    github_issue_number { nil }
    priority { 0 }
  end
end
