# frozen_string_literal: true

# Structured Logging Helper
#
# Provides consistent structured logging with JSON format for better log aggregation
# and analysis. Logs include contextual information like agent_id, work_item_id, etc.
#
# Usage:
#   StructuredLogger.info("Agent execution started", agent_id: 1, work_item_id: 2)
#   StructuredLogger.error("Operation failed", error: e.message, context: {...})
#
module StructuredLogger
  # Log levels
  LEVELS = %i[debug info warn error].freeze

  # Log an info message with structured context
  #
  # @param message [String] Human-readable message
  # @param context [Hash] Additional structured context
  def self.info(message, **context)
    log(:info, message, context)
  end

  # Log a warning message with structured context
  #
  # @param message [String] Human-readable message
  # @param context [Hash] Additional structured context
  def self.warn(message, **context)
    log(:warn, message, context)
  end

  # Log an error message with structured context
  #
  # @param message [String] Human-readable message
  # @param context [Hash] Additional structured context
  def self.error(message, **context)
    log(:error, message, context)
  end

  # Log a debug message with structured context
  #
  # @param message [String] Human-readable message
  # @param context [Hash] Additional structured context
  def self.debug(message, **context)
    log(:debug, message, context)
  end

  # Log agent execution events
  #
  # @param event [Symbol] Event type (:started, :completed, :failed)
  # @param agent [Agent] The agent being executed
  # @param work_item [WorkItem] The work item being processed
  # @param context [Hash] Additional context
  def self.agent_event(event, agent:, work_item:, **context)
    log(
      event == :failed ? :error : :info,
      "Agent #{event}: #{agent.name}",
      {
        event: "agent.#{event}",
        agent_id: agent.id,
        agent_key: agent.key,
        work_item_id: work_item.id,
        project_id: work_item.project_id,
        work_type: work_item.work_type
      }.merge(context)
    )
  end

  # Log LLM API calls
  #
  # @param event [Symbol] Event type (:request, :response, :error)
  # @param model [String] LLM model name
  # @param context [Hash] Additional context (usage, tokens, etc.)
  def self.llm_event(event, model:, **context)
    level = event == :error ? :error : :info
    log(
      level,
      "LLM #{event}: #{model}",
      {
        event: "llm.#{event}",
        model: model
      }.merge(context)
    )
  end

  # Log GitHub API operations
  #
  # @param operation [String] Operation name (e.g., "create_issue")
  # @param repo [String] Repository name
  # @param context [Hash] Additional context
  def self.github_operation(operation, repo:, **context)
    log(
      :info,
      "GitHub operation: #{operation}",
      {
        event: "github.operation",
        operation: operation,
        repo: repo
      }.merge(context)
    )
  end

  # Log webhook events
  #
  # @param event_type [String] Webhook event type
  # @param project [Project] The project
  # @param context [Hash] Additional context
  def self.webhook_event(event_type, project:, **context)
    log(
      :info,
      "Webhook received: #{event_type}",
      {
        event: "webhook.received",
        event_type: event_type,
        project_id: project.id
      }.merge(context)
    )
  end

  private

  # Internal logging method that formats structured logs
  #
  # @param level [Symbol] Log level
  # @param message [String] Human-readable message
  # @param context [Hash] Structured context
  def self.log(level, message, context = {})
    # Build structured log entry
    log_entry = {
      timestamp: Time.current.iso8601,
      level: level.to_s.upcase,
      message: message,
      service: context.delete(:service) || extract_service_name,
      **context
    }

    # Add request context if available
    if defined?(RequestStore) && RequestStore.store[:request_id]
      log_entry[:request_id] = RequestStore.store[:request_id]
    end

    # Format based on environment
    if Rails.env.production? || ENV["STRUCTURED_LOGS"] == "true"
      # JSON format for production/log aggregation
      Rails.logger.send(level, log_entry.to_json)
    else
      # Human-readable format for development
      formatted = format_human_readable(log_entry)
      Rails.logger.send(level, formatted)
    end
  end

  # Extract service name from caller
  def self.extract_service_name
    caller_locations(2, 1).first&.label&.gsub(/^.*::/, "") || "unknown"
  end

  # Format log entry for human-readable output
  def self.format_human_readable(entry)
    parts = ["[#{entry[:level]}]"]
    parts << "[#{entry[:service]}]" if entry[:service]
    parts << entry[:message]

    # Add key context fields
    context_parts = []
    context_parts << "agent_id=#{entry[:agent_id]}" if entry[:agent_id]
    context_parts << "work_item_id=#{entry[:work_item_id]}" if entry[:work_item_id]
    context_parts << "project_id=#{entry[:project_id]}" if entry[:project_id]
    context_parts << "event=#{entry[:event]}" if entry[:event]

    parts << "(#{context_parts.join(", ")})" if context_parts.any?

    parts.join(" ")
  end
end

