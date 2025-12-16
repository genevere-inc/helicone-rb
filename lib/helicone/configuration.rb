# frozen_string_literal: true

require "logger"

module Helicone
  DEFAULT_BASE_URL = "https://ai-gateway.helicone.ai/v1"

  class Configuration
    attr_accessor :logger, :default_model, :base_url

    # Initialize configuration with defaults
    #
    # @return [Configuration]
    def initialize
      @default_model = "gpt-4o"
      @base_url = DEFAULT_BASE_URL
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
