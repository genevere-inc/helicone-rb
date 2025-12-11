# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::Response do
  let(:raw_response) do
    {
      id: "chatcmpl-abc123",
      object: "chat.completion",
      created: 1234567890,
      model: "gpt-4",
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content: "The answer is 4."
          },
          finish_reason: "stop"
        }
      ],
      usage: {
        prompt_tokens: 10,
        completion_tokens: 5,
        total_tokens: 15
      }
    }
  end

  subject(:response) { described_class.new(raw_response) }

  describe "#content" do
    it "returns the assistant message content" do
      expect(response.content).to eq("The answer is 4.")
    end
  end

  describe "#role" do
    it "returns the message role" do
      expect(response.role).to eq("assistant")
    end
  end

  describe "#message" do
    it "returns the full message hash" do
      expect(response.message).to eq({
        role: "assistant",
        content: "The answer is 4."
      })
    end
  end

  describe "#finish_reason" do
    it "returns the finish reason" do
      expect(response.finish_reason).to eq("stop")
    end
  end

  describe "#choices" do
    it "returns all choices" do
      expect(response.choices).to be_an(Array)
      expect(response.choices.length).to eq(1)
    end
  end

  describe "usage methods" do
    it "returns prompt_tokens" do
      expect(response.prompt_tokens).to eq(10)
    end

    it "returns completion_tokens" do
      expect(response.completion_tokens).to eq(5)
    end

    it "returns total_tokens" do
      expect(response.total_tokens).to eq(15)
    end
  end

  describe "#model" do
    it "returns the model used" do
      expect(response.model).to eq("gpt-4")
    end
  end

  describe "#id" do
    it "returns the completion id" do
      expect(response.id).to eq("chatcmpl-abc123")
    end
  end

  describe "#success?" do
    it "returns true when content is present" do
      expect(response.success?).to be true
    end

    it "returns true when finish_reason is stop" do
      raw = { choices: [{ message: {}, finish_reason: "stop" }] }
      resp = described_class.new(raw)
      expect(resp.success?).to be true
    end

    it "returns false when no content and not stopped" do
      raw = { choices: [{ message: {}, finish_reason: "length" }] }
      resp = described_class.new(raw)
      expect(resp.success?).to be false
    end
  end

  describe "#tool_calls" do
    it "returns nil when no tool calls" do
      expect(response.tool_calls).to be_nil
    end

    it "returns tool calls when present" do
      raw = Helicone::Message.deep_dup(raw_response)
      raw[:choices][0][:message][:tool_calls] = [
        { id: "call_123", type: "function", function: { name: "get_weather" } }
      ]
      resp = described_class.new(raw)
      expect(resp.tool_calls).to be_an(Array)
      expect(resp.tool_calls.first[:function][:name]).to eq("get_weather")
    end
  end

  describe "#to_message" do
    it "converts the response to a Message object" do
      message = response.to_message

      expect(message).to be_a(Helicone::Message)
      expect(message.role).to eq("assistant")
      expect(message.content).to eq("The answer is 4.")
    end
  end

  describe "hash-like access" do
    it "supports bracket access" do
      expect(response[:model]).to eq("gpt-4")
    end

    it "supports dig" do
      expect(response.dig(:choices, 0, :message, :content)).to eq("The answer is 4.")
    end
  end
end
