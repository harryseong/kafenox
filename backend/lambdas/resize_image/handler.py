import io
import os

import boto3
from aws_lambda_powertools import Logger, Tracer
from PIL import Image, ImageOps

logger = Logger()
tracer = Tracer()

s3 = boto3.client("s3")

MAX_LONG_EDGE = 1280
JPEG_QUALITY = 85


class ImageProcessingError(Exception):
    pass


@logger.inject_lambda_context(log_event=False)
@tracer.capture_lambda_handler
def handler(event, context):
    """SFN Task: read the raw upload, resize to 720p, write to the processed
    bucket. Raises ImageProcessingError (caught by the state machine) on
    corrupt/unsupported input."""
    photo_id = event["photoId"]
    raw_bucket = os.environ["RAW_BUCKET_NAME"]
    processed_bucket = os.environ["PROCESSED_BUCKET_NAME"]
    raw_key = event["rawImageKey"]
    processed_key = f"processed/{photo_id}.jpg"

    try:
        obj = s3.get_object(Bucket=raw_bucket, Key=raw_key)
        image = Image.open(io.BytesIO(obj["Body"].read()))
        image = ImageOps.exif_transpose(image)
        if image.mode != "RGB":
            image = image.convert("RGB")
        image.thumbnail((MAX_LONG_EDGE, MAX_LONG_EDGE), Image.LANCZOS)

        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=JPEG_QUALITY)
        buffer.seek(0)
    except Exception as exc:
        raise ImageProcessingError(f"Failed to process image {raw_key}: {exc}") from exc

    s3.put_object(
        Bucket=processed_bucket,
        Key=processed_key,
        Body=buffer.getvalue(),
        ContentType="image/jpeg",
    )
    logger.info("Resized image", photo_id=photo_id, processed_key=processed_key)

    return {
        "photoId": photo_id,
        "rawImageKey": raw_key,
        "processedImageKey": processed_key,
    }
