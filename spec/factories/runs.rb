# frozen_string_literal: true

FactoryBot.define do
  factory :run do
    agent
    work_item
    started_at { Time.current }
    finished_at { nil }
    outcome { nil }
    logs_url { nil }
    artifacts_url { nil }
    costs { {} }
  end
end
