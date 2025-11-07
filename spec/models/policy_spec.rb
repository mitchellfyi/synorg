# frozen_string_literal: true

require "rails_helper"

RSpec.describe Policy, type: :model do
  describe "validations" do
    subject { described_class.new(project: Project.create!(slug: "test"), key: "test_key") }

    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_uniqueness_of(:key).scoped_to(:project_id) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:project) }
  end
end
