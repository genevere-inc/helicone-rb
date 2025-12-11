# frozen_string_literal: true

require "logger"

module Helicone
  URI_BASE = "https://ai-gateway.helicone.ai/v1"

  class Configuration
    attr_accessor :logger, :default_model

    # Initialize configuration with defaults
    #
    # @return [Configuration]
    def initialize
      @default_model = "gpt-4o"
      @logger = Logger.new($stdout, level: Logger::INFO)
    end
  end

  class << self
    attr_writer :configuration

    # Get the current configuration
    #
    # @return [Configuration]
    def configuration
      @configuration ||= Configuration.new
    end

    # Configure the gem
    #
    # @yield [Configuration] configuration object
    # @return [void]
    def configure
      yield(configuration)
    end

    # Reset configuration to defaults
    #
    # @return [Configuration]
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
