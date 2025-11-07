# frozen_string_literal: true

class Policy < ApplicationRecord
  belongs_to :project

  validates :key, presence: true
  validates :key, uniqueness: { scope: :project_id }
end
