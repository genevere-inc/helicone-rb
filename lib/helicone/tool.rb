# frozen_string_literal: true

module Helicone
  class Tool
    class << self
      attr_reader :tool_description, :tool_parameters

      def inherited(subclass)
        super
        # Ensure subclasses get their own class instance variables
        subclass.instance_variable_set(:@tool_description, nil)
        subclass.instance_variable_set(:@tool_parameters, nil)
      end

      # Set the tool description
      #
      # @param text [String] Description of what this tool does
      # @return [void]
      def description(text)
        @tool_description = text.strip
      end

      # Set the tool parameters schema
      #
      # @param schema [Hash] JSON Schema for the tool parameters
      # @return [void]
      def parameters(schema)
        @tool_parameters = schema
      end

      # Get or set a custom tool name
      #
      # @param custom_name [String, nil] Custom name to set, or nil to get current name
      # @return [String] The tool name
      def tool_name(custom_name = nil)
        if custom_name
          @tool_name = custom_name
        else
          @tool_name || derive_function_name
        end
      end

      # Generate the function name from class name
      #
      # @return [String] The function name for API calls
      def function_name
        @tool_name || derive_function_name
      end

      # Generate OpenAI tool definition
      #
      # @return [Hash] Tool definition formatted for OpenAI API
      def to_openai_tool
        {
          type: "function",
          function: {
            name: function_name,
            description: tool_description,
            parameters: tool_parameters || { type: "object", properties: {}, required: [] }
          }
        }
      end

      private

      # Derive function name from class name without Rails dependencies
      # Converts "MyModule::SomeToolClass" to "some_tool_class" (without _tool suffix)
      #
      # @return [String]
      def derive_function_name
        # Get the class name without module prefix (like demodulize)
        class_name = name.to_s.split("::").last

        # Convert CamelCase to snake_case (like underscore)
        snake_case = class_name
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase

        # Remove _tool suffix if present
        snake_case.sub(/_tool$/, "")
      end
    end

    attr_reader :context

    # Initialize a tool instance
    #
    # @param context [Object] Context object passed from the agent
    def initialize(context = nil)
      @context = context
    end

    # Execute the tool with the given arguments
    #
    # @param args [Hash] Arguments parsed from the tool call
    # @return [Hash] Result to be returned to the LLM
    def execute(**args)
      raise NotImplementedError, "Subclasses must implement #execute"
    end

    # Delegate to class method for instances
    #
    # @return [Hash] Tool definition formatted for OpenAI API
    def to_openai_tool
      self.class.to_openai_tool
    end

    # Delegate to class method for instances
    #
    # @return [String] The function name
    def function_name
      self.class.function_name
    end
  end
end
