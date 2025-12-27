# frozen_string_literal: true

module Helicone
  class Message
    attr_reader :role, :content, :tool_call_id

    # Initialize a message
    #
    # @param role [String, Symbol] Message role ("user", "assistant", "system", "tool")
    # @param content [String, Array<Hash>] Message content (text or structured content)
    # @param tool_call_id [String] Tool call ID (required for tool result messages)
    def initialize(role:, content:, tool_call_id: nil)
      @role = role.to_s
      @content = content
      @tool_call_id = tool_call_id
    end

    # Build a user message with text
    #
    # @param text [String] The text content
    # @return [Helicone::Message]
    def self.user_text(text)
      new(role: "user", content: text)
    end

    # Build an assistant message with text
    #
    # @param text [String] The text content
    # @return [Helicone::Message]
    def self.assistant_text(text)
      new(role: "assistant", content: text)
    end

    # Build a system message
    #
    # @param text [String] The system prompt text
    # @return [Helicone::Message]
    def self.system(text)
      new(role: "system", content: text)
    end

    # Build a user message with text and images
    #
    # @param text [String] The text content
    # @param images [Array<String>, String] Image URL(s) or base64 data URI(s)
    # @param detail [String] Image detail level: "auto", "low", or "high"
    # @return [Helicone::Message]
    def self.user_with_images(text, images, detail: "auto")
      content = []
      content << { type: "text", text: text }

      Array(images).each do |image|
        content << {
          type: "image_url",
          image_url: {
            url: image,
            detail: detail
          }
        }
      end

      new(role: "user", content: content)
    end

    # Build a user message with a single image
    #
    # @param image_url [String] URL or base64 data URI of the image
    # @param text [String] Optional text content to include
    # @param detail [String] Image detail level: "auto", "low", or "high"
    # @return [Helicone::Message]
    def self.user_image(image_url, text: nil, detail: "auto")
      content = []
      content << { type: "text", text: text } if text
      content << {
        type: "image_url",
        image_url: {
          url: image_url,
          detail: detail
        }
      }

      new(role: "user", content: content)
    end

    # Build a tool result message
    #
    # @param tool_call_id [String] The ID of the tool call being responded to
    # @param content [String, Hash] The tool result (will be JSON-encoded if not a string)
    # @return [Helicone::Message]
    def self.tool_result(tool_call_id:, content:)
      content_str = content.is_a?(String) ? content : content.to_json
      new(role: "tool", content: content_str, tool_call_id: tool_call_id)
    end

    # Build an assistant message that contains tool_calls (from API response)
    # This stores the raw message so it can be returned as-is for the API
    # Note: We transform null content to empty string as the API rejects null
    #
    # @param raw_message [Hash] The raw message hash from the API response
    # @return [Helicone::Message]
    def self.assistant_with_tool_calls(raw_message)
      msg = new(role: "assistant", content: nil)
      # Deep duplicate the message to avoid mutating the original
      sanitized_message = deep_dup(raw_message)
      if sanitized_message[:content].nil?
        sanitized_message[:content] = ""
      end
      msg.instance_variable_set(:@raw_message, sanitized_message)
      msg
    end

    # Convert to hash for API request
    #
    # @return [Hash] Message formatted for the API
    def to_h
      if @raw_message
        # Return the full raw message to preserve extra_content (thought signatures)
        # and any other provider-specific fields (e.g., Gemini 3 requires thought_signature)
        @raw_message
      else
        hash = { role: role, content: content }
        hash[:tool_call_id] = tool_call_id if tool_call_id
        hash
      end
    end

    # Check if this message has tool calls
    #
    # @return [Boolean]
    def tool_calls?
      tool_calls = @raw_message&.dig(:tool_calls)
      !tool_calls.nil? && !tool_calls.empty?
    end

    alias_method :to_hash, :to_h

    # Deep duplicate a hash/array structure
    #
    # @param obj [Object] Object to duplicate
    # @return [Object] Deep copy of the object
    def self.deep_dup(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array
        obj.map { |v| deep_dup(v) }
      else
        obj.respond_to?(:dup) ? obj.dup : obj
      end
    end
  end
end
