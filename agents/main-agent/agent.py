from strands import Agent
from strands.models import BedrockModel

# bedrock_model_id="anthropic.claude-3-7-sonnet-20250219-v1:0"
bedrock_model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0"

# Create a Bedrock model instance
bedrock_model = BedrockModel(
    model_id=bedrock_model_id,
    temperature=0.3,
    top_p=0.8,
)

# Create an agent using the BedrockModel instance
agent = Agent(model=bedrock_model)

# Use the agent
response = agent("Tell me about Amazon Bedrock.")
