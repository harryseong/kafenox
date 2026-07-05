from pathlib import Path

from aws_cdk import Duration, Stack
from aws_cdk import aws_apigateway as apigateway
from aws_cdk import aws_dynamodb as dynamodb
from aws_cdk import aws_iam as iam
from aws_cdk import aws_lambda as lambda_
from aws_cdk import aws_s3 as s3
from aws_cdk.aws_lambda_python_alpha import PythonLayerVersion
from constructs import Construct

LAMBDAS_DIR = Path(__file__).parent.parent.parent / "lambdas"

POWERTOOLS_ENV = {"POWERTOOLS_SERVICE_NAME": "kafenox", "POWERTOOLS_LOG_LEVEL": "INFO"}


class ApiStack(Stack):
    """API Gateway REST API + CRUD/status Lambdas + API key auth. Iterated
    on for routes/auth independently of the data plane (StorageStack) and
    the extraction pipeline (ProcessingStack)."""

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        env_name: str,
        coffee_table: dynamodb.ITable,
        raw_bucket: s3.IBucket,
        processed_bucket: s3.IBucket,
        bedrock_model_id: str,
        insights_model_id: str,
        **kwargs,
    ) -> None:
        super().__init__(scope, construct_id, **kwargs)

        common_layer = PythonLayerVersion(
            self,
            "ApiCommonLayer",
            entry=str(LAMBDAS_DIR / "common"),
            compatible_runtimes=[lambda_.Runtime.PYTHON_3_12],
            compatible_architectures=[lambda_.Architecture.ARM_64],
        )

        def make_fn(
            name: str,
            dir_name: str,
            extra_env: dict | None = None,
            timeout_seconds: int = 15,
        ) -> lambda_.Function:
            fn = lambda_.Function(
                self,
                name,
                runtime=lambda_.Runtime.PYTHON_3_12,
                architecture=lambda_.Architecture.ARM_64,
                handler="handler.handler",
                code=lambda_.Code.from_asset(str(LAMBDAS_DIR / dir_name)),
                timeout=Duration.seconds(timeout_seconds),
                memory_size=256,
                tracing=lambda_.Tracing.ACTIVE,
                environment={
                    "COFFEE_TABLE_NAME": coffee_table.table_name,
                    **POWERTOOLS_ENV,
                    **(extra_env or {}),
                },
                layers=[common_layer],
            )
            return fn

        def grant_bedrock_invoke(fn: lambda_.Function, model_id: str) -> None:
            """Mirror of the extract function's Bedrock grants in
            processing_stack.py: invoke via the global inference profile, plus
            marketplace self-subscribe for gated Claude models (those actions
            don't support resource-level scoping)."""
            fn.add_to_role_policy(
                iam.PolicyStatement(
                    actions=["bedrock:InvokeModel"],
                    resources=[
                        f"arn:aws:bedrock:{self.region}:{self.account}:inference-profile/{model_id}",
                        "arn:aws:bedrock:*::foundation-model/anthropic.*",
                    ],
                )
            )
            fn.add_to_role_policy(
                iam.PolicyStatement(
                    actions=[
                        "aws-marketplace:Subscribe",
                        "aws-marketplace:ViewSubscriptions",
                    ],
                    resources=["*"],
                )
            )

        upload_init_fn = make_fn(
            "UploadInitFn", "upload_init", {"RAW_BUCKET_NAME": raw_bucket.bucket_name}
        )
        get_upload_status_fn = make_fn("GetUploadStatusFn", "get_upload_status")
        list_coffees_fn = make_fn("ListCoffeesFn", "list_coffees")
        get_coffee_fn = make_fn("GetCoffeeFn", "get_coffee")
        # PATCHed flavor notes are re-categorized into flavor families via
        # Bedrock, so the update function needs the model id + invoke grant.
        update_coffee_fn = make_fn(
            "UpdateCoffeeFn",
            "update_coffee",
            {"BEDROCK_MODEL_ID": bedrock_model_id},
            timeout_seconds=30,
        )
        ask_insights_fn = make_fn(
            "AskInsightsFn",
            "ask_insights",
            {"BEDROCK_INSIGHTS_MODEL_ID": insights_model_id},
            timeout_seconds=30,
        )
        delete_coffee_fn = make_fn(
            "DeleteCoffeeFn",
            "delete_coffee",
            {
                "RAW_BUCKET_NAME": raw_bucket.bucket_name,
                "PROCESSED_BUCKET_NAME": processed_bucket.bucket_name,
            },
        )

        coffee_table.grant_write_data(upload_init_fn)
        coffee_table.grant_read_data(get_upload_status_fn)
        coffee_table.grant_read_data(list_coffees_fn)
        coffee_table.grant_read_data(get_coffee_fn)
        coffee_table.grant_read_write_data(update_coffee_fn)
        coffee_table.grant_read_write_data(delete_coffee_fn)
        coffee_table.grant_read_data(ask_insights_fn)
        grant_bedrock_invoke(update_coffee_fn, bedrock_model_id)
        grant_bedrock_invoke(ask_insights_fn, insights_model_id)
        raw_bucket.grant_put(upload_init_fn)
        raw_bucket.grant_delete(delete_coffee_fn)
        processed_bucket.grant_delete(delete_coffee_fn)

        api = apigateway.RestApi(
            self,
            "KafenoxApi",
            rest_api_name=f"kafenox-api-{env_name}",
            deploy_options=apigateway.StageOptions(stage_name=env_name),
            default_method_options=apigateway.MethodOptions(api_key_required=True),
        )

        uploads = api.root.add_resource("uploads")
        uploads.add_method("POST", apigateway.LambdaIntegration(upload_init_fn))
        upload_status = uploads.add_resource("{photoId}").add_resource("status")
        upload_status.add_method("GET", apigateway.LambdaIntegration(get_upload_status_fn))

        coffees = api.root.add_resource("coffees")
        coffees.add_method("GET", apigateway.LambdaIntegration(list_coffees_fn))
        coffee = coffees.add_resource("{photoId}")
        coffee.add_method("GET", apigateway.LambdaIntegration(get_coffee_fn))
        coffee.add_method("PATCH", apigateway.LambdaIntegration(update_coffee_fn))
        coffee.add_method("DELETE", apigateway.LambdaIntegration(delete_coffee_fn))

        insights = api.root.add_resource("insights")
        insights_ask = insights.add_resource("ask")
        insights_ask.add_method("POST", apigateway.LambdaIntegration(ask_insights_fn))

        api_key = api.add_api_key("KafenoxApiKey", api_key_name=f"kafenox-ios-{env_name}")
        usage_plan = api.add_usage_plan(
            "KafenoxUsagePlan",
            name=f"kafenox-usage-plan-{env_name}",
            throttle=apigateway.ThrottleSettings(rate_limit=50, burst_limit=100),
        )
        usage_plan.add_api_key(api_key)
        usage_plan.add_api_stage(stage=api.deployment_stage)

        self.api = api
