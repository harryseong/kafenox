from pathlib import Path

from aws_cdk import Duration, Stack
from aws_cdk import aws_dynamodb as dynamodb
from aws_cdk import aws_events as events
from aws_cdk import aws_events_targets as targets
from aws_cdk import aws_iam as iam
from aws_cdk import aws_lambda as lambda_
from aws_cdk import aws_s3 as s3
from aws_cdk.aws_lambda_python_alpha import PythonFunction, PythonLayerVersion
from constructs import Construct

from kafenox_cdk.constructs.extraction_pipeline import ExtractionPipeline

LAMBDAS_DIR = Path(__file__).parent.parent.parent / "lambdas"

POWERTOOLS_ENV = {"POWERTOOLS_SERVICE_NAME": "kafenox", "POWERTOOLS_LOG_LEVEL": "INFO"}


class ProcessingStack(Stack):
    """Step Functions pipeline + resize/extract/persist Lambdas. Iterated on
    often (prompt tuning, model swaps) -- isolated from StorageStack (data)
    and ApiStack (routes/auth) so changes here never touch either."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        env_name: str,
        bedrock_model_id: str,
        raw_bucket: s3.IBucket,
        processed_bucket: s3.IBucket,
        coffee_table: dynamodb.ITable,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        common_layer = PythonLayerVersion(
            self,
            "CommonLayer",
            entry=str(LAMBDAS_DIR / "common"),
            compatible_runtimes=[lambda_.Runtime.PYTHON_3_12],
            compatible_architectures=[lambda_.Architecture.ARM_64],
        )

        resize_fn = PythonFunction(
            self,
            "ResizeImageFn",
            entry=str(LAMBDAS_DIR / "resize_image"),
            runtime=lambda_.Runtime.PYTHON_3_12,
            architecture=lambda_.Architecture.ARM_64,
            index="handler.py",
            handler="handler",
            timeout=Duration.seconds(30),
            memory_size=512,
            tracing=lambda_.Tracing.ACTIVE,
            environment={
                "RAW_BUCKET_NAME": raw_bucket.bucket_name,
                "PROCESSED_BUCKET_NAME": processed_bucket.bucket_name,
                **POWERTOOLS_ENV,
            },
        )
        raw_bucket.grant_read(resize_fn)
        processed_bucket.grant_write(resize_fn)

        extract_fn = PythonFunction(
            self,
            "ExtractCoffeeDataFn",
            entry=str(LAMBDAS_DIR / "extract_coffee_data"),
            runtime=lambda_.Runtime.PYTHON_3_12,
            architecture=lambda_.Architecture.ARM_64,
            index="handler.py",
            handler="handler",
            timeout=Duration.seconds(60),
            memory_size=512,
            tracing=lambda_.Tracing.ACTIVE,
            environment={
                "PROCESSED_BUCKET_NAME": processed_bucket.bucket_name,
                "BEDROCK_MODEL_ID": bedrock_model_id,
                **POWERTOOLS_ENV,
            },
        )
        processed_bucket.grant_read(extract_fn)
        extract_fn.add_to_role_policy(
            iam.PolicyStatement(
                actions=["bedrock:InvokeModel"],
                resources=[
                    f"arn:aws:bedrock:{self.region}:{self.account}:inference-profile/{bedrock_model_id}",
                    "arn:aws:bedrock:*::foundation-model/anthropic.*",
                ],
            )
        )

        persist_fn = lambda_.Function(
            self,
            "PersistExtractionFn",
            runtime=lambda_.Runtime.PYTHON_3_12,
            architecture=lambda_.Architecture.ARM_64,
            handler="handler.handler",
            code=lambda_.Code.from_asset(str(LAMBDAS_DIR / "persist_extraction")),
            timeout=Duration.seconds(15),
            memory_size=256,
            tracing=lambda_.Tracing.ACTIVE,
            environment={"COFFEE_TABLE_NAME": coffee_table.table_name, **POWERTOOLS_ENV},
            layers=[common_layer],
        )
        coffee_table.grant_read_write_data(persist_fn)

        pipeline = ExtractionPipeline(
            self,
            "ExtractionPipeline",
            resize_fn=resize_fn,
            extract_fn=extract_fn,
            persist_fn=persist_fn,
        )
        self.state_machine = pipeline.state_machine

        # S3 ObjectCreated (via EventBridge) on the raw bucket starts an
        # extraction execution for the uploaded photoId.
        rule = events.Rule(
            self,
            "RawUploadRule",
            event_pattern=events.EventPattern(
                source=["aws.s3"],
                detail_type=["Object Created"],
                detail={
                    "bucket": {"name": [raw_bucket.bucket_name]},
                    "object": {"key": [{"prefix": "uploads/"}]},
                },
            ),
        )
        rule.add_target(
            targets.SfnStateMachine(
                self.state_machine,
                input=events.RuleTargetInput.from_object(
                    {
                        "rawImageKey": events.EventField.from_path(
                            "$.detail.object.key"
                        ),
                    }
                ),
            )
        )
