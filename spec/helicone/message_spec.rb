# frozen_string_literal: true

require "spec_helper"

RSpec.describe Helicone::Message do
  describe ".user_text" do
    it "creates a user message with text content" do
      message = described_class.user_text("Hello world")

      expect(message.role).to eq("user")
      expect(message.content).to eq("Hello world")
    end

    it "converts to hash for API" do
      message = described_class.user_text("Hello")

      expect(message.to_h).to eq({ role: "user", content: "Hello" })
    end
  end

  describe ".assistant_text" do
    it "creates an assistant message with text content" do
      message = described_class.assistant_text("Hi there!")

      expect(message.role).to eq("assistant")
      expect(message.content).to eq("Hi there!")
    end

    it "converts to hash for API" do
      message = described_class.assistant_text("Response")

      expect(message.to_h).to eq({ role: "assistant", content: "Response" })
    end
  end

  describe ".system" do
    it "creates a system message" do
      message = described_class.system("You are helpful")

      expect(message.role).to eq("system")
      expect(message.content).to eq("You are helpful")
    end
  end

  describe ".user_with_images" do
    it "creates a user message with text and a single image" do
      message = described_class.user_with_images(
        "What's in this image?",
        "https://example.com/image.jpg"
      )

      expect(message.role).to eq("user")
      expect(message.content).to be_an(Array)
      expect(message.content.length).to eq(2)

      text_part = message.content.find { |c| c[:type] == "text" }
      image_part = message.content.find { |c| c[:type] == "image_url" }

      expect(text_part[:text]).to eq("What's in this image?")
      expect(image_part[:image_url][:url]).to eq("https://example.com/image.jpg")
      expect(image_part[:image_url][:detail]).to eq("auto")
    end

    it "creates a user message with multiple images" do
      message = described_class.user_with_images(
        "Compare these images",
        ["https://example.com/a.jpg", "https://example.com/b.jpg"]
      )

      expect(message.content.length).to eq(3) # 1 text + 2 images
      image_parts = message.content.select { |c| c[:type] == "image_url" }
      expect(image_parts.length).to eq(2)
    end

    it "respects the detail parameter" do
      message = described_class.user_with_images(
        "Analyze in detail",
        "https://example.com/image.jpg",
        detail: "high"
      )

      image_part = message.content.find { |c| c[:type] == "image_url" }
      expect(image_part[:image_url][:detail]).to eq("high")
    end
  end

  describe ".user_image" do
    it "creates a message with just an image" do
      message = described_class.user_image("https://example.com/image.jpg")

      expect(message.role).to eq("user")
      expect(message.content).to be_an(Array)
      expect(message.content.length).to eq(1)
      expect(message.content.first[:type]).to eq("image_url")
    end

    it "includes text when provided" do
      message = described_class.user_image(
        "https://example.com/image.jpg",
        text: "Describe this"
      )

      expect(message.content.length).to eq(2)
      text_part = message.content.find { |c| c[:type] == "text" }
      expect(text_part[:text]).to eq("Describe this")
    end
  end

  describe "#to_h / #to_hash" do
    it "returns a hash representation" do
      message = described_class.user_text("Test")

      expect(message.to_h).to be_a(Hash)
      expect(message.to_hash).to eq(message.to_h)
    end
  end
end
