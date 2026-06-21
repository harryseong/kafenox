import datetime
import json
import os
import uuid

import boto3
from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel

logger = Logger()
tracer = Tracer()

s3 = boto3.client("s3")

PRESIGN_EXPIRY_SECONDS = 300


def _new_photo_id() -> str:
    # ULID would be ideal for lexicographic time-ordering; uuid4 hex is used
    # here to avoid an extra dependency in this small Lambda -- swap for a
    # ULID library if chronological PK ordering becomes useful later.
    return uuid.uuid4().hex


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    photo_id = _new_photo_id()
    raw_bucket = os.environ["RAW_BUCKET_NAME"]
    raw_key = f"uploads/{photo_id}.jpg"

    CoffeeModel(
        photoId=photo_id,
        status="PENDING",
        createdAt=datetime.datetime.now(datetime.UTC).isoformat(),
        rawImageKey=raw_key,
        isVerified=False,
        flavorNotes=[],
    ).save()
    logger.info("Created pending coffee item", photo_id=photo_id)

    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": raw_bucket, "Key": raw_key, "ContentType": "image/jpeg"},
        ExpiresIn=PRESIGN_EXPIRY_SECONDS,
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"photoId": photo_id, "uploadUrl": upload_url}),
    }
