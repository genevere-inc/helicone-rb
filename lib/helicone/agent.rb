# frozen_string_literal: true

module Helicone
  class Agent
    MAX_ITERATIONS = 10

    attr_reader :client, :tools, :messages, :context, :model

    # Create an agent with tools and optional context
    #
    # @param client [Helicone::Client] Optional client (creates new one if not provided)
    # @param session [Hash] Session config for Helicone tracking (id:, name:) - creates client if no client provided
    # @param user [Hash] User config for Helicone tracking (id:, name:) - sets Helicone-User-Id header
    # @param tools [Array<Class>] Array of Tool subclasses
    # @param context [Object] Context object passed to tool#initialize
    # @param system_prompt [String] System prompt
    # @param messages [Array<Helicone::Message>] Initial messages (for continuing conversations)
    # @param model [String] Model to use (defaults to Helicone.configuration.default_model)
    def initialize(client: nil, session: nil, user: nil, tools: [], context: nil, system_prompt: nil, messages: [], model: nil)
      @client = client || build_client(session: session, user: user)
      @tools = tools
      @context = context
      @model = model
      @messages = messages.dup

      # Add system message at the start if provided and not already present
      if system_prompt && @messages.none? { |m| m.respond_to?(:role) && m.role == "system" }
        @messages.unshift(Message.system(system_prompt))
      end
    end

    # Run the agent with an optional prompt, executing tools until done
    #
    # @param prompt [String, nil] User prompt to add (nil to use existing messages)
    # @param max_iterations [Integer] Maximum tool execution loops
    # @return [AgentResult]
    def run(prompt = nil, max_iterations: MAX_ITERATIONS)
      @messages << Message.user_text(prompt) if prompt

      iterations = 0
      while iterations < max_iterations
        response = call_llm

        tool_calls = response.tool_calls
        if tool_calls && !tool_calls.empty?
          # Add assistant message with tool calls to conversation
          @messages << Message.assistant_with_tool_calls(response.message)

          # Execute each tool and add results
          response.tool_calls.each do |tc|
            tool_call = ToolCall.from_response([tc]).first
            result = execute_tool(tool_call)
            @messages << Message.tool_result(
              tool_call_id: tool_call.id,
              content: result
            )
          end

          iterations += 1
        else
          # No tool calls - we're done
          return AgentResult.new(
            content: response.content,
            messages: @messages,
            iterations: iterations,
            response: response
          )
        end
      end

      # Max iterations reached - make one final call without tools to get a response
      final_response = @client.chat(messages: @messages, model: @model)

      AgentResult.new(
        content: final_response.content,
        messages: @messages,
        iterations: iterations,
        response: final_response,
        max_iterations_reached: true
      )
    end

    # Continue the conversation with a new prompt
    #
    # @param prompt [String] User prompt to continue with
    # @param max_iterations [Integer] Maximum tool execution loops
    # @return [AgentResult]
    def continue(prompt, max_iterations: MAX_ITERATIONS)
      run(prompt, max_iterations: max_iterations)
    end

    private

    def logger
      Helicone.configuration.logger
    end

    def call_llm
      @client.chat(
        messages: @messages,
        model: @model,
        tools: tools_for_api,
        tool_choice: "auto"
      )
    end

    def tools_for_api
      return nil if @tools.empty?
      @tools.map(&:to_openai_tool)
    end

    def execute_tool(tool_call)
      tool = find_tool(tool_call.name)

      unless tool
        logger.warn("[Helicone::Agent] Unknown tool: #{tool_call.name}")
        return { error: "Unknown tool: #{tool_call.name}" }
      end

      logger.info("[Helicone::Agent] Executing tool: #{tool_call.name} with #{tool_call.arguments}")

      # Support both tool classes and tool instances
      tool_instance = tool.is_a?(Class) ? tool.new(@context) : tool
      result = tool_instance.execute(**tool_call.arguments)

      result_preview = result.inspect
      result_preview = result_preview[0, 197] + "..." if result_preview.length > 200
      logger.info("[Helicone::Agent] Tool result: #{result_preview}")
      result
    rescue => e
      logger.error("[Helicone::Agent] Tool execution error: #{e.message}")
      logger.error(e.backtrace.first(5).join("\n"))
      { error: e.message }
    end

    def find_tool(name)
      @tools.find { |t| t.function_name == name }
    end

    def build_client(session:, user:)
      return Client.new unless session || user

      Client.new(
        session_id: session&.dig(:id),
        session_name: session&.dig(:name),
        account_id: user&.dig(:id),
        account_name: user&.dig(:name)
      )
    end
  end
end
