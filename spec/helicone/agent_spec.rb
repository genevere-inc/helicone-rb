# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::Agent do
  # Define test tools
  before(:all) do
    class CalculatorTool < Helicone::Tool
      description "Perform basic math calculations"

      parameters(
        type: "object",
        properties: {
          expression: {
            type: "string",
            description: "Math expression to evaluate"
          }
        },
        required: ["expression"]
      )

      def execute(expression:)
        { result: eval(expression) }
      rescue => e
        { error: e.message }
      end
    end

    class GreetTool < Helicone::Tool
      description "Greet a person by name"

      parameters(
        type: "object",
        properties: {
          name: { type: "string", description: "Name to greet" }
        },
        required: ["name"]
      )

      def execute(name:)
        { greeting: "Hello, #{name}!" }
      end
    end
  end

  after(:all) do
    Object.send(:remove_const, :CalculatorTool)
    Object.send(:remove_const, :GreetTool)
  end

  let(:mock_client) { instance_double(Helicone::Client) }

  before do
    allow(Helicone::Client).to receive(:new).and_return(mock_client)
  end

  describe "#initialize" do
    it "creates with default client if none provided" do
      described_class.new(tools: [CalculatorTool])

      expect(Helicone::Client).to have_received(:new)
    end

    it "uses provided client" do
      custom_client = instance_double(Helicone::Client)
      agent = described_class.new(client: custom_client, tools: [])

      expect(agent.client).to eq(custom_client)
    end

    it "adds system message if provided" do
      agent = described_class.new(tools: [], system_prompt: "You are helpful")

      expect(agent.messages.first.role).to eq("system")
      expect(agent.messages.first.content).to eq("You are helpful")
    end

    it "stores context for tools" do
      context = { user_id: 123 }
      agent = described_class.new(tools: [], context: context)

      expect(agent.context).to eq(context)
    end
  end

  describe "#run" do
    context "when model responds with text only" do
      it "returns immediately without tool execution" do
        response = instance_double(Helicone::Response,
          content: "The answer is 42",
          tool_calls: nil
        )
        allow(mock_client).to receive(:chat).and_return(response)

        agent = described_class.new(tools: [CalculatorTool])
        result = agent.run("What is the meaning of life?")

        expect(result).to be_a(Helicone::AgentResult)
        expect(result.content).to eq("The answer is 42")
        expect(result.iterations).to eq(0)
        expect(result.tool_calls_made).to eq(0)
      end
    end

    context "when model calls a tool" do
      it "executes the tool and continues" do
        tool_call_response = instance_double(Helicone::Response,
          content: nil,
          tool_calls: [{
            id: "call_123",
            type: "function",
            function: {
              name: "calculator",
              arguments: '{"expression": "2 + 2"}'
            }
          }],
          message: {
            role: "assistant",
            content: nil,
            tool_calls: [{
              id: "call_123",
              type: "function",
              function: {
                name: "calculator",
                arguments: '{"expression": "2 + 2"}'
              }
            }]
          }
        )

        final_response = instance_double(Helicone::Response,
          content: "2 + 2 equals 4",
          tool_calls: nil
        )

        allow(mock_client).to receive(:chat)
          .and_return(tool_call_response, final_response)

        agent = described_class.new(tools: [CalculatorTool])
        result = agent.run("What is 2 + 2?")

        expect(result.content).to eq("2 + 2 equals 4")
        expect(result.iterations).to eq(1)
        expect(result.tool_calls_made).to eq(1)
      end
    end

    context "when max iterations reached" do
      it "returns with max_iterations_reached flag" do
        tool_response = instance_double(Helicone::Response,
          content: nil,
          tool_calls: [{
            id: "call_123",
            function: { name: "calculator", arguments: '{"expression": "1+1"}' }
          }],
          message: {
            role: "assistant",
            tool_calls: [{
              id: "call_123",
              function: { name: "calculator", arguments: '{"expression": "1+1"}' }
            }]
          }
        )

        final_response = instance_double(Helicone::Response,
          content: "I've been calculating too much",
          tool_calls: nil
        )

        call_count = 0
        allow(mock_client).to receive(:chat) do
          call_count += 1
          call_count <= 3 ? tool_response : final_response
        end

        agent = described_class.new(tools: [CalculatorTool])
        result = agent.run("Calculate forever", max_iterations: 3)

        expect(result.max_iterations_reached?).to be true
        expect(result.iterations).to eq(3)
      end
    end

    context "when tool execution fails" do
      it "returns error message and continues" do
        class FailingTool < Helicone::Tool
          description "A tool that fails"
          parameters(type: "object", properties: {}, required: [])

          def execute
            raise "Something went wrong!"
          end
        end

        tool_call_response = instance_double(Helicone::Response,
          content: nil,
          tool_calls: [{
            id: "call_fail",
            function: { name: "failing", arguments: '{}' }
          }],
          message: {
            role: "assistant",
            tool_calls: [{
              id: "call_fail",
              function: { name: "failing", arguments: '{}' }
            }]
          }
        )

        final_response = instance_double(Helicone::Response,
          content: "Sorry, there was an error",
          tool_calls: nil
        )

        allow(mock_client).to receive(:chat)
          .and_return(tool_call_response, final_response)

        agent = described_class.new(tools: [FailingTool])
        result = agent.run("Do the thing")

        tool_results = result.messages.select { |m| m.role == "tool" }
        expect(tool_results.first.content).to include("error")
        expect(result.content).to eq("Sorry, there was an error")

        Object.send(:remove_const, :FailingTool)
      end
    end

    context "with unknown tool" do
      it "returns error for unknown tool name" do
        tool_call_response = instance_double(Helicone::Response,
          content: nil,
          tool_calls: [{
            id: "call_unknown",
            function: { name: "nonexistent_tool", arguments: '{}' }
          }],
          message: {
            role: "assistant",
            tool_calls: [{
              id: "call_unknown",
              function: { name: "nonexistent_tool", arguments: '{}' }
            }]
          }
        )

        final_response = instance_double(Helicone::Response,
          content: "I don't know that tool",
          tool_calls: nil
        )

        allow(mock_client).to receive(:chat)
          .and_return(tool_call_response, final_response)

        agent = described_class.new(tools: [CalculatorTool])
        result = agent.run("Use a fake tool")

        tool_results = result.messages.select { |m| m.role == "tool" }
        expect(tool_results.first.content).to include("Unknown tool")
      end
    end
  end

  describe "#continue" do
    it "continues conversation with existing messages" do
      response1 = instance_double(Helicone::Response, content: "Hi!", tool_calls: nil)
      response2 = instance_double(Helicone::Response, content: "Your name is Bob", tool_calls: nil)

      allow(mock_client).to receive(:chat).and_return(response1, response2)

      agent = described_class.new(tools: [])
      agent.run("My name is Bob")
      result = agent.continue("What is my name?")

      expect(result.content).to eq("Your name is Bob")
      expect(agent.messages.count { |m| m.role == "user" }).to eq(2)
    end
  end
end
