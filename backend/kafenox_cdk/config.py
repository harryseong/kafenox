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
    # Global cross-region inference profile for Claude -- the profile *id*, not
    # the full ARN: Bedrock's converse API accepts the id as modelId, and the
    # CDK IAM grant builds the inference-profile ARN from it (see
    # processing_stack.py). Verify the exact current profile id against
    # `aws bedrock list-inference-profiles` for the target account before
    # deploying -- AWS adds new profile ids as new Claude versions ship.
    # Validated ACTIVE in account 552566233886/ap-southeast-1 on 2026-06-28.
    bedrock_model_id = os.environ.get(
        "KAFENOX_BEDROCK_MODEL_ID",
        "global.anthropic.claude-sonnet-4-6",
    )
    return Config(
        env_name=env_name,
        account=account,
        region=region,
        bedrock_model_id=bedrock_model_id,
    )
