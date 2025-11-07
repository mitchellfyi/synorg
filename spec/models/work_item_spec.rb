# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkItem, type: :model do
  describe "validations" do
    it "validates presence of type" do
      work_item = described_class.new(title: "Test", status: "pending")
      expect(work_item).not_to be_valid
      expect(work_item.errors[:type]).to include("can't be blank")
    end

    it "validates presence of title" do
      work_item = described_class.new(type: "task", status: "pending")
      expect(work_item).not_to be_valid
      expect(work_item.errors[:title]).to include("can't be blank")
    end

    it "validates presence of status" do
      work_item = described_class.new(type: "task", title: "Test")
      expect(work_item).not_to be_valid
      expect(work_item.errors[:status]).to include("can't be blank")
    end
  end

  describe "scopes" do
    let!(:task1) { create(:work_item, type: "task", status: "pending") }
    let!(:task2) { create(:work_item, type: "task", status: "completed") }
    let!(:bug) { create(:work_item, type: "bug", status: "pending") }

    describe ".tasks" do
      it "returns only work items with type task" do
        expect(described_class.tasks).to contain_exactly(task1, task2)
      end
    end

    describe ".pending" do
      it "returns only work items with status pending" do
        expect(described_class.pending).to contain_exactly(task1, bug)
      end
    end

    describe ".without_github_issue" do
      let!(:task_with_issue) { create(:work_item, type: "task", github_issue_number: 123) }

      it "returns only work items without GitHub issue numbers" do
        result = described_class.without_github_issue
        expect(result).to include(task1, task2, bug)
        expect(result).not_to include(task_with_issue)
      end
    end
  end
end
