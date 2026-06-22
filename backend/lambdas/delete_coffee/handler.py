import json
import os

import boto3
from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel

logger = Logger()
tracer = Tracer()

s3 = boto3.client("s3")


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    photo_id = event["pathParameters"]["photoId"]

    try:
        item = CoffeeModel.get(photo_id)
    except CoffeeModel.DoesNotExist:
        logger.warning("Delete for unknown photoId", photo_id=photo_id)
        return {"statusCode": 404, "body": json.dumps({"message": "Not found"})}

    raw_bucket = os.environ["RAW_BUCKET_NAME"]
    processed_bucket = os.environ["PROCESSED_BUCKET_NAME"]

    if item.rawImageKey:
        s3.delete_object(Bucket=raw_bucket, Key=item.rawImageKey)
    if item.processedImageKey:
        s3.delete_object(Bucket=processed_bucket, Key=item.processedImageKey)

    item.delete()
    logger.info("Deleted coffee item", photo_id=photo_id)

    return {"statusCode": 204, "body": ""}
