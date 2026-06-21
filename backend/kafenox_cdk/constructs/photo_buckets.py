from aws_cdk import Duration, RemovalPolicy
from aws_cdk import aws_s3 as s3
from constructs import Construct


class PhotoBuckets(Construct):
    """Raw + processed (720p) coffee bag photo buckets.

    The raw bucket has EventBridge notifications enabled so S3 ObjectCreated
    events can trigger the extraction Step Functions state machine without a
    direct S3->Lambda wiring.
    """

    def __init__(self, scope: Construct, construct_id: str, *, env_name: str) -> None:
        super().__init__(scope, construct_id)

        self.raw_bucket = s3.Bucket(
            self,
            "RawBucket",
            bucket_name=None,  # let CDK generate a unique name
            event_bridge_enabled=True,
            cors=[
                s3.CorsRule(
                    allowed_methods=[s3.HttpMethods.PUT],
                    allowed_origins=["*"],
                    allowed_headers=["*"],
                )
            ],
            lifecycle_rules=[
                s3.LifecycleRule(
                    id="ExpireIncompleteUploads",
                    abort_incomplete_multipart_upload_after=Duration.days(1),
                )
            ],
            removal_policy=RemovalPolicy.RETAIN,
            auto_delete_objects=False,
        )

        self.processed_bucket = s3.Bucket(
            self,
            "ProcessedBucket",
            bucket_name=None,
            removal_policy=RemovalPolicy.RETAIN,
            auto_delete_objects=False,
        )
