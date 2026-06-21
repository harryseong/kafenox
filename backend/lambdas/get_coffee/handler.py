import json

from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel

logger = Logger()
tracer = Tracer()


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    photo_id = event["pathParameters"]["photoId"]

    try:
        item = CoffeeModel.get(photo_id)
    except CoffeeModel.DoesNotExist:
        logger.warning("Get coffee for unknown photoId", photo_id=photo_id)
        return {"statusCode": 404, "body": json.dumps({"message": "Not found"})}

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(item.to_dict()),
    }
