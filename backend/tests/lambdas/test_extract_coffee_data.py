import io
from unittest.mock import patch

from .conftest import FakeLambdaContext, load_handler_module

handler = load_handler_module("extract_coffee_data_handler", "extract_coffee_data")

VALID_TOOL_INPUT = {
    "roaster": "Heart Roasters",
    "coffeeName": "Ethiopia Chelchele",
    "originCountry": "Ethiopia",
    "originRegion": "Gedeo",
    "roastDate": "2026-06-10",
    "roastLevel": "light",
    "process": "washed",
    "variety": "Heirloom",
    "flavorNotes": ["jasmine", "stone fruit"],
    "altitude": "1900-2100 masl",
}


def _converse_response(tool_input: dict) -> dict:
    return {
        "output": {
            "message": {
                "content": [
                    {"toolUse": {"name": handler.TOOL_NAME, "input": tool_input}},
                ]
            }
        }
    }


@patch.dict("os.environ", {"PROCESSED_BUCKET_NAME": "processed-bucket", "BEDROCK_MODEL_ID": "apac.test-model"})
@patch.object(handler, "s3")
@patch.object(handler, "bedrock")
def test_returns_extracted_fields_on_valid_response(mock_bedrock, mock_s3):
    mock_s3.get_object.return_value = {"Body": io.BytesIO(b"fake-jpeg-bytes")}
    mock_bedrock.converse.return_value = _converse_response(VALID_TOOL_INPUT)

    event = {"photoId": "abc123", "processedImageKey": "processed/abc123.jpg"}
    result = handler.handler(event, FakeLambdaContext())

    assert result["photoId"] == "abc123"
    assert result["extracted"]["originCountry"] == "Ethiopia"


@patch.dict("os.environ", {"PROCESSED_BUCKET_NAME": "processed-bucket", "BEDROCK_MODEL_ID": "apac.test-model"})
@patch.object(handler, "s3")
@patch.object(handler, "bedrock")
def test_raises_extraction_failed_on_malformed_tool_response(mock_bedrock, mock_s3):
    mock_s3.get_object.return_value = {"Body": io.BytesIO(b"fake-jpeg-bytes")}
    bad_input = dict(VALID_TOOL_INPUT)
    bad_input["roastLevel"] = "extra-dark-not-a-valid-enum-value"
    mock_bedrock.converse.return_value = _converse_response(bad_input)

    event = {"photoId": "abc123", "processedImageKey": "processed/abc123.jpg"}
    try:
        handler.handler(event, FakeLambdaContext())
        assert False, "expected ExtractionFailedError"
    except handler.ExtractionFailedError:
        pass
