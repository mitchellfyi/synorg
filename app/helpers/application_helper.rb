# frozen_string_literal: true

module ApplicationHelper
  def agent_enabled_badge_class(enabled)
    enabled ? "bg-green-100 text-green-800" : "bg-gray-100 text-gray-800"
  end
end
