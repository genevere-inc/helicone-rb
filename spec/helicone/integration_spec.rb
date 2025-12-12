# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Helicone Integration", type: :integration do
  # Run live tests against the actual API:
  # HELICONE_LIVE_TEST=true HELICONE_API_KEY=your_key bundle exec rspec spec/helicone/integration_spec.rb

  before(:each) do
    skip "Set HELICONE_LIVE_TEST=true to run live integration tests" unless ENV["HELICONE_LIVE_TEST"]
    skip "HELICONE_API_KEY must be set" unless ENV["HELICONE_API_KEY"]
  end

  describe "live API calls" do
    let(:client) { Helicone::Client.new }

    it "can ask a simple math question and get the correct answer" do
      response = client.ask("What is 2+2? Reply with just the number.")

      expect(response).not_to be_nil
      expect(response).to include("4")
    end

    it "returns a full Response object from chat" do
      messages = [
        Helicone::Message.system("You are a helpful assistant. Be very brief."),
        Helicone::Message.user_text("What is the capital of France? One word answer.")
      ]

      response = client.chat(messages: messages)

      expect(response).to be_a(Helicone::Response)
      expect(response.content).not_to be_nil
      expect(response.content.downcase).to include("paris")
      expect(response.role).to eq("assistant")
      expect(response.finish_reason).to eq("stop")
      expect(response.total_tokens).to be > 0
    end

    it "supports conversation history" do
      messages = [
        Helicone::Message.user_text("My name is Alice."),
        Helicone::Message.assistant_text("Nice to meet you, Alice!"),
        Helicone::Message.user_text("What is my name?")
      ]

      response = client.chat(messages: messages)

      expect(response.content.downcase).to include("alice")
    end

    it "tracks sessions with Helicone headers" do
      client_with_session = Helicone::Client.new(
        session_id: "test-session-#{Time.now.to_i}",
        session_name: "RSpec Integration Test"
      )

      response = client_with_session.ask("Say 'hello'")

      expect(response).not_to be_nil
    end

    it "tracks accounts with Helicone headers" do
      client_with_account = Helicone::Client.new(
        account_id: "test-account-123",
        account_name: "Test Account"
      )

      response = client_with_account.ask("Say 'test'")

      expect(response).not_to be_nil
    end
  end

  describe "live API with images" do
    let(:client) { Helicone::Client.new }

    it "can describe an image from URL" do
      # Using a public test image
      image_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4d/Cat_November_2010-1a.jpg/1200px-Cat_November_2010-1a.jpg"

      response = client.ask_with_image(
        "What animal is in this image? Reply with just the animal name.",
        image_url
      )

      expect(response.downcase).to include("cat")
    end
  end

  describe "live agent with tools" do
    before(:all) do
      class TestAdditionTool < Helicone::Tool
        description "Add two numbers together"

        parameters(
          type: "object",
          properties: {
            a: { type: "number", description: "First number" },
            b: { type: "number", description: "Second number" }
          },
          required: ["a", "b"]
        )

        def execute(a:, b:)
          { result: a + b }
        end
      end
    end

    after(:all) do
      Object.send(:remove_const, :TestAdditionTool) if defined?(TestAdditionTool)
    end

    it "executes tools and returns final response" do
      agent = Helicone::Agent.new(
        tools: [TestAdditionTool],
        system_prompt: "You are a helpful assistant. Use the addition tool for math questions."
      )

      result = agent.run("What is 15 + 7? Use the addition tool.")

      expect(result).to be_a(Helicone::AgentResult)
      expect(result.content).not_to be_nil
      expect(result.content).to include("22")
      expect(result.tool_calls_made).to be >= 1
    end
  end
end
