# frozen_string_literal: true

FactoryBot.define do
  factory :project do
    sequence(:slug) { |n| "project-#{n}" }
    state { "draft" }
  end
end
