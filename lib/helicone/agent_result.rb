# frozen_string_literal: true

module Helicone
  class AgentResult
    attr_reader :content, :messages, :iterations, :response

    # Initialize an agent result
    #
    # @param content [String] Final text response from the agent
    # @param messages [Array<Helicone::Message>] Full conversation history
    # @param iterations [Integer] Number of tool execution loops
    # @param response [Helicone::Response] The final API response
    # @param max_iterations_reached [Boolean] Whether the agent hit the iteration limit
    def initialize(content:, messages:, iterations:, response: nil, max_iterations_reached: false)
      @content = content
      @messages = messages
      @iterations = iterations
      @response = response
      @max_iterations_reached = max_iterations_reached
    end

    # Check if the agent hit the iteration limit
    #
    # @return [Boolean]
    def max_iterations_reached?
      @max_iterations_reached
    end

    # Check if the agent completed successfully
    #
    # @return [Boolean]
    def success?
      !@max_iterations_reached && !@content.nil? && !@content.empty?
    end

    # Count of tool calls executed during the run
    #
    # @return [Integer]
    def tool_calls_made
      @messages.count { |m| m.respond_to?(:role) && m.role == "tool" }
    end

    # Get all tool result messages from the conversation
    #
    # @return [Array<Helicone::Message>] Messages with role "tool"
    def tool_results
      @messages.select { |m| m.respond_to?(:role) && m.role == "tool" }
    end
  end
end
