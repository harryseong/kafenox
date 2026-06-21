import os

import boto3
from aws_lambda_powertools import Logger, Tracer
from jsonschema import ValidationError, validate

logger = Logger()
tracer = Tracer()

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")

TOOL_NAME = "extract_coffee_label"

EXTRACTION_SCHEMA = {
    "type": "object",
    "properties": {
        "roaster": {"type": ["string", "null"]},
        "coffeeName": {"type": ["string", "null"]},
        "originCountry": {"type": ["string", "null"]},
        "originRegion": {"type": ["string", "null"]},
        "roastDate": {
            "type": ["string", "null"],
            "description": "ISO 8601 date if present, else null",
        },
        "roastLevel": {
            "type": "string",
            "enum": ["light", "medium-light", "medium", "medium-dark", "dark", "unknown"],
        },
        "process": {
            "type": "string",
            "enum": ["washed", "natural", "honey", "anaerobic", "other", "unknown"],
        },
        "variety": {"type": ["string", "null"]},
        "flavorNotes": {"type": "array", "items": {"type": "string"}},
        "altitude": {
            "type": ["string", "null"],
            "description": "e.g. '1800-2000 masl', null if absent",
        },
    },
    "required": ["roaster", "coffeeName", "originCountry", "roastLevel", "process", "flavorNotes"],
}

COFFEE_EXTRACTION_TOOL = {
    "toolSpec": {
        "name": TOOL_NAME,
        "description": (
            "Extract structured coffee data from a roasted coffee bag label photo. "
            "If a field is not visible or not present on the label, return null "
            "rather than guessing."
        ),
        "inputSchema": {"json": EXTRACTION_SCHEMA},
    }
}


class ExtractionFailedError(Exception):
    pass


class BedrockThrottlingError(Exception):
    pass


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    """SFN Task: read the resized image, call Bedrock with tool-forced
    structured output, validate the response shape, return it for
    persist_extraction to write to DynamoDB."""
    photo_id = event["photoId"]
    processed_bucket = os.environ["PROCESSED_BUCKET_NAME"]
    processed_key = event["processedImageKey"]
    model_id = os.environ["BEDROCK_MODEL_ID"]

    obj = s3.get_object(Bucket=processed_bucket, Key=processed_key)
    image_bytes = obj["Body"].read()

    try:
        response = bedrock.converse(
            modelId=model_id,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"image": {"format": "jpeg", "source": {"bytes": image_bytes}}},
                        {
                            "text": (
                                "Extract the coffee details visible on this roasted "
                                "coffee bag label using the extract_coffee_label tool."
                            )
                        },
                    ],
                }
            ],
            toolConfig={
                "tools": [COFFEE_EXTRACTION_TOOL],
                "toolChoice": {"tool": {"name": TOOL_NAME}},
            },
        )
    except bedrock.exceptions.ThrottlingException as exc:
        raise BedrockThrottlingError(str(exc)) from exc
    except Exception as exc:
        raise ExtractionFailedError(f"Bedrock invocation failed: {exc}") from exc

    try:
        content_blocks = response["output"]["message"]["content"]
        tool_use = next(b["toolUse"] for b in content_blocks if "toolUse" in b)
        extracted = tool_use["input"]
        validate(instance=extracted, schema=EXTRACTION_SCHEMA)
    except (KeyError, StopIteration, ValidationError) as exc:
        raise ExtractionFailedError(f"Malformed Bedrock tool-use response: {exc}") from exc

    logger.info("Extracted coffee data", photo_id=photo_id)
    return {"photoId": photo_id, "extracted": extracted}
