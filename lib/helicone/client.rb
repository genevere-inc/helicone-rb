# frozen_string_literal: true

module Helicone
  class Client
    attr_reader :client

    # Initialize with optional session/account context for Helicone tracking
    #
    # @param session_id [String, Integer] Conversation/session ID for Helicone grouping
    # @param session_name [String] Human-readable session name
    # @param account_id [String, Integer] Account ID for cost tracking per account
    # @param account_name [String] Human-readable account name
    def initialize(session_id: nil, session_name: nil, account_id: nil, account_name: nil)
      @client = OpenAI::Client.new(
        access_token: ENV["HELICONE_API_KEY"],
        uri_base: Helicone.configuration.base_url
      )

      # Add Helicone session headers if provided
      if session_id
        @client.add_headers(
          "Helicone-Session-Id" => session_id.to_s,
          "Helicone-Session-Name" => session_name || "Conversation ##{session_id}"
        )
      end

      # Add Helicone account/user headers if provided
      if account_id
        @client.add_headers(
          "Helicone-User-Id" => account_id.to_s,
          "Helicone-Property-Account" => account_name || account_id.to_s
        )
      end
    end

    # Send a chat completion request
    #
    # @param messages [Array<Helicone::Message, Hash>] Array of messages (Message objects or hashes)
    # @param model [String] Model ID to use for completion
    # @param tools [Array<Hash>] OpenAI tool definitions for function calling
    # @param tool_choice [String, Hash] Tool choice strategy ("auto", "none", or specific tool)
    # @param options [Hash] Additional options passed to the API
    # @return [Helicone::Response] Wrapped API response
    def chat(messages:, model: nil, tools: nil, tool_choice: nil, **options)
      model ||= Helicone.configuration.default_model

      # Convert Message objects to hashes if needed
      message_hashes = messages.map { |m| m.respond_to?(:to_h) ? m.to_h : m }

      params = {
        model: model,
        messages: message_hashes,
        **options
      }

      # Add tools if provided
      params[:tools] = tools if tools && !tools.empty?
      params[:tool_choice] = tool_choice if tool_choice

      raw_response = @client.chat(parameters: params)

      Response.new(deep_symbolize_keys(raw_response))
    end

    # Convenience method for simple single-turn requests
    #
    # @param prompt [String] User prompt text
    # @param model [String] Model ID to use for completion
    # @param system_prompt [String] Optional system prompt
    # @param options [Hash] Additional options passed to chat
    # @return [String] The text content of the response
    def ask(prompt, model: nil, system_prompt: nil, **options)
      messages = []
      messages << Message.system(system_prompt) if system_prompt
      messages << Message.user_text(prompt)

      response = chat(messages: messages, model: model, **options)
      response.content
    end

    # Ask with an image
    #
    # @param prompt [String] User prompt text
    # @param image_url [String] URL or base64 data URI of the image
    # @param model [String] Model ID to use for completion
    # @param system_prompt [String] Optional system prompt
    # @param detail [String] Image detail level: "auto", "low", or "high"
    # @param options [Hash] Additional options passed to chat
    # @return [String] The text content of the response
    def ask_with_image(prompt, image_url, model: nil, system_prompt: nil, detail: "auto", **options)
      messages = []
      messages << Message.system(system_prompt) if system_prompt
      messages << Message.user_with_images(prompt, image_url, detail: detail)

      response = chat(messages: messages, model: model, **options)
      response.content
    end

    # Add additional headers at any time
    #
    # @param headers [Hash] Headers to add to subsequent requests
    # @return [void]
    def add_headers(headers)
      @client.add_headers(headers)
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
