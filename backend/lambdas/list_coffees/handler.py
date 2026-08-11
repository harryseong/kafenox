import json

from aws_lambda_powertools import Logger, Tracer
from kafenox_common.models import CoffeeModel

logger = Logger()
tracer = Tracer()


def _build_filter_condition(params: dict):
    """No status filter by default: the catalog shows in-flight
    (PENDING/PROCESSING) and FAILED items too, so the user can see what's
    still being extracted. Those items have no roastLevel/rating/etc. yet, so
    they naturally drop out of any of the optional filters below."""
    condition = None

    def add(new_condition):
        nonlocal condition
        condition = new_condition if condition is None else condition & new_condition

    if params.get("status"):
        add(CoffeeModel.status == params["status"])
    if params.get("origin"):
        add(CoffeeModel.originCountry == params["origin"])
    if params.get("roastLevel"):
        add(CoffeeModel.roastLevel == params["roastLevel"])
    if params.get("roastDateFrom"):
        add(CoffeeModel.roastDate >= params["roastDateFrom"])
    if params.get("roastDateTo"):
        add(CoffeeModel.roastDate <= params["roastDateTo"])
    if params.get("minRating"):
        add(CoffeeModel.rating >= int(params["minRating"]))
    return condition


def _matches_flavor_note(item: CoffeeModel, flavor_note: str | None) -> bool:
    if not flavor_note:
        return True
    notes = [n.lower() for n in (item.flavorNotes or [])]
    return any(flavor_note.lower() in n for n in notes)


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    """At catalog sizes of "a few hundred bags ever", a filtered Scan is
    simpler and fast enough -- no GSIs needed. Revisit only if item count
    grows past ~5-10k."""
    params = event.get("queryStringParameters") or {}

    condition = _build_filter_condition(params)
    items = [
        item.to_dict()
        for item in CoffeeModel.scan(filter_condition=condition)
        if _matches_flavor_note(item, params.get("flavorNote"))
    ]
    logger.info("Listed coffees", count=len(items))

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"coffees": items}),
    }
