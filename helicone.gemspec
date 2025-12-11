# frozen_string_literal: true

require_relative "lib/helicone/version"

Gem::Specification.new do |spec|
  spec.name = "helicone-rb"
  spec.version = Helicone::VERSION
  spec.authors = ["Genevere"]
  spec.email = ["hello@genevere.com"]

  spec.summary = "Ruby client for Helicone AI Gateway with agentic tool support"
  spec.description = "A Ruby client that wraps the OpenAI API through the Helicone AI Gateway, " \
                     "providing session tracking, cost attribution, and an agentic framework " \
                     "for building AI applications with tool/function calling."
  spec.homepage = "https://github.com/genevere-inc/helicone-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/genevere-inc/helicone-rb"
  spec.metadata["changelog_uri"] = "https://github.com/genevere-inc/helicone-rb/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ruby-openai", "~> 7.0"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
end
