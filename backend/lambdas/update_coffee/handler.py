import json

from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel
from kafenox_common.origin_geocode import geocode_origin

logger = Logger()
tracer = Tracer()

EDITABLE_FIELDS = {
    "roaster",
    "coffeeName",
    "originCountry",
    "originRegion",
    "roastDate",
    "roastLevel",
    "roastType",
    "process",
    "variety",
    "producer",
    "flavorNotes",
    "altitude",
    "rating",
}


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    photo_id = event["pathParameters"]["photoId"]
    body = json.loads(event.get("body") or "{}")

    updates = {k: v for k, v in body.items() if k in EDITABLE_FIELDS}
    if not updates:
        return {"statusCode": 400, "body": json.dumps({"message": "No editable fields provided"})}

    try:
        item = CoffeeModel.get(photo_id)
    except CoffeeModel.DoesNotExist:
        logger.warning("Update for unknown photoId", photo_id=photo_id)
        return {"statusCode": 404, "body": json.dumps({"message": "Not found"})}

    if "originCountry" in updates or "originRegion" in updates:
        country = updates.get("originCountry", item.originCountry)
        region = updates.get("originRegion", item.originRegion)
        updates["lat"], updates["lng"] = geocode_origin(country, region)

    # Any manual field edit (other than just setting a rating) marks the
    # item as human-verified.
    if set(updates) - {"rating"}:
        updates["isVerified"] = True

    for field, value in updates.items():
        setattr(item, field, value)
    item.save()
    logger.info("Updated coffee item", photo_id=photo_id, fields=list(updates.keys()))

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(item.to_dict()),
    }
