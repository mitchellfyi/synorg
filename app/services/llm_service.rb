# frozen_string_literal: true

require "openai"

# LLM Service
#
# Wraps OpenAI API calls to provide a consistent interface for LLM interactions.
# Handles authentication, request formatting, and response parsing.
#
# Example usage:
#   service = LlmService.new
#   response = service.chat(prompt: "Hello", context: { project: "test" })
#   # => { content: "...", usage: {...} }
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
  # @param temperature [Float] Sampling temperature (0.0 to 2.0)
  # @param max_tokens [Integer] Maximum tokens in response
  # @return [Hash] Response hash with :content and :usage keys
  def chat(prompt:, context: {}, system_message: nil, temperature: DEFAULT_TEMPERATURE, max_tokens: DEFAULT_MAX_TOKENS)
    messages = build_messages(prompt, context, system_message)

    response = client.chat(
      parameters: {
        model: model,
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens
      }
    )

    parse_response(response)
  rescue OpenAI::Error => e
    Rails.logger.error("OpenAI API error: #{e.message}")
    {
      content: nil,
      usage: {},
      error: e.message
    }
  rescue StandardError => e
    Rails.logger.error("LlmService error: #{e.message}\n#{e.backtrace.join("\n")}")
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

  def build_messages(prompt, context, system_message)
    messages = []

    # System message with context
    system_content = system_message || build_system_message(context)
    messages << { role: "system", content: system_content } if system_content.present?

    # User message with prompt
    user_content = format_user_message(prompt, context)
    messages << { role: "user", content: user_content }

    messages
  end

  def build_system_message(context)
    return nil if context.empty?

    parts = ["You are a helpful AI assistant working on a software project."]

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

  def parse_response(response)
    content = response.dig("choices", 0, "message", "content")
    usage = response["usage"] || {}

    {
      content: content,
      usage: {
        prompt_tokens: usage["prompt_tokens"] || 0,
        completion_tokens: usage["completion_tokens"] || 0,
        total_tokens: usage["total_tokens"] || 0
      }
    }
  end
end

