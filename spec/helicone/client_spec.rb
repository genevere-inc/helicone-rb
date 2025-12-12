# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::Client do
  let(:mock_openai_client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
    allow(mock_openai_client).to receive(:add_headers)
  end

  describe "#initialize" do
    it "creates an OpenAI client with ENV key and Helicone URI" do
      allow(ENV).to receive(:[]).with("HELICONE_API_KEY").and_return("test-key")

      described_class.new

      expect(OpenAI::Client).to have_received(:new).with(
        access_token: "test-key",
        uri_base: "https://ai-gateway.helicone.ai/v1"
      )
    end

    context "with session tracking" do
      it "adds session headers when session_id is provided" do
        described_class.new(session_id: 123)

        expect(mock_openai_client).to have_received(:add_headers).with(
          "Helicone-Session-Id" => "123",
          "Helicone-Session-Name" => "Conversation #123"
        )
      end

      it "uses custom session_name when provided" do
        described_class.new(session_id: 123, session_name: "My Chat")

        expect(mock_openai_client).to have_received(:add_headers).with(
          "Helicone-Session-Id" => "123",
          "Helicone-Session-Name" => "My Chat"
        )
      end
    end

    context "with account tracking" do
      it "adds account headers when account_id is provided" do
        described_class.new(account_id: 456)

        expect(mock_openai_client).to have_received(:add_headers).with(
          "Helicone-User-Id" => "456",
          "Helicone-Property-Account" => "456"
        )
      end

      it "uses custom account_name when provided" do
        described_class.new(account_id: 456, account_name: "Acme Corp")

        expect(mock_openai_client).to have_received(:add_headers).with(
          "Helicone-User-Id" => "456",
          "Helicone-Property-Account" => "Acme Corp"
        )
      end
    end

    context "with both session and account" do
      it "adds all headers" do
        described_class.new(
          session_id: 123,
          session_name: "Chat",
          account_id: 456,
          account_name: "Acme"
        )

        expect(mock_openai_client).to have_received(:add_headers).with(
          "Helicone-Session-Id" => "123",
          "Helicone-Session-Name" => "Chat"
        )
        expect(mock_openai_client).to have_received(:add_headers).with(
          "Helicone-User-Id" => "456",
          "Helicone-Property-Account" => "Acme"
        )
      end
    end
  end

  describe "#chat" do
    let(:raw_response) do
      {
        "choices" => [
          { "message" => { "role" => "assistant", "content" => "Hello!" }, "finish_reason" => "stop" }
        ]
      }
    end

    before do
      allow(mock_openai_client).to receive(:chat).and_return(raw_response)
    end

    it "sends messages to the OpenAI client" do
      client = described_class.new
      messages = [Helicone::Message.user_text("Hi")]

      client.chat(messages: messages)

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: hash_including(
          model: "gpt-4o",
          messages: [{ role: "user", content: "Hi" }]
        )
      )
    end

    it "returns a Response object" do
      client = described_class.new
      response = client.chat(messages: [Helicone::Message.user_text("Hi")])

      expect(response).to be_a(Helicone::Response)
      expect(response.content).to eq("Hello!")
    end

    it "accepts hash messages as well as Message objects" do
      client = described_class.new
      client.chat(messages: [{ role: "user", content: "Hi" }])

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: hash_including(
          messages: [{ role: "user", content: "Hi" }]
        )
      )
    end

    it "allows custom model" do
      client = described_class.new
      client.chat(messages: [Helicone::Message.user_text("Hi")], model: "gpt-4o")

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: hash_including(model: "gpt-4o")
      )
    end

    it "passes through additional options" do
      client = described_class.new
      client.chat(
        messages: [Helicone::Message.user_text("Hi")],
        temperature: 0.5,
        max_tokens: 100
      )

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: hash_including(
          temperature: 0.5,
          max_tokens: 100
        )
      )
    end
  end

  describe "#ask" do
    let(:raw_response) do
      {
        "choices" => [
          { "message" => { "role" => "assistant", "content" => "4" }, "finish_reason" => "stop" }
        ]
      }
    end

    before do
      allow(mock_openai_client).to receive(:chat).and_return(raw_response)
    end

    it "sends a simple text prompt and returns content" do
      client = described_class.new
      result = client.ask("What is 2+2?")

      expect(result).to eq("4")
    end

    it "includes system message when provided" do
      client = described_class.new
      client.ask("What is 2+2?", system_prompt: "You are a math tutor")

      expect(mock_openai_client).to have_received(:chat).with(
        parameters: hash_including(
          messages: [
            { role: "system", content: "You are a math tutor" },
            { role: "user", content: "What is 2+2?" }
          ]
        )
      )
    end
  end

  describe "#ask_with_image" do
    let(:raw_response) do
      {
        "choices" => [
          { "message" => { "role" => "assistant", "content" => "A cat" }, "finish_reason" => "stop" }
        ]
      }
    end

    before do
      allow(mock_openai_client).to receive(:chat).and_return(raw_response)
    end

    it "sends a prompt with an image and returns content" do
      client = described_class.new
      result = client.ask_with_image("What is this?", "https://example.com/cat.jpg")

      expect(result).to eq("A cat")
    end

    it "structures the message correctly with image" do
      client = described_class.new
      client.ask_with_image("Describe", "https://example.com/image.jpg", detail: "high")

      expect(mock_openai_client).to have_received(:chat) do |args|
        messages = args[:parameters][:messages]
        user_message = messages.find { |m| m[:role] == "user" }
        expect(user_message[:content]).to be_an(Array)

        image_part = user_message[:content].find { |c| c[:type] == "image_url" }
        expect(image_part[:image_url][:url]).to eq("https://example.com/image.jpg")
        expect(image_part[:image_url][:detail]).to eq("high")
      end
    end
  end

  describe "#add_headers" do
    it "delegates to the OpenAI client" do
      client = described_class.new
      client.add_headers("X-Custom" => "value")

      expect(mock_openai_client).to have_received(:add_headers).with("X-Custom" => "value")
    end
  end
end
