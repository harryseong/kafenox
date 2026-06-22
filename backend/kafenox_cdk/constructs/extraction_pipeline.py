from aws_cdk import Duration, RemovalPolicy
from aws_cdk import aws_lambda as lambda_
from aws_cdk import aws_logs as logs
from aws_cdk import aws_stepfunctions as sfn
from aws_cdk import aws_stepfunctions_tasks as tasks
from constructs import Construct


class ExtractionPipeline(Construct):
    """Step Functions Express state machine orchestrating the
    resize -> Bedrock extract -> persist pipeline, with status updates and
    retry/catch so the iOS app can poll PENDING/PROCESSING/COMPLETE/FAILED
    on the DynamoDB item.

    Input: {"rawImageKey": "uploads/<photoId>.jpg"}. photoId is derived from
    the key (not threaded through EventBridge JsonPath) by the first
    persist_fn invocation (action=INIT), since ASL intrinsics for string
    splitting are more fragile than doing it once in Python.
    """

    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        resize_fn: lambda_.IFunction,
        extract_fn: lambda_.IFunction,
        persist_fn: lambda_.IFunction,
    ) -> None:
        super().__init__(scope, construct_id)

        init = tasks.LambdaInvoke(
            self,
            "MarkProcessing",
            lambda_function=persist_fn,
            payload=sfn.TaskInput.from_object(
                {
                    "action": "INIT",
                    "rawImageKey": sfn.JsonPath.string_at("$.rawImageKey"),
                }
            ),
            payload_response_only=True,
            result_path="$.init",
        )

        resize_image = tasks.LambdaInvoke(
            self,
            "ResizeImage",
            lambda_function=resize_fn,
            payload=sfn.TaskInput.from_object(
                {
                    "photoId": sfn.JsonPath.string_at("$.init.photoId"),
                    "rawImageKey": sfn.JsonPath.string_at("$.init.rawImageKey"),
                }
            ),
            payload_response_only=True,
            result_path="$.resizeResult",
        )

        extract_data = tasks.LambdaInvoke(
            self,
            "ExtractCoffeeData",
            lambda_function=extract_fn,
            payload=sfn.TaskInput.from_object(
                {
                    "photoId": sfn.JsonPath.string_at("$.init.photoId"),
                    "processedImageKey": sfn.JsonPath.string_at(
                        "$.resizeResult.processedImageKey"
                    ),
                }
            ),
            payload_response_only=True,
            result_path="$.extractResult",
        ).add_retry(
            errors=["BedrockThrottlingError"],
            interval=Duration.seconds(2),
            max_attempts=3,
            backoff_rate=2,
        )

        persist_complete = tasks.LambdaInvoke(
            self,
            "PersistExtraction",
            lambda_function=persist_fn,
            payload=sfn.TaskInput.from_object(
                {
                    "action": "SET_COMPLETE",
                    "photoId": sfn.JsonPath.string_at("$.init.photoId"),
                    "processedImageKey": sfn.JsonPath.string_at(
                        "$.resizeResult.processedImageKey"
                    ),
                    "extracted": sfn.JsonPath.object_at("$.extractResult.extracted"),
                }
            ),
            payload_response_only=True,
            result_path=sfn.JsonPath.DISCARD,
        )

        mark_failed = tasks.LambdaInvoke(
            self,
            "MarkFailed",
            lambda_function=persist_fn,
            payload=sfn.TaskInput.from_object(
                {
                    "action": "SET_FAILED",
                    "photoId": sfn.JsonPath.string_at("$.init.photoId"),
                    "errorMessage": sfn.JsonPath.string_at("$.error.Cause"),
                }
            ),
            payload_response_only=True,
            result_path=sfn.JsonPath.DISCARD,
        ).next(sfn.Fail(self, "ExtractionFailed"))

        resize_image.add_catch(mark_failed, errors=["States.ALL"], result_path="$.error")
        extract_data.add_catch(mark_failed, errors=["States.ALL"], result_path="$.error")
        persist_complete.add_catch(mark_failed, errors=["States.ALL"], result_path="$.error")

        definition = init.next(resize_image).next(extract_data).next(persist_complete)

        log_group = logs.LogGroup(
            self,
            "ExtractionStateMachineLogs",
            removal_policy=RemovalPolicy.DESTROY,
            retention=logs.RetentionDays.ONE_MONTH,
        )

        self.state_machine = sfn.StateMachine(
            self,
            "ExtractionStateMachine",
            definition_body=sfn.DefinitionBody.from_chainable(definition),
            state_machine_type=sfn.StateMachineType.EXPRESS,
            timeout=Duration.minutes(2),
            logs=sfn.LogOptions(destination=log_group, level=sfn.LogLevel.ERROR),
        )
