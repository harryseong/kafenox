#!/usr/bin/env python3
import aws_cdk as cdk

from kafenox_cdk.config import get_config
from kafenox_cdk.stacks.api_stack import ApiStack
from kafenox_cdk.stacks.processing_stack import ProcessingStack
from kafenox_cdk.stacks.storage_stack import StorageStack

config = get_config()
env = cdk.Environment(account=config.account, region=config.region)

app = cdk.App()

storage = StorageStack(
    app,
    f"KafenoxStorage-{config.env_name}",
    env_name=config.env_name,
    env=env,
)

processing = ProcessingStack(
    app,
    f"KafenoxProcessing-{config.env_name}",
    env_name=config.env_name,
    bedrock_model_id=config.bedrock_model_id,
    raw_bucket=storage.raw_bucket,
    processed_bucket=storage.processed_bucket,
    coffee_table=storage.coffee_table,
    env=env,
)

api = ApiStack(
    app,
    f"KafenoxApi-{config.env_name}",
    env_name=config.env_name,
    coffee_table=storage.coffee_table,
    raw_bucket=storage.raw_bucket,
    processed_bucket=storage.processed_bucket,
    env=env,
)

app.synth()
