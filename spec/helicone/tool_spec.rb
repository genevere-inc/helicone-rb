# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::Tool do
  # Define test tool classes
  before(:all) do
    class TestWeatherTool < Helicone::Tool
      description <<~DESC
        Get the current weather for a location.
        Use when the user asks about weather.
      DESC

      parameters(
        type: "object",
        properties: {
          location: {
            type: "string",
            description: "City and state"
          },
          unit: {
            type: "string",
            enum: ["celsius", "fahrenheit"]
          }
        },
        required: ["location"]
      )

      def execute(location:, unit: "fahrenheit")
        { temperature: 72, unit: unit, location: location }
      end
    end

    class TestNoParamsTool < Helicone::Tool
      description "A tool with no parameters"

      def execute
        { status: "done" }
      end
    end
  end

  after(:all) do
    Object.send(:remove_const, :TestWeatherTool)
    Object.send(:remove_const, :TestNoParamsTool)
  end

  describe "class methods" do
    describe ".description" do
      it "sets the tool description" do
        expect(TestWeatherTool.tool_description).to include("Get the current weather")
      end

      it "strips whitespace" do
        expect(TestWeatherTool.tool_description).not_to start_with("\n")
      end
    end

    describe ".parameters" do
      it "sets the tool parameters schema" do
        expect(TestWeatherTool.tool_parameters[:type]).to eq("object")
        expect(TestWeatherTool.tool_parameters[:properties]).to have_key(:location)
      end
    end

    describe ".function_name" do
      it "derives name from class name" do
        expect(TestWeatherTool.function_name).to eq("test_weather")
      end

      it "removes _tool suffix" do
        expect(TestNoParamsTool.function_name).to eq("test_no_params")
      end
    end

    describe ".to_openai_tool" do
      it "generates OpenAI tool definition format" do
        tool_def = TestWeatherTool.to_openai_tool

        expect(tool_def[:type]).to eq("function")
        expect(tool_def[:function][:name]).to eq("test_weather")
        expect(tool_def[:function][:description]).to include("Get the current weather")
        expect(tool_def[:function][:parameters][:type]).to eq("object")
      end

      it "provides default empty parameters for tools without params" do
        tool_def = TestNoParamsTool.to_openai_tool

        expect(tool_def[:function][:parameters]).to eq({
          type: "object",
          properties: {},
          required: []
        })
      end
    end

    describe ".inherited" do
      it "ensures subclasses get their own class instance variables" do
        expect(TestWeatherTool.tool_description).not_to eq(TestNoParamsTool.tool_description)
      end
    end
  end

  describe "instance methods" do
    describe "#initialize" do
      it "accepts optional context" do
        context = { chat_id: 123 }
        tool = TestWeatherTool.new(context)

        expect(tool.context).to eq(context)
      end

      it "works without context" do
        tool = TestWeatherTool.new

        expect(tool.context).to be_nil
      end
    end

    describe "#execute" do
      it "executes with provided arguments" do
        tool = TestWeatherTool.new

        result = tool.execute(location: "San Francisco", unit: "celsius")

        expect(result[:temperature]).to eq(72)
        expect(result[:location]).to eq("San Francisco")
        expect(result[:unit]).to eq("celsius")
      end

      it "uses default values for optional params" do
        tool = TestWeatherTool.new

        result = tool.execute(location: "Boston")

        expect(result[:unit]).to eq("fahrenheit")
      end

      it "raises NotImplementedError for base class" do
        tool = Helicone::Tool.new

        expect { tool.execute }.to raise_error(NotImplementedError)
      end
    end
  end
end
