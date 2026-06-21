import aws_cdk as cdk
from aws_cdk.assertions import Template

from kafenox_cdk.stacks.api_stack import ApiStack
from kafenox_cdk.stacks.storage_stack import StorageStack


def _synth():
    app = cdk.App()
    storage = StorageStack(app, "TestStorage", env_name="test")
    stack = ApiStack(
        app,
        "TestApi",
        env_name="test",
        coffee_table=storage.coffee_table,
        raw_bucket=storage.raw_bucket,
        processed_bucket=storage.processed_bucket,
    )
    return Template.from_stack(stack)


def test_creates_rest_api():
    template = _synth()
    template.resource_count_is("AWS::ApiGateway::RestApi", 1)


def test_requires_api_key_by_default():
    template = _synth()
    template.has_resource_properties("AWS::ApiGateway::Method", {"ApiKeyRequired": True})


def test_creates_api_key_and_usage_plan():
    template = _synth()
    template.resource_count_is("AWS::ApiGateway::ApiKey", 1)
    template.resource_count_is("AWS::ApiGateway::UsagePlan", 1)


def test_creates_six_crud_lambdas():
    template = _synth()
    template.resource_count_is("AWS::Lambda::Function", 6)
