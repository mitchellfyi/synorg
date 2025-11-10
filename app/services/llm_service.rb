# frozen_string_literal: true

require "openai"
require_relative "../lib/structured_logger"
require_relative "../lib/llm_output_schema"

# LLM Service
#
# Wraps OpenAI API calls to provide a consistent interface for LLM interactions.
# Handles authentication, request formatting, and response parsing with structured outputs.
#
# Example usage:
#   service = LlmService.new
#   response = service.chat(prompt: "Hello", context: { project: "test" })
#   # => { content: "...", usage: {...} }
#
#   # With structured output:
#   schema = LlmOutputSchema.for_type(:work_items)
#   response = service.chat(prompt: "...", structured_output: schema)
#   # => { content: {...}, usage: {...} } where content is validated JSON
#
class LlmService
  attr_reader :api_key, :model, :client

  DEFAULT_MODEL = "gpt-4o-mini".freeze
  DEFAULT_TEMPERATURE = 0.7
  DEFAULT_MAX_TOKENS = 4000

  def initialize(api_key: nil, model: nil)
    @api_key = api_key || fetch_api_key
    @model = model || DEFAULT_MODEL

    raise ArgumentError, "OpenAI API key is required" unless @api_key

    @client = OpenAI::Client.new(access_token: @api_key)
  end

  # Send a chat completion request to the LLM
  #
  # @param prompt [String] The user prompt/message
  # @param context [Hash] Additional context to include in the system message
  # @param system_message [String] Optional custom system message
  # @param temperature [Float] Sampling temperature (0.0 to 2.0). Use 0.0 for deterministic outputs.
  # @param max_tokens [Integer] Maximum tokens in response
  # @param project [Project] Optional project for activity tracking
  # @param agent [Agent] Optional agent for activity tracking
  # @param structured_output [LlmOutputSchema] Optional schema for structured JSON output
  # @return [Hash] Response hash with :content and :usage keys
  def chat(prompt:, context: {}, system_message: nil, temperature: DEFAULT_TEMPERATURE, max_tokens: DEFAULT_MAX_TOKENS, project: nil, agent: nil, structured_output: nil)
    messages = build_messages(prompt, context, system_message, structured_output)

    StructuredLogger.llm_event(
      :request,
      model: model,
      temperature: temperature,
      max_tokens: max_tokens,
      prompt_length: prompt.length,
      structured_output: structured_output&.schema_type
    )

    # Track LLM request activity
    if project
      Activity.create!(
        trackable: agent || project,
        owner: agent,
        recipient: project,
        key: Activity::KEYS[:llm_request],
        parameters: {
          model: model,
          temperature: temperature,
          max_tokens: max_tokens,
          prompt_length: prompt.length,
          agent_key: agent&.key,
          agent_name: agent&.name,
          structured_output: structured_output&.schema_type
        },
        project: project,
        created_at: Time.current
      )
    end

    # Build request parameters
    request_params = {
      model: model,
      messages: messages,
      temperature: temperature,
      max_tokens: max_tokens
    }

    # Add structured output if schema provided
    if structured_output
      request_params[:response_format] = {
        type: "json_schema",
        json_schema: {
          name: "#{structured_output.schema_type}_response",
          strict: true,
          schema: structured_output.to_openai_schema
        }
      }
      # Use temperature 0 for deterministic structured outputs
      request_params[:temperature] = 0.0
    end

    response = client.chat(parameters: request_params)

    parsed = parse_response(response, structured_output)

    # Track LLM response activity
    if project
      if parsed[:error]
        Activity.create!(
          trackable: agent || project,
          owner: agent,
          recipient: project,
          key: Activity::KEYS[:llm_error],
          parameters: {
            model: model,
            error: parsed[:error],
            agent_key: agent&.key,
            agent_name: agent&.name
          },
          project: project,
          created_at: Time.current
        )
      else
        Activity.create!(
          trackable: agent || project,
          owner: agent,
          recipient: project,
          key: Activity::KEYS[:llm_response],
          parameters: {
            model: model,
            usage: parsed[:usage],
            response_length: parsed[:content].is_a?(Hash) ? parsed[:content].to_json.length : (parsed[:content]&.length || 0),
            agent_key: agent&.key,
            agent_name: agent&.name,
            structured_output: structured_output&.schema_type
          },
          project: project,
          created_at: Time.current
        )
      end
    end

    parsed
  rescue OpenAI::Error => e
    StructuredLogger.llm_event(
      :error,
      model: model,
      error: e.message,
      error_class: e.class.name
    )

    # Track LLM error activity
    if project
      Activity.create!(
        trackable: agent || project,
        owner: agent,
        recipient: project,
        key: Activity::KEYS[:llm_error],
        parameters: {
          model: model,
          error: e.message,
          error_class: e.class.name,
          agent_key: agent&.key,
          agent_name: agent&.name
        },
        project: project,
        created_at: Time.current
      )
    end

    {
      content: nil,
      usage: {},
      error: e.message
    }
  rescue StandardError => e
    StructuredLogger.error(
      "LlmService error",
      model: model,
      error: e.message,
      error_class: e.class.name,
      backtrace: e.backtrace.first(5)
    )

    # Track LLM error activity
    if project
      Activity.create!(
        trackable: agent || project,
        owner: agent,
        recipient: project,
        key: Activity::KEYS[:llm_error],
        parameters: {
          model: model,
          error: e.message,
          error_class: e.class.name,
          agent_key: agent&.key,
          agent_name: agent&.name
        },
        project: project,
        created_at: Time.current
      )
    end

    {
      content: nil,
      usage: {},
      error: e.message
    }
  end

  private

  def fetch_api_key
    Rails.application.credentials.dig(:openai, :api_key) || ENV["OPENAI_API_KEY"]
  end

  def build_messages(prompt, context, system_message, structured_output)
    messages = []

    # System message with context and structured output instructions
    system_content = system_message || build_system_message(context, structured_output)
    messages << { role: "system", content: system_content } if system_content.present?

    # User message with prompt
    user_content = format_user_message(prompt, context)
    messages << { role: "user", content: user_content }

    messages
  end

  def build_system_message(context, structured_output)
    parts = ["You are a helpful AI assistant working on a software project."]

    # Add structured output instructions
    if structured_output
      parts << "\n\nIMPORTANT: You must respond with valid JSON matching the required schema."
      parts << "The response must be a JSON object, not a JSON string."
      parts << "Do not include any markdown formatting, code blocks, or explanatory text."
      parts << "Return only the JSON object."
    end

    if context[:project]
      parts << "\nProject context:"
      parts << "- Name: #{context[:project][:name]}" if context[:project][:name]
      parts << "- Repository: #{context[:project][:repo_full_name]}" if context[:project][:repo_full_name]
      parts << "- Brief: #{context[:project][:brief]}" if context[:project][:brief]
    end

    if context[:agent]
      parts << "\nAgent context:"
      parts << "- Agent: #{context[:agent][:name]} (#{context[:agent][:key]})" if context[:agent][:name]
      parts << "- Capabilities: #{context[:agent][:capabilities]}" if context[:agent][:capabilities]
    end

    if context[:work_item]
      parts << "\nWork item context:"
      parts << "- Type: #{context[:work_item][:work_type]}" if context[:work_item][:work_type]
      parts << "- Priority: #{context[:work_item][:priority]}" if context[:work_item][:priority]
    end

    parts.join("\n")
  end

  def format_user_message(prompt, context)
    return prompt if context.empty?

    parts = [prompt]

    # Add structured context if available
    if context[:work_item] && context[:work_item][:payload]
      payload = context[:work_item][:payload]
      parts << "\n\nAdditional context:" if payload.present?
      parts << JSON.pretty_generate(payload) if payload.present?
    end

    parts.join("\n")
  end

  def parse_response(response, structured_output)
    content = response.dig("choices", 0, "message", "content")
    usage = response["usage"] || {}

    StructuredLogger.llm_event(
      :response,
      model: model,
      usage: {
        prompt_tokens: usage["prompt_tokens"] || 0,
        completion_tokens: usage["completion_tokens"] || 0,
        total_tokens: usage["total_tokens"] || 0
      }
    )

    # Parse structured output if schema provided
    parsed_content = if structured_output && content
                       begin
                         # Content is already JSON when using structured outputs
                         JSON.parse(content).deep_symbolize_keys
                       rescue JSON::ParserError => e
                         StructuredLogger.error(
                           "Failed to parse structured output",
                           error: e.message,
                           content_preview: content&.truncate(500)
                         )
                         nil
                       end
                     else
                       content
                     end

    {
      content: parsed_content,
      usage: {
        prompt_tokens: usage["prompt_tokens"] || 0,
        completion_tokens: usage["completion_tokens"] || 0,
        total_tokens: usage["total_tokens"] || 0
      }
    }
  end
end
