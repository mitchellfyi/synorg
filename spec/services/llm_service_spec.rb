# frozen_string_literal: true

require "rails_helper"

RSpec.describe LlmService do
  let(:api_key) { "test-api-key" }
  let(:model) { "gpt-4o-mini" }
  let(:service) { described_class.new(api_key: api_key, model: model) }
  let(:mock_client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
  end

  describe "#initialize" do
    context "with explicit API key" do
      it "uses the provided API key" do
        expect(OpenAI::Client).to receive(:new).with(access_token: api_key)
        described_class.new(api_key: api_key)
      end
    end

    context "without explicit API key" do
      it "fetches API key from Rails credentials" do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return("credential-key")
        expect(OpenAI::Client).to receive(:new).with(access_token: "credential-key")
        described_class.new
      end

      it "falls back to ENV variable if credentials not found" do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return("env-key")
        expect(OpenAI::Client).to receive(:new).with(access_token: "env-key")
        described_class.new
      end

      it "raises ArgumentError if no API key is available" do
        allow(Rails.application.credentials).to receive(:dig).with(:openai, :api_key).and_return(nil)
        allow(ENV).to receive(:[]).with("OPENAI_API_KEY").and_return(nil)
        expect { described_class.new }.to raise_error(ArgumentError, "OpenAI API key is required")
      end
    end

    context "with custom model" do
      it "uses the provided model" do
        custom_service = described_class.new(api_key: api_key, model: "gpt-4")
        expect(custom_service.model).to eq("gpt-4")
      end
    end

    context "without custom model" do
      it "uses default model" do
        expect(service.model).to eq(LlmService::DEFAULT_MODEL)
      end
    end
  end

  describe "#chat" do
    let(:prompt) { "Test prompt" }
    let(:context) { {} }
    let(:mock_response) do
      {
        "choices" => [
          {
            "message" => {
              "content" => "Test response"
            }
          }
        ],
        "usage" => {
          "prompt_tokens" => 10,
          "completion_tokens" => 5,
          "total_tokens" => 15
        }
      }
    end

    before do
      allow(mock_client).to receive(:chat).and_return(mock_response)
    end

    it "calls the OpenAI API with correct parameters" do
      expect(mock_client).to receive(:chat).with(
        parameters: hash_including(
          model: model,
          messages: array_including(
            hash_including(role: "user", content: prompt)
          ),
          temperature: LlmService::DEFAULT_TEMPERATURE,
          max_tokens: LlmService::DEFAULT_MAX_TOKENS
        )
      )

      service.chat(prompt: prompt, context: context)
    end

    it "returns parsed response with content and usage" do
      result = service.chat(prompt: prompt, context: context)

      expect(result).to include(
        content: "Test response",
        usage: hash_including(
          prompt_tokens: 10,
          completion_tokens: 5,
          total_tokens: 15
        )
      )
    end

    context "with context" do
      let(:context) do
        {
          project: {
            name: "Test Project",
            repo_full_name: "test/repo",
            brief: "A test project"
          },
          agent: {
            name: "Test Agent",
            key: "test_agent",
            capabilities: "testing"
          },
          work_item: {
            work_type: "test",
            priority: "high"
          }
        }
      end

      it "includes system message with context" do
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(
            messages: array_including(
              hash_including(role: "system", content: include("Test Project"))
            )
          )
        )

        service.chat(prompt: prompt, context: context)
      end
    end

    context "with custom system message" do
      it "uses custom system message instead of building from context" do
        custom_system = "Custom system message"
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(
            messages: array_including(
              hash_including(role: "system", content: custom_system)
            )
          )
        )

        service.chat(prompt: prompt, context: context, system_message: custom_system)
      end
    end

    context "with custom temperature and max_tokens" do
      it "uses custom values" do
        expect(mock_client).to receive(:chat).with(
          parameters: hash_including(
            temperature: 0.5,
            max_tokens: 2000
          )
        )

        service.chat(prompt: prompt, context: context, temperature: 0.5, max_tokens: 2000)
      end
    end

    context "when OpenAI API returns an error" do
      before do
        allow(mock_client).to receive(:chat).and_raise(OpenAI::Error.new("API Error"))
      end

      it "returns error hash without raising" do
        result = service.chat(prompt: prompt, context: context)

        expect(result).to include(
          content: nil,
          usage: {},
          error: "API Error"
        )
      end
    end

    context "when response has no content" do
      let(:empty_response) do
        {
          "choices" => [],
          "usage" => {}
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(empty_response)
      end

      it "returns nil content" do
        result = service.chat(prompt: prompt, context: context)

        expect(result[:content]).to be_nil
      end
    end

    context "when response has no usage data" do
      let(:no_usage_response) do
        {
          "choices" => [
            {
              "message" => {
                "content" => "Test response"
              }
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:chat).and_return(no_usage_response)
      end

      it "returns zero usage values" do
        result = service.chat(prompt: prompt, context: context)

        expect(result[:usage]).to eq(
          prompt_tokens: 0,
          completion_tokens: 0,
          total_tokens: 0
        )
      end
    end
  end

  describe "private methods" do
    describe "#build_system_message" do
      it "returns nil for empty context" do
        messages = service.send(:build_messages, "test", {}, nil)
        expect(messages.none? { |m| m[:role] == "system" }).to be(true)
      end

      it "includes project information in system message" do
        context = { project: { name: "Test", repo_full_name: "test/repo" } }
        messages = service.send(:build_messages, "test", context, nil)
        system_msg = messages.find { |m| m[:role] == "system" }

        expect(system_msg[:content]).to include("Test")
        expect(system_msg[:content]).to include("test/repo")
      end
    end

    describe "#format_user_message" do
      it "returns prompt as-is for empty context" do
        result = service.send(:format_user_message, "test prompt", {})
        expect(result).to eq("test prompt")
      end

      it "includes work item payload when present" do
        context = { work_item: { payload: { key: "value" } } }
        result = service.send(:format_user_message, "test prompt", context)

        expect(result).to include("test prompt")
        expect(result).to include("key")
        expect(result).to include("value")
      end
    end
  end
end

