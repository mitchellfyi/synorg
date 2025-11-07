# frozen_string_literal: true
FactoryBot.define do
  factory :work_item do
    project
    work_type { "task" }
    payload { { title: "Sample Task", description: "A detailed description of the work item" } }
    status { "pending" }
    priority { 0 }
  end
end
