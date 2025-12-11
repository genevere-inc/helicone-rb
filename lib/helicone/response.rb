# frozen_string_literal: true

module Helicone
  class Response
    attr_reader :raw

    # Initialize a response wrapper
    #
    # @param raw [Hash] The raw API response (symbolized keys)
    def initialize(raw)
      @raw = raw
    end

    # The assistant's text response content
    #
    # @return [String, nil]
    def content
      message&.dig(:content)
    end

    # The full message object from the first choice
    #
    # @return [Hash, nil]
    def message
      raw.dig(:choices, 0, :message)
    end

    # The role of the response (usually "assistant")
    #
    # @return [String, nil]
    def role
      message&.dig(:role)
    end

    # All choices returned (for n > 1)
    #
    # @return [Array<Hash>]
    def choices
      raw[:choices] || []
    end

    # The finish reason: "stop", "length", "tool_calls", etc.
    #
    # @return [String, nil]
    def finish_reason
      raw.dig(:choices, 0, :finish_reason)
    end

    # Usage statistics
    #
    # @return [Hash, nil]
    def usage
      raw[:usage]
    end

    # Number of tokens in the prompt
    #
    # @return [Integer, nil]
    def prompt_tokens
      usage&.dig(:prompt_tokens)
    end

    # Number of tokens in the completion
    #
    # @return [Integer, nil]
    def completion_tokens
      usage&.dig(:completion_tokens)
    end

    # Total tokens used (prompt + completion)
    #
    # @return [Integer, nil]
    def total_tokens
      usage&.dig(:total_tokens)
    end

    # Model used for the completion
    #
    # @return [String, nil]
    def model
      raw[:model]
    end

    # Unique ID for this completion
    #
    # @return [String, nil]
    def id
      raw[:id]
    end

    # Whether the response completed successfully
    #
    # @return [Boolean]
    def success?
      (content && !content.empty?) || finish_reason == "stop"
    end

    # Tool calls if any were made
    #
    # @return [Array<Hash>, nil]
    def tool_calls
      message&.dig(:tool_calls)
    end

    # Convert response content back to a Message for conversation history
    #
    # @return [Helicone::Message]
    def to_message
      Message.new(role: role, content: content)
    end

    # Delegate hash-like access to raw response
    #
    # @param key [Symbol] Key to access
    # @return [Object, nil]
    def [](key)
      raw[key]
    end

    # Dig into nested data in raw response
    #
    # @param keys [Array<Symbol>] Keys to dig through
    # @return [Object, nil]
    def dig(*keys)
      raw.dig(*keys)
    end
  end
end
