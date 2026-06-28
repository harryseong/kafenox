import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    env_name: str
    account: str | None
    region: str
    bedrock_model_id: str


def get_config() -> Config:
    env_name = os.environ.get("KAFENOX_ENV", "dev")
    region = os.environ.get("CDK_DEFAULT_REGION", "ap-southeast-1")
    account = os.environ.get("CDK_DEFAULT_ACCOUNT")
    # APAC cross-region inference profile for Claude. Verify the exact current
    # profile id against the Bedrock console's "Cross-region inference" model
    # list in ap-southeast-1 before deploying -- AWS adds new profile ids as
    # new Claude versions ship.
    bedrock_model_id = os.environ.get(
        "KAFENOX_BEDROCK_MODEL_ID",
        "apac.anthropic.claude-sonnet-4-20250514-v1:0",
    )
    return Config(
        env_name=env_name,
        account=account,
        region=region,
        bedrock_model_id=bedrock_model_id,
    )
