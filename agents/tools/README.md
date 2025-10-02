# Agent Tools Directory

This directory contains utility tools for Strands agents in the Kafenox project.

## Available Tools

### 1. S3 Helper (`s3_helper.py`)

Lists files in S3 buckets with optional prefix filtering.

**Function**: `s3_helper(s3_bucket_name, s3_prefix="")`
- **Args**: bucket name (str), optional prefix (str)
- **Returns**: List of S3 object keys

**Usage**:
```python
from agents.tools.s3_helper import s3_helper
files = s3_helper("kafenox-data", "images/nylon_coffee_bags/")
```

### 2. Image Converter (`convert_image.py`)

Converts HEIC images to JPG format, downloading from S3 and uploading converted images back.

**Main Function**: `convert_heic_images(s3_uris)`
- **Args**: List of S3 URIs pointing to HEIC files
- **Returns**: Dictionary with conversion results

**Convenience Function**: `convert_images_from_bucket(bucket_name, prefix)`
- **Args**: bucket name (str), prefix (str)
- **Returns**: Dictionary with conversion results

### 3. Image Analyzer (`analyze_image.py`)

Downloads JPG images from S3 and prepares them for Anthropic Claude LLM vision analysis.

**Main Function**: `analyze_image(s3_bucket_name, s3_object)`
- **Args**: bucket name (str), S3 object key (str)
- **Returns**: Dictionary with base64-encoded image data formatted for Claude

**Convenience Function**: `get_claude_image_message(s3_bucket_name, s3_object, prompt)`
- **Args**: bucket name (str), object key (str), analysis prompt (str)
- **Returns**: Complete Claude message format with image and text

**Features**:
- Downloads JPG images from S3
- Validates file format and size (max 20MB for Claude)
- Resizes large images while maintaining aspect ratio (max 2048px)
- Converts to RGB color space for optimal Claude processing
- Encodes to base64 format required by Claude Vision API
- Returns both raw image data and Claude-formatted message structure
- Comprehensive error handling and metadata collection

**Usage Examples**:

```python
# Analyze a specific image
from agents.tools.analyze_image import analyze_image
result = analyze_image("kafenox-data", "images/nylon_coffee_bags/processed/jpg/IMG_5905.jpg")

if result['success']:
    # Use the base64 data with Claude
    image_data = result['image_data']
    claude_format = result['claude_format']

# Get complete Claude message
from agents.tools.analyze_image import get_claude_image_message
message = get_claude_image_message(
    "kafenox-data", 
    "images/nylon_coffee_bags/processed/jpg/IMG_5905.jpg",
    "Describe this coffee bag design in detail"
)

if message['success']:
    # Send message['message'] to Claude
    claude_message = message['message']
```

**Command Line Usage**:
```bash
# Analyze an image
python agents/tools/analyze_image.py kafenox-data images/nylon_coffee_bags/processed/jpg/IMG_5905.jpg

# With custom prompt
python agents/tools/analyze_image.py kafenox-data images/nylon_coffee_bags/processed/jpg/IMG_5905.jpg "What colors are in this image?"
```

**Claude Message Format**:
The tool returns data in the exact format expected by Claude's Vision API:
```python
{
    'role': 'user',
    'content': [
        {
            'type': 'text',
            'text': 'Your analysis prompt here'
        },
        {
            'type': 'image',
            'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': 'base64_encoded_image_data_here'
            }
        }
    ]
}
```

**Image Processing Features**:
- **Format Validation**: Ensures JPG/JPEG format
- **Size Limits**: Respects Claude's 20MB limit
- **Smart Resizing**: Maintains aspect ratio, max 2048px dimension
- **Color Space**: Converts to RGB for optimal Claude processing
- **Quality Optimization**: 90% JPEG quality with optimization
- **Metadata Preservation**: Tracks original file info and processing details

## Installation

The tools use dependencies already specified in the main requirements.txt:

```bash
pip install -r agents/requirements.txt
```

## Key Dependencies

- **boto3**: AWS SDK for S3 operations
- **Pillow**: Image processing and format conversion
- **pillow-heif**: HEIC format support
- **strands-agents**: Agent framework integration

## AWS Configuration

Ensure your AWS credentials are configured with:
- S3 read permissions for source buckets
- S3 write permissions for processed image uploads
- Proper region configuration (us-east-1)

## Integration with Strands Agents

All tools are designed to be easily integrated as Strands agent tools using the `@tool` decorator. See `agents/main/agent.py` for examples of how to wrap these functions for agent use.

## Error Handling

All tools include comprehensive error handling:
- AWS credential and permission issues
- Invalid file formats or corrupted images
- Network connectivity problems
- File size and processing limitations
- Detailed error messages and metadata for debugging