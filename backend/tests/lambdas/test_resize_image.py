import io
from unittest.mock import patch

from PIL import Image

from .conftest import FakeLambdaContext, load_handler_module

handler = load_handler_module("resize_image_handler", "resize_image")


def _make_test_jpeg(width: int, height: int) -> bytes:
    image = Image.new("RGB", (width, height), color="brown")
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG")
    return buffer.getvalue()


@patch.dict(
    "os.environ",
    {"RAW_BUCKET_NAME": "raw-bucket", "PROCESSED_BUCKET_NAME": "processed-bucket"},
)
@patch.object(handler, "s3")
def test_resizes_large_image_to_720p_long_edge(mock_s3):
    raw_bytes = _make_test_jpeg(4000, 3000)
    mock_s3.get_object.return_value = {"Body": io.BytesIO(raw_bytes)}

    event = {"photoId": "abc123", "rawImageKey": "uploads/abc123.jpg"}
    result = handler.handler(event, FakeLambdaContext())

    assert result["processedImageKey"] == "processed/abc123.jpg"
    put_call = mock_s3.put_object.call_args
    assert put_call.kwargs["Bucket"] == "processed-bucket"
    assert put_call.kwargs["Key"] == "processed/abc123.jpg"

    resized = Image.open(io.BytesIO(put_call.kwargs["Body"]))
    assert max(resized.size) <= handler.MAX_LONG_EDGE


@patch.dict(
    "os.environ",
    {"RAW_BUCKET_NAME": "raw-bucket", "PROCESSED_BUCKET_NAME": "processed-bucket"},
)
@patch.object(handler, "s3")
def test_raises_on_corrupt_image(mock_s3):
    mock_s3.get_object.return_value = {"Body": io.BytesIO(b"not an image")}

    event = {"photoId": "abc123", "rawImageKey": "uploads/abc123.jpg"}
    try:
        handler.handler(event, FakeLambdaContext())
        assert False, "expected ImageProcessingError"
    except handler.ImageProcessingError:
        pass
