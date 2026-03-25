import os

from strands import Agent
from strands.models.bedrock import BedrockModel


def create_agent() -> Agent:
    """Create a Strands agent backed by Amazon Bedrock."""
    model = BedrockModel(
        model_id=os.environ.get(
            "BEDROCK_MODEL_ID", "us.anthropic.claude-opus-4-6-20251101"
        ),
        region_name=os.environ.get("AWS_REGION", "us-east-1"),
    )
    return Agent(
        model=model,
        system_prompt="You are a helpful assistant powered by Amazon Bedrock.",
    )


def main() -> None:
    agent = create_agent()
    print("Strands Bedrock agent ready. Type 'quit' to exit.\n")
    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in {"quit", "exit", "q"}:
            break
        if not user_input:
            continue
        response = agent(user_input)
        print(f"Agent: {response}\n")


if __name__ == "__main__":
    main()
