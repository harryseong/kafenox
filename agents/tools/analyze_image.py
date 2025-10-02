#!/usr/bin/env python3
"""
HEIC Image Analyzer - Download and prepare HEIC images for Anthropic Claude Sonnet 3.7 analysis

This module downloads HEIC images from S3, converts them to JPEG format, 
compresses them to under 200KB, and formats them for Claude vision analysis.
"""

import boto3
import base64
import tempfile
import os
from typing import Dict, Any, Optional
from PIL import Image
from pillow_heif import register_heif_opener
import io


# Register HEIF opener to enable HEIC support in PIL
register_heif_opener()


def analyze_image(s3_bucket_name: str, s3_object: str) -> Dict[str, Any]:
    """
    Download a HEIC image from S3 and prepare it for Anthropic Claude Sonnet 3.7 analysis.
    
    Args:
        s3_bucket_name: The name of the S3 bucket containing the image
        s3_object: The S3 object key (path) to the HEIC image file
    
    Returns:
        Dictionary containing image data formatted for Claude Sonnet 3.7 analysis
    """
    try:
        # Initialize S3 client
        s3_client = boto3.client('s3', region_name='us-east-1')
        
        # Validate the file is a HEIC
        if not s3_object.lower().endswith(('.heic', '.heif')):
            return {
                'success': False,
                'error': f"File must be HEIC/HEIF format. Got: {s3_object}",
                'image_data': None,
                'metadata': None
            }
        
        # Get object metadata first
        try:
            metadata_response = s3_client.head_object(Bucket=s3_bucket_name, Key=s3_object)
            original_file_size = metadata_response['ContentLength']
            last_modified = metadata_response['LastModified'].isoformat()
            content_type = metadata_response.get('ContentType', 'unknown')
        except Exception as e:
            return {
                'success': False,
                'error': f"Could not access object metadata: {str(e)}",
                'image_data': None,
                'metadata': None
            }
        
        # Check file size (reasonable limit for processing)
        max_input_size = 50 * 1024 * 1024  # 50MB
        if original_file_size > max_input_size:
            return {
                'success': False,
                'error': f"HEIC file too large ({original_file_size} bytes). Maximum size is {max_input_size} bytes.",
                'image_data': None,
                'metadata': {
                    'original_file_size': original_file_size,
                    'last_modified': last_modified,
                    'content_type': content_type
                }
            }
        
        # Download the HEIC image to temporary file
        with tempfile.NamedTemporaryFile(suffix='.heic') as temp_file:
            try:
                s3_client.download_file(s3_bucket_name, s3_object, temp_file.name)
                
                # Open and process the HEIC image
                with Image.open(temp_file.name) as img:
                    # Get original image info
                    original_width, original_height = img.size
                    original_format = img.format
                    original_mode = img.mode
                    
                    # Convert to RGB if necessary (Claude Sonnet 3.7 prefers RGB)
                    if img.mode != 'RGB':
                        img = img.convert('RGB')
                    
                    # Start with current dimensions
                    current_width, current_height = original_width, original_height
                    
                    # Initial resize if image is extremely large (optimize for Claude)
                    max_initial_dimension = 3000
                    if current_width > max_initial_dimension or current_height > max_initial_dimension:
                        if current_width > current_height:
                            new_width = max_initial_dimension
                            new_height = int((current_height * max_initial_dimension) / current_width)
                        else:
                            new_height = max_initial_dimension
                            new_width = int((current_width * max_initial_dimension) / current_height)
                        
                        img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                        current_width, current_height = new_width, new_height
                    
                    # Compress to under 200KB for Claude Sonnet 3.7
                    target_size = 200 * 1024  # 200KB
                    quality = 95
                    min_quality = 20
                    
                    # First attempt with high quality
                    img_buffer = io.BytesIO()
                    img.save(img_buffer, format='JPEG', quality=quality, optimize=True)
                    current_size = len(img_buffer.getvalue())
                    
                    # Iteratively reduce quality if needed
                    while current_size > target_size and quality > min_quality:
                        quality -= 5
                        img_buffer = io.BytesIO()
                        img.save(img_buffer, format='JPEG', quality=quality, optimize=True)
                        current_size = len(img_buffer.getvalue())
                    
                    # If still too large, progressively resize
                    resize_attempts = 0
                    max_resize_attempts = 10
                    
                    while current_size > target_size and resize_attempts < max_resize_attempts:
                        # Reduce dimensions by 10%
                        scale_factor = 0.9
                        new_width = int(current_width * scale_factor)
                        new_height = int(current_height * scale_factor)
                        
                        # Don't go below reasonable minimum size
                        if new_width < 400 or new_height < 400:
                            break
                            
                        resized_img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)
                        
                        # Try saving with current quality
                        img_buffer = io.BytesIO()
                        resized_img.save(img_buffer, format='JPEG', quality=quality, optimize=True)
                        current_size = len(img_buffer.getvalue())
                        
                        if current_size <= target_size:
                            img = resized_img
                            current_width, current_height = new_width, new_height
                            break
                        
                        # Update for next iteration
                        current_width, current_height = new_width, new_height
                        resize_attempts += 1
                    
                    # Final image data
                    final_img_bytes = img_buffer.getvalue()
                    final_size = len(final_img_bytes)
                    
                    # Encode to base64 for Claude Sonnet 3.7
                    base64_image = base64.b64encode(final_img_bytes).decode('utf-8')
                
                # Prepare the response in Claude Sonnet 3.7 compatible format
                return {
                    'success': True,
                    'error': None,
                    'image_data': {
                        'type': 'base64',
                        'media_type': 'image/jpeg',
                        'data': base64_image
                    },
                    'metadata': {
                        'original_s3_uri': f"s3://{s3_bucket_name}/{s3_object}",
                        'bucket': s3_bucket_name,
                        'object_key': s3_object,
                        'original_file_size': original_file_size,
                        'last_modified': last_modified,
                        'content_type': content_type,
                        'conversion': {
                            'source_format': original_format,
                            'target_format': 'JPEG',
                            'source_mode': original_mode,
                            'target_mode': 'RGB'
                        },
                        'dimensions': {
                            'original_width': original_width,
                            'original_height': original_height,
                            'final_width': current_width,
                            'final_height': current_height,
                            'resized': (current_width != original_width or current_height != original_height)
                        },
                        'compression': {
                            'final_quality': quality,
                            'final_file_size': final_size,
                            'compression_ratio': round(final_size / original_file_size, 3),
                            'target_size_met': final_size <= target_size
                        }
                    },
                    'claude_format': {
                        'type': 'image',
                        'source': {
                            'type': 'base64',
                            'media_type': 'image/jpeg',
                            'data': base64_image
                        }
                    }
                }
                
            except Exception as e:
                return {
                    'success': False,
                    'error': f"Error processing HEIC image: {str(e)}",
                    'image_data': None,
                    'metadata': {
                        'original_file_size': original_file_size,
                        'last_modified': last_modified,
                        'content_type': content_type
                    }
                }
                
    except Exception as e:
        return {
            'success': False,
            'error': f"Error downloading from S3: {str(e)}",
            'image_data': None,
            'metadata': None
        }


