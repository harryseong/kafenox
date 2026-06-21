from aws_cdk import Stack
from constructs import Construct

from kafenox_cdk.constructs.coffee_table import CoffeeTable
from kafenox_cdk.constructs.photo_buckets import PhotoBuckets


class StorageStack(Stack):
    """S3 buckets + DynamoDB table. Near-zero churn data plane, isolated from
    the Lambda/pipeline code and API routes so iterating on those never risks
    a resource replacement here."""

    def __init__(self, scope: Construct, construct_id: str, *, env_name: str, **kwargs) -> None:
        super().__init__(scope, construct_id, **kwargs)

        buckets = PhotoBuckets(self, "PhotoBuckets", env_name=env_name)
        self.raw_bucket = buckets.raw_bucket
        self.processed_bucket = buckets.processed_bucket

        coffee_table = CoffeeTable(self, "CoffeeTable", env_name=env_name)
        self.coffee_table = coffee_table.table
