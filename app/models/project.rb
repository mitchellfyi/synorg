# frozen_string_literal: true

class Project < ApplicationRecord
  include AASM

  has_many :work_items, dependent: :destroy
  has_many :integrations, dependent: :destroy
  has_many :policies, dependent: :destroy
  has_many :webhook_events, dependent: :destroy

  validates :slug, presence: true, uniqueness: true
  validates :state, presence: true

  aasm column: :state do
    state :draft, initial: true
    state :scoped
    state :repo_bootstrapped
    state :in_build
    state :live

    event :scope do
      transitions from: :draft, to: :scoped
    end

    event :bootstrap_repo do
      transitions from: :scoped, to: :repo_bootstrapped
    end

    event :start_build do
      transitions from: :repo_bootstrapped, to: :in_build
    end

    event :go_live do
      transitions from: :in_build, to: :live
    end

    event :revert_to_build do
      transitions from: :live, to: :in_build
    end
  end
end
