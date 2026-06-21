import json
import os
import sys
from pathlib import Path

# Must be set before kafenox_common.models (and any handler that imports it)
# is first imported, since CoffeeModel.Meta reads them at class-definition
# time.
os.environ.setdefault("AWS_DEFAULT_REGION", "ap-southeast-1")
os.environ.setdefault("AWS_ACCESS_KEY_ID", "testing")
os.environ.setdefault("AWS_SECRET_ACCESS_KEY", "testing")
os.environ["COFFEE_TABLE_NAME"] = "kafenox-coffees-test"
os.environ["RAW_BUCKET_NAME"] = "raw-bucket-test"
os.environ["PROCESSED_BUCKET_NAME"] = "processed-bucket-test"

import boto3
import pytest
from moto import mock_aws

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "lambdas" / "common"))

from kafenox_common.models import CoffeeModel  # noqa: E402

from .conftest import FakeLambdaContext, load_handler_module  # noqa: E402

EXTRACTED = {
    "roaster": "Heart Roasters",
    "coffeeName": "Ethiopia Chelchele",
    "originCountry": "Ethiopia",
    "originRegion": "Yirgacheffe",
    "roastDate": "2026-06-01",
    "roastLevel": "light",
    "process": "washed",
    "variety": "Heirloom",
    "flavorNotes": ["jasmine", "citrus"],
    "altitude": "2000 masl",
}


@mock_aws
def test_upload_complete_list_update_delete_roundtrip():
    CoffeeModel.create_table(read_capacity_units=5, write_capacity_units=5, wait=True)
    s3 = boto3.client("s3", region_name="ap-southeast-1")
    s3.create_bucket(
        Bucket="raw-bucket-test",
        CreateBucketConfiguration={"LocationConstraint": "ap-southeast-1"},
    )
    s3.create_bucket(
        Bucket="processed-bucket-test",
        CreateBucketConfiguration={"LocationConstraint": "ap-southeast-1"},
    )

    upload_init = load_handler_module("upload_init_handler", "upload_init")
    persist = load_handler_module("persist_extraction_handler", "persist_extraction")
    get_coffee = load_handler_module("get_coffee_handler", "get_coffee")
    list_coffees = load_handler_module("list_coffees_handler", "list_coffees")
    update_coffee = load_handler_module("update_coffee_handler", "update_coffee")
    delete_coffee = load_handler_module("delete_coffee_handler", "delete_coffee")

    init_response = upload_init.handler({}, FakeLambdaContext())
    assert init_response["statusCode"] == 200
    photo_id = json.loads(init_response["body"])["photoId"]
    assert CoffeeModel.get(photo_id).status == "PENDING"

    complete_event = {
        "action": "SET_COMPLETE",
        "photoId": photo_id,
        "processedImageKey": f"processed/{photo_id}.jpg",
        "extracted": EXTRACTED,
    }
    persist.handler(complete_event, FakeLambdaContext())

    get_response = get_coffee.handler(
        {"pathParameters": {"photoId": photo_id}}, FakeLambdaContext()
    )
    body = json.loads(get_response["body"])
    assert body["status"] == "COMPLETE"
    assert body["lat"] == 6.1611  # Ethiopia:Yirgacheffe centroid

    list_response = list_coffees.handler(
        {"queryStringParameters": {"origin": "Ethiopia"}}, FakeLambdaContext()
    )
    coffees = json.loads(list_response["body"])["coffees"]
    assert [c["photoId"] for c in coffees] == [photo_id]

    update_response = update_coffee.handler(
        {"pathParameters": {"photoId": photo_id}, "body": json.dumps({"rating": 5})},
        FakeLambdaContext(),
    )
    assert json.loads(update_response["body"])["rating"] == 5

    delete_response = delete_coffee.handler(
        {"pathParameters": {"photoId": photo_id}}, FakeLambdaContext()
    )
    assert delete_response["statusCode"] == 204

    with pytest.raises(CoffeeModel.DoesNotExist):
        CoffeeModel.get(photo_id)
