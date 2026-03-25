import os

from strands import Agent, tool
from strands.models.bedrock import BedrockModel


def _bedrock_model() -> BedrockModel:
    return BedrockModel(
        model_id=os.environ.get(
            "BEDROCK_MODEL_ID", "us.anthropic.claude-opus-4-6-20251101"
        ),
        region_name=os.environ.get("AWS_REGION", "us-east-1"),
    )


# ---------------------------------------------------------------------------
# Sub agent
# ---------------------------------------------------------------------------

sub_agent = Agent(
    model=_bedrock_model(),
    system_prompt="You are a concise research sub-agent. Answer questions with brief, factual responses.",
)


@tool
def sub_agent_tool(query: str) -> str:
    """Delegate a research query to the sub agent and return its response.

    Args:
        query: The research question or task to send to the sub agent.
    """
    response = sub_agent(query)
    return str(response)


# ---------------------------------------------------------------------------
# Main agent
# ---------------------------------------------------------------------------

main_agent = Agent(
    model=_bedrock_model(),
    system_prompt=(
        "You are a helpful assistant. "
        "For research questions or tasks that benefit from delegation, "
        "use the sub_agent_tool."
    ),
    tools=[sub_agent_tool],
)


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    print("Strands multi-agent ready. Type 'quit' to exit.\n")
    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in {"quit", "exit", "q"}:
            break
        if not user_input:
            continue
        response = main_agent(user_input)
        print(f"Agent: {response}\n")


if __name__ == "__main__":
    main()
