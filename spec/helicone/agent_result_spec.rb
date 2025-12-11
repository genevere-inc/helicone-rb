# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::AgentResult do
  describe "#initialize" do
    it "stores all provided attributes" do
      messages = [Helicone::Message.user_text("Hi")]
      response = instance_double(Helicone::Response)

      result = described_class.new(
        content: "Hello!",
        messages: messages,
        iterations: 2,
        response: response
      )

      expect(result.content).to eq("Hello!")
      expect(result.messages).to eq(messages)
      expect(result.iterations).to eq(2)
      expect(result.response).to eq(response)
    end
  end

  describe "#max_iterations_reached?" do
    it "returns false by default" do
      result = described_class.new(
        content: "Done",
        messages: [],
        iterations: 1
      )

      expect(result.max_iterations_reached?).to be false
    end

    it "returns true when set" do
      result = described_class.new(
        content: "Stopped",
        messages: [],
        iterations: 10,
        max_iterations_reached: true
      )

      expect(result.max_iterations_reached?).to be true
    end
  end

  describe "#success?" do
    it "returns true when content present and not max iterations" do
      result = described_class.new(
        content: "Success!",
        messages: [],
        iterations: 1
      )

      expect(result.success?).to be true
    end

    it "returns false when max iterations reached" do
      result = described_class.new(
        content: "Partial",
        messages: [],
        iterations: 10,
        max_iterations_reached: true
      )

      expect(result.success?).to be false
    end

    it "returns false when content blank" do
      result = described_class.new(
        content: nil,
        messages: [],
        iterations: 0
      )

      expect(result.success?).to be false
    end
  end

  describe "#tool_calls_made" do
    it "counts tool result messages" do
      messages = [
        Helicone::Message.user_text("Hi"),
        Helicone::Message.assistant_text("Let me check..."),
        Helicone::Message.tool_result(tool_call_id: "1", content: { result: "a" }),
        Helicone::Message.tool_result(tool_call_id: "2", content: { result: "b" }),
        Helicone::Message.assistant_text("Done!")
      ]

      result = described_class.new(
        content: "Done!",
        messages: messages,
        iterations: 1
      )

      expect(result.tool_calls_made).to eq(2)
    end

    it "returns 0 when no tool calls" do
      messages = [
        Helicone::Message.user_text("Hi"),
        Helicone::Message.assistant_text("Hello!")
      ]

      result = described_class.new(
        content: "Hello!",
        messages: messages,
        iterations: 0
      )

      expect(result.tool_calls_made).to eq(0)
    end
  end

  describe "#tool_results" do
    it "returns only tool result messages" do
      messages = [
        Helicone::Message.user_text("Hi"),
        Helicone::Message.tool_result(tool_call_id: "1", content: { data: "test" }),
        Helicone::Message.assistant_text("Done")
      ]

      result = described_class.new(
        content: "Done",
        messages: messages,
        iterations: 1
      )

      expect(result.tool_results.length).to eq(1)
      expect(result.tool_results.first.role).to eq("tool")
    end
  end
end
