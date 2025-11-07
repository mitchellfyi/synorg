# frozen_string_literal: true

FactoryBot.define do
  factory :webhook_event do
    project
    event_type { "issues" }
    sequence(:delivery_id) { |n| "delivery-#{n}" }
    payload do
      {
        action: "opened",
        issue: {
          number: 123,
          title: "Test Issue",
          body: "Test issue body",
          state: "open",
          labels: [],
          html_url: "https://github.com/test/repo/issues/123"
        }
      }
    end
  end
end
