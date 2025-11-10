# frozen_string_literal: true

module ActivitiesHelper
  def activity_description(activity)
    params = activity.parameters || {}

    case activity.key
    when "project.create"
      "Project created: #{activity.trackable.respond_to?(:name) ? activity.trackable.name : activity.trackable.slug}"
    when "project.update"
      "Project updated: #{activity.trackable.respond_to?(:name) ? activity.trackable.name : activity.trackable.slug}"
    when "project.state_changed"
      "Project state changed: #{params['from'] || params[:from]} → #{params['to'] || params[:to]}"
    when "orchestrator.triggered"
      "Orchestrator triggered"
    when "orchestrator.completed"
      "Orchestrator completed (#{params['work_items_created'] || params[:work_items_created] || 0} work items created)"
    when "orchestrator.failed"
      "Orchestrator failed: #{params['error'] || params[:error]}"
    when "llm.request"
      "LLM request (#{params['model'] || params[:model] || 'unknown'})"
    when "llm.response"
      usage = params["usage"] || params[:usage] || {}
      tokens = usage["total_tokens"] || usage[:total_tokens] || 0
      "LLM response (#{params['model'] || params[:model] || 'unknown'}, #{tokens} tokens)"
    when "llm.error"
      "LLM error: #{params['error'] || params[:error]}"
    when "work_item.create"
      "Work item created: #{params['work_type'] || params[:work_type] || 'unknown'}"
    when "work_item.update"
      "Work item updated: #{params['work_type'] || params[:work_type] || 'unknown'}"
    when "work_item.completed"
      "Work item completed: #{params['work_type'] || params[:work_type] || 'unknown'}"
    when "work_item.failed"
      "Work item failed: #{params['work_type'] || params[:work_type] || 'unknown'}"
    when "run.started"
      "Run started: #{params['agent_name'] || params[:agent_name] || params['agent_key'] || params[:agent_key] || 'unknown agent'}"
    when "run.completed"
      duration = params["duration"] || params[:duration]
      duration_str = duration ? "#{duration}s" : "unknown duration"
      "Run completed: #{params['agent_name'] || params[:agent_name] || params['agent_key'] || params[:agent_key] || 'unknown agent'} (#{duration_str})"
    when "run.failed"
      "Run failed: #{params['agent_name'] || params[:agent_name] || params['agent_key'] || params[:agent_key] || 'unknown agent'}"
    else
      activity.key.humanize
    end
  end

  def icon_bg_class(activity)
    case activity.key
    when /\.completed$/, /\.success/
      "bg-green-100"
    when /\.failed$/, /\.error/
      "bg-red-100"
    when /\.started$/, /\.triggered$/
      "bg-blue-100"
    when /^project\./
      "bg-purple-100"
    when /^orchestrator\./
      "bg-yellow-100"
    when /^llm\./
      "bg-indigo-100"
    when /^work_item\./
      "bg-gray-100"
    when /^run\./
      "bg-cyan-100"
    else
      "bg-gray-100"
    end
  end

  def activity_color_badge(activity)
    case activity.key
    when /\.completed$/, /\.success/
      "bg-green-100 text-green-800"
    when /\.failed$/, /\.error/
      "bg-red-100 text-red-800"
    when /\.started$/, /\.triggered$/
      "bg-blue-100 text-blue-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
