# frozen_string_literal: true

module Helicone
  class ToolCall
    attr_reader :id, :name, :arguments

    # Initialize a tool call
    #
    # @param id [String] The unique ID for this tool call
    # @param name [String] The name of the function to call
    # @param arguments [String, Hash, nil] Arguments (JSON string or Hash)
    def initialize(id:, name:, arguments:)
      @id = id
      @name = name
      @arguments = if arguments.nil?
        {}
      elsif arguments.is_a?(String)
        deep_symbolize_keys(JSON.parse(arguments))
      else
        deep_symbolize_keys(arguments)
      end
    end

    # Parse tool calls from an API response (expects symbolized keys)
    #
    # @param response [Helicone::Response, Array<Hash>] Response object or tool_calls array
    # @return [Array<Helicone::ToolCall>]
    def self.from_response(response)
      tool_calls = response.is_a?(Response) ? response.tool_calls : response
      return [] if tool_calls.nil?

      tool_calls.map do |tc|
        new(
          id: tc[:id],
          name: tc.dig(:function, :name),
          arguments: tc.dig(:function, :arguments)
        )
      end
    end

    # Build a tool result message to send back to the API
    #
    # @param tool_call_id [String] The ID of the tool call being responded to
    # @param content [String, Hash] The tool result
    # @return [Helicone::Message]
    def self.result(tool_call_id:, content:)
      Message.tool_result(tool_call_id: tool_call_id, content: content)
    end

    # Convert to hash for inspection
    #
    # @return [Hash]
    def to_h
      {
        id: id,
        name: name,
        arguments: arguments
      }
    end

    # Access arguments like a hash (supports both string and symbol keys)
    #
    # @param key [String, Symbol] Key to access
    # @return [Object, nil]
    def [](key)
      arguments[key.to_sym]
    end

    # Dig into nested data in arguments
    #
    # @param keys [Array<String, Symbol>] Keys to dig through
    # @return [Object, nil]
    def dig(*keys)
      arguments.dig(*keys.map(&:to_sym))
    end

    private

    # Recursively symbolize keys in a hash
    #
    # @param obj [Object] Object to process
    # @return [Object] Object with symbolized keys
    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = deep_symbolize_keys(value)
        end
      when Array
        obj.map { |item| deep_symbolize_keys(item) }
      else
        obj
      end
    end
  end
end
