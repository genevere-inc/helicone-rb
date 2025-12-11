# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::ToolCall do
  describe ".new" do
    it "creates a tool call with parsed arguments" do
      tool_call = described_class.new(
        id: "call_123",
        name: "get_weather",
        arguments: { location: "San Francisco" }
      )

      expect(tool_call.id).to eq("call_123")
      expect(tool_call.name).to eq("get_weather")
      expect(tool_call.arguments).to eq({ location: "San Francisco" })
    end

    it "parses JSON string arguments" do
      tool_call = described_class.new(
        id: "call_123",
        name: "get_weather",
        arguments: '{"location": "San Francisco", "unit": "celsius"}'
      )

      expect(tool_call.arguments).to eq({
        location: "San Francisco",
        unit: "celsius"
      })
    end

    it "handles nil arguments" do
      tool_call = described_class.new(
        id: "call_123",
        name: "get_time",
        arguments: nil
      )

      expect(tool_call.arguments).to eq({})
    end
  end

  describe ".from_response" do
    let(:raw_tool_calls) do
      [
        {
          id: "call_abc123",
          type: "function",
          function: {
            name: "get_weather",
            arguments: '{"location": "Boston"}'
          }
        },
        {
          id: "call_def456",
          type: "function",
          function: {
            name: "get_time",
            arguments: '{"timezone": "EST"}'
          }
        }
      ]
    end

    it "parses tool calls from raw response array" do
      tool_calls = described_class.from_response(raw_tool_calls)

      expect(tool_calls.length).to eq(2)
      expect(tool_calls.first.name).to eq("get_weather")
      expect(tool_calls.first[:location]).to eq("Boston")
      expect(tool_calls.last.name).to eq("get_time")
    end

    it "parses tool calls from a Response object" do
      raw_response = {
        choices: [
          {
            message: {
              role: "assistant",
              content: nil,
              tool_calls: raw_tool_calls
            },
            finish_reason: "tool_calls"
          }
        ]
      }
      response = Helicone::Response.new(raw_response)

      tool_calls = described_class.from_response(response)

      expect(tool_calls.length).to eq(2)
      expect(tool_calls.first.id).to eq("call_abc123")
    end

    it "returns empty array when no tool calls" do
      expect(described_class.from_response(nil)).to eq([])
      expect(described_class.from_response([])).to eq([])
    end
  end

  describe "#[]" do
    it "provides hash-like access to arguments" do
      tool_call = described_class.new(
        id: "call_123",
        name: "search",
        arguments: { query: "ruby" }
      )

      expect(tool_call[:query]).to eq("ruby")
    end
  end

  describe "#dig" do
    it "supports nested argument access" do
      tool_call = described_class.new(
        id: "call_123",
        name: "complex",
        arguments: { nested: { value: 42 } }
      )

      expect(tool_call.dig(:nested, :value)).to eq(42)
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      tool_call = described_class.new(
        id: "call_123",
        name: "test",
        arguments: { a: 1 }
      )

      expect(tool_call.to_h).to eq({
        id: "call_123",
        name: "test",
        arguments: { a: 1 }
      })
    end
  end
end

RSpec.describe "Helicone::Message tool result support" do
  describe ".tool_result" do
    it "creates a tool result message with string content" do
      message = Helicone::Message.tool_result(
        tool_call_id: "call_123",
        content: "The weather is sunny"
      )

      expect(message.role).to eq("tool")
      expect(message.content).to eq("The weather is sunny")
      expect(message.tool_call_id).to eq("call_123")
    end

    it "converts hash content to JSON" do
      message = Helicone::Message.tool_result(
        tool_call_id: "call_123",
        content: { temperature: 72, conditions: "sunny" }
      )

      expect(message.content).to eq('{"temperature":72,"conditions":"sunny"}')
    end

    it "includes tool_call_id in to_h output" do
      message = Helicone::Message.tool_result(
        tool_call_id: "call_123",
        content: "result"
      )

      expect(message.to_h).to eq({
        role: "tool",
        content: "result",
        tool_call_id: "call_123"
      })
    end
  end

  describe "regular messages" do
    it "do not include tool_call_id in to_h" do
      message = Helicone::Message.user_text("Hello")

      expect(message.to_h).to eq({ role: "user", content: "Hello" })
      expect(message.to_h).not_to have_key(:tool_call_id)
    end
  end
end
