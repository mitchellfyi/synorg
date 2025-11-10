# frozen_string_literal: true

module ProjectsHelper
  def state_badge_class(state)
    case state
    when "draft"
      "bg-gray-100 text-gray-800"
    when "scoped"
      "bg-blue-100 text-blue-800"
    when "repo_bootstrapped"
      "bg-purple-100 text-purple-800"
    when "in_build"
      "bg-yellow-100 text-yellow-800"
    when "live"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def run_status_badge_class(outcome)
    case outcome
    when "success"
      "bg-green-100 text-green-800"
    when "failure"
      "bg-red-100 text-red-800"
    when nil
      "bg-blue-100 text-blue-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def run_status_text(outcome, started_at, finished_at)
    if outcome.nil? && started_at.present?
      "In Progress"
    elsif outcome.nil?
      "Pending"
    else
      outcome.titleize
    end
  end

  def run_duration(started_at, finished_at)
    return "N/A" if started_at.nil?

    end_time = finished_at || Time.current
    duration_seconds = (end_time - started_at).to_i

    if duration_seconds < 60
      "#{duration_seconds}s"
    elsif duration_seconds < 3600
      minutes = duration_seconds / 60
      seconds = duration_seconds % 60
      "#{minutes}m #{seconds}s"
    else
      hours = duration_seconds / 3600
      minutes = (duration_seconds % 3600) / 60
      "#{hours}h #{minutes}m"
    end
  end
end
