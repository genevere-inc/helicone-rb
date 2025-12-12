require 'helicone'


  # ============================================
  # Configuration
  # ============================================

  Helicone.configure do |config|
    config.default_model = "gpt-4o-mini"
    config.logger = Logger.new(STDOUT, level: Logger::DEBUG)
  end

if ENV["HELICONE_API_KEY"].nil?
  fail StandardError, "HELICONE_API_KEY is not set"
end

# ============================================
# Basic Usage - Simple Questions
# ============================================

client = Helicone::Client.new
client.ask("What is 2 + 2?")
# => "2 + 2 equals 4."

# With a system prompt
client.ask("Tell me a joke", system_prompt: "You are a comedian")

# With a specific model
client.ask("Explain Ruby blocks", model: "gpt-4o-mini")

# ============================================
# With Session/Account Tracking
# ============================================

client = Helicone::Client.new(
session_id: "conv_123",
session_name: "Customer Support Chat",
account_id: "user_456",
account_name: "Acme Corp"
)

client.ask("Help me with my order")

# ============================================
# Multi-turn Conversation
# ============================================

client = Helicone::Client.new
messages = [
Helicone::Message.system("You are a helpful assistant"),
Helicone::Message.user_text("My name is Alice")
]

response = client.chat(messages: messages)
puts response.content
# => "Nice to meet you, Alice!"

messages << response.to_message
messages << Helicone::Message.user_text("What's my name?")

response = client.chat(messages: messages)
puts response.content
# => "Your name is Alice."

# ============================================
# Vision - Ask About Images
# ============================================

client.ask_with_image(
"What's in this image?",
"https://example.com/photo.jpg",
detail: "high"
)

# ============================================
# Using the Agent with Tools
# ============================================

# Define a tool
class WeatherTool < Helicone::Tool
description "Get current weather for a location"

parameters(
    type: "object",
    properties: {
    location: { type: "string", description: "City name" }
    },
    required: ["location"]
)

def execute(location:)
    # In reality, call a weather API
    { temperature: 72, conditions: "sunny", location: location }
end
end

class CalculatorTool < Helicone::Tool
description "Evaluate a math expression"

parameters(
    type: "object",
    properties: {
    expression: { type: "string", description: "Math expression like '2 + 2'" }
    },
    required: ["expression"]
)

def execute(expression:)
    { result: eval(expression) }
rescue => e
    { error: e.message }
end
end

# Run the agent
agent = Helicone::Agent.new(
tools: [WeatherTool, CalculatorTool],
system_prompt: "You are a helpful assistant with access to weather and calculator tools."
)

result = agent.run("What's the weather in San Francisco?")
puts result.content
puts "Iterations: #{result.iterations}"
puts "Tool calls made: #{result.tool_calls_made}"

# Continue the conversation
result = agent.continue("What about New York?")
puts result.content

# ============================================
# Agent with Context
# ============================================

# Context is passed to tool instances
class DatabaseTool < Helicone::Tool
description "Query the database"

parameters(
    type: "object",
    properties: {
    query: { type: "string" }
    },
    required: ["query"]
)

def execute(query:)
    # Access context passed from agent
    user_id = context[:user_id]
    { results: "Data for user #{user_id}: #{query}" }
end
end

agent = Helicone::Agent.new(
tools: [DatabaseTool],
context: { user_id: 123, db: some_db_connection }
)

result = agent.run("Find my recent orders")

# ============================================
# Inspecting Responses
# ============================================

client = Helicone::Client.new
response = client.chat(
messages: [Helicone::Message.user_text("Hello")]
)

response.content          # => "Hello! How can I help?"
response.role             # => "assistant"
response.model            # => "gpt-4o"
response.finish_reason    # => "stop"
response.prompt_tokens    # => 10
response.completion_tokens # => 15
response.total_tokens     # => 25
response.success?         # => true
response.raw              # => full raw response hash
