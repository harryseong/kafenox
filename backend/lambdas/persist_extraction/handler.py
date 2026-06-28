import datetime
import os

from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel
from kafenox_common.origin_geocode import geocode_origin

logger = Logger()
tracer = Tracer()


def _photo_id_from_key(raw_image_key: str) -> str:
    basename = os.path.basename(raw_image_key)
    return os.path.splitext(basename)[0]


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    """SFN Task, reused for all status transitions plus the final structured
    data write -- the 'action' field in the input selects the behavior."""
    action = event["action"]

    if action == "INIT":
        raw_image_key = event["rawImageKey"]
        photo_id = _photo_id_from_key(raw_image_key)
        item = CoffeeModel.get(photo_id)
        item.status = "PROCESSING"
        item.save()
        logger.info("Marked processing", photo_id=photo_id)
        return {"photoId": photo_id, "rawImageKey": raw_image_key}

    photo_id = event["photoId"]
    item = CoffeeModel.get(photo_id)

    if action == "SET_FAILED":
        item.status = "FAILED"
        item.errorMessage = event.get("errorMessage", "Unknown processing error")
        item.save()
        logger.error("Marked failed", photo_id=photo_id, error_message=item.errorMessage)
        return {"photoId": photo_id}

    if action == "SET_COMPLETE":
        extracted = event["extracted"]
        lat, lng = geocode_origin(extracted.get("originCountry"), extracted.get("originRegion"))

        item.status = "COMPLETE"
        item.processedImageKey = event["processedImageKey"]
        item.roaster = extracted.get("roaster")
        item.coffeeName = extracted.get("coffeeName")
        item.originCountry = extracted.get("originCountry")
        item.originRegion = extracted.get("originRegion")
        item.roastDate = extracted.get("roastDate")
        item.roastLevel = extracted.get("roastLevel")
        item.roastType = extracted.get("roastType")
        item.process = extracted.get("process")
        item.variety = extracted.get("variety")
        item.producer = extracted.get("producer")
        item.flavorNotes = extracted.get("flavorNotes", [])
        item.altitude = extracted.get("altitude")
        item.lat = lat
        item.lng = lng
        item.isVerified = False
        item.extractedAt = datetime.datetime.now(datetime.UTC).isoformat()
        item.save()
        logger.info("Marked complete", photo_id=photo_id)
        return {"photoId": photo_id}

    raise ValueError(f"Unknown action: {action}")
