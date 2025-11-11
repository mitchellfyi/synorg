# frozen_string_literal: true

module WorkItemsHelper
  def work_item_status_badge_class(status)
    case status
    when "pending"
      "bg-gray-100 text-gray-800"
    when "in_progress"
      "bg-blue-100 text-blue-800"
    when "completed"
      "bg-green-100 text-green-800"
    when "failed"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
