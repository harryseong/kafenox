import aws_cdk as cdk
from aws_cdk.assertions import Template

from kafenox_cdk.stacks.storage_stack import StorageStack


def _synth():
    app = cdk.App()
    stack = StorageStack(app, "TestStorage", env_name="test")
    return Template.from_stack(stack)


def test_creates_dynamodb_table_with_photo_id_key():
    template = _synth()
    template.has_resource_properties(
        "AWS::DynamoDB::Table",
        {
            "TableName": "kafenox-coffees-test",
            "KeySchema": [{"AttributeName": "photoId", "KeyType": "HASH"}],
            "BillingMode": "PAY_PER_REQUEST",
        },
    )


def test_creates_two_s3_buckets():
    template = _synth()
    template.resource_count_is("AWS::S3::Bucket", 2)


def test_raw_bucket_has_eventbridge_enabled():
    template = _synth()
    template.has_resource_properties(
        "Custom::S3BucketNotifications",
        {"NotificationConfiguration": {"EventBridgeConfiguration": {}}},
    )