if __name__ == "__main__":
    # Test the HEIC image analysis function
    import sys
    
    if len(sys.argv) < 3:
        print("Usage: python analyze_image.py <bucket_name> <object_key>")
        print("Example: python analyze_image.py kafenox-data images/nylon_coffee_bags/raw/IMG_5905.heic")
        sys.exit(1)
    
    bucket = sys.argv[1]
    object_key = sys.argv[2]
    
    print(f"🔍 Processing HEIC image s3://{bucket}/{object_key} for Claude Sonnet 3.7...")
    
    # Test the analyze_image function
    result = analyze_image(bucket, object_key)
    
    if result['success']:
        print("✅ HEIC image successfully converted and prepared for Claude Sonnet 3.7")
        print(f"📊 Original dimensions: {result['metadata']['dimensions']['original_width']}x{result['metadata']['dimensions']['original_height']}")
        print(f"📊 Final dimensions: {result['metadata']['dimensions']['final_width']}x{result['metadata']['dimensions']['final_height']}")
        print(f"📁 Original HEIC size: {result['metadata']['original_file_size']:,} bytes")
        print(f"📁 Final JPEG size: {result['metadata']['compression']['final_file_size']:,} bytes")
        print(f"🗜️ Compression ratio: {result['metadata']['compression']['compression_ratio']}")
        print(f"🎯 Quality used: {result['metadata']['compression']['final_quality']}%")
        print(f"✅ Under 200KB: {result['metadata']['compression']['target_size_met']}")
        print(f"🔗 S3 URI: {result['metadata']['original_s3_uri']}")
        print(f"📝 Base64 data length: {len(result['image_data']['data']):,} characters")
            
    else:
        print(f"❌ Error: {result['error']}")
        if result['metadata']:
            print(f"📊 File info: {result['metadata']}")