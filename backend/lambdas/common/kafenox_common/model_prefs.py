"""User-selectable Bedrock model choices.

The app's Settings screen lets the user pick Claude Haiku or Claude Sonnet
per feature (scan extraction, Ask AI, flavor categorization). The client
sends the short choice name; Lambdas map it to a concrete inference-profile
id via env vars so the actual model versions stay a deploy-time concern.
"""

import os

VALID_MODEL_CHOICES = ("haiku", "sonnet")

_CHOICE_ENV_VARS = {
    "haiku": "BEDROCK_HAIKU_MODEL_ID",
    "sonnet": "BEDROCK_SONNET_MODEL_ID",
}


def resolve_model_id(choice: str | None, default: str) -> str:
    """Map a user's model choice to an inference-profile id, falling back to
    the feature's configured default for missing/unknown choices."""
    env_var = _CHOICE_ENV_VARS.get(choice or "")
    if env_var and os.environ.get(env_var):
        return os.environ[env_var]
    return default
