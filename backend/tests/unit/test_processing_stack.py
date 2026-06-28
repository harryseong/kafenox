import aws_cdk as cdk
from aws_cdk.assertions import Match, Template

from kafenox_cdk.stacks.processing_stack import ProcessingStack
from kafenox_cdk.stacks.storage_stack import StorageStack


def _synth():
    app = cdk.App()
    storage = StorageStack(app, "TestStorage", env_name="test")
    stack = ProcessingStack(
        app,
        "TestProcessing",
        env_name="test",
        bedrock_model_id="global.anthropic.claude-sonnet-4-6",
        raw_bucket=storage.raw_bucket,
        processed_bucket=storage.processed_bucket,
        coffee_table=storage.coffee_table,
    )
    return Template.from_stack(stack)


def test_creates_express_state_machine():
    template = _synth()
    template.has_resource_properties(
        "AWS::StepFunctions::StateMachine", {"StateMachineType": "EXPRESS"}
    )


def test_creates_three_pipeline_lambdas():
    template = _synth()
    template.resource_count_is("AWS::Lambda::Function", 3)


def test_extract_lambda_has_bedrock_invoke_permission():
    template = _synth()
    template.has_resource_properties(
        "AWS::IAM::Policy",
        {
            "PolicyDocument": {
                "Statement": Match.array_with(
                    [Match.object_like({"Action": "bedrock:InvokeModel", "Effect": "Allow"})]
                )
            }
        },
    )


def test_creates_eventbridge_rule_on_raw_bucket():
    template = _synth()
    template.has_resource_properties(
        "AWS::Events::Rule",
        {"EventPattern": {"source": ["aws.s3"], "detail-type": ["Object Created"]}},
    )
