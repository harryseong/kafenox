import json
import os

from aws_lambda_powertools import Logger, Tracer
from kafenox_common.flavor_families import categorize_flavor_notes
from kafenox_common.model_prefs import resolve_model_id
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


def _families_for(item: CoffeeModel, notes: list, model_choice: str | None) -> dict | None:
    """Keep existing note->family assignments; categorize only new notes.
    A categorization failure leaves the new notes unmapped (the app falls
    back to its client-side lookup) rather than failing the edit."""
    existing = item.to_dict().get("flavorFamilies") or {}
    families = {n: existing[n] for n in notes if n in existing}
    new_notes = [n for n in notes if n not in existing]
    if new_notes:
        try:
            families.update(
                categorize_flavor_notes(
                    new_notes,
                    resolve_model_id(model_choice, os.environ["BEDROCK_MODEL_ID"]),
                )
            )
        except Exception as exc:
            logger.warning("Flavor-family categorization failed", error=str(exc))
    return families or None


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    photo_id = event["pathParameters"]["photoId"]
    body = json.loads(event.get("body") or "{}")

    # Optional Settings-driven model choice for categorizing new flavor
    # notes; not a persisted field.
    model_choice = body.get("model")
    # "Looks good" confirms an extracted item as-is, with no field edits.
    verify_only = body.get("verified") is True
    updates = {k: v for k, v in body.items() if k in EDITABLE_FIELDS}
    if not updates and not verify_only:
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

    if "flavorNotes" in updates:
        updates["flavorFamilies"] = _families_for(item, updates["flavorNotes"] or [], model_choice)

    # Any manual field edit (other than just setting a rating) marks the
    # item as human-verified, as does an explicit "looks good" confirmation.
    if verify_only or (set(updates) - {"rating"}):
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
