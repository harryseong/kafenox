#!/usr/bin/env python3
"""
Image Converter - Convert HEIC images to JPG format

This module downloads HEIC images from S3, converts them to JPG format,
and uploads the converted images back to S3.
"""

import boto3
import os
import tempfile
from typing import List, Dict, Any
from urllib.parse import urlparse
from PIL import Image
import pillow_heif


def convert_heic_images(s3_uris: List[str]) -> Dict[str, Any]:
    """
    Convert HEIC images from S3 URIs to JPG format and upload to processed folder.
    
    Args:
        s3_uris: List of S3 URIs pointing to HEIC image files
                Example: ['s3://kafenox-data/images/nylon_coffee_bags/IMG_5905.HEIC']
    
    Returns:
        Dictionary with conversion results including success/failure counts and details
    """
    # Register HEIF opener with Pillow
    pillow_heif.register_heif_opener()
    
    # Initialize S3 client
    s3_client = boto3.client('s3', region_name='us-east-1')
    
    results = {
        'total_files': len(s3_uris),
        'successful_conversions': 0,
        'failed_conversions': 0,
        'converted_files': [],
        'failed_files': [],
        'errors': []
    }
    
    for s3_uri in s3_uris:
        try:
            # Parse S3 URI
            parsed_uri = urlparse(s3_uri)
            if parsed_uri.scheme != 's3':
                error_msg = f"Invalid S3 URI: {s3_uri}"
                results['errors'].append(error_msg)
                results['failed_files'].append(s3_uri)
                results['failed_conversions'] += 1
                continue
            
            bucket_name = parsed_uri.netloc
            object_key = parsed_uri.path.lstrip('/')
            
            # Validate it's a HEIC file
            if not object_key.lower().endswith('.heic'):
                error_msg = f"File is not HEIC format: {s3_uri}"
                results['errors'].append(error_msg)
                results['failed_files'].append(s3_uri)
                results['failed_conversions'] += 1
                continue
            
            # Generate output key for processed JPG
            filename = os.path.basename(object_key)
            filename_without_ext = os.path.splitext(filename)[0]
            output_key = f"images/nylon_coffee_bags/processed/jpg/{filename_without_ext}.jpg"
            
            # Create temporary files for download and conversion
            with tempfile.NamedTemporaryFile(suffix='.heic', delete=False) as temp_heic:
                with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_jpg:
                    try:
                        # Download HEIC file from S3
                        print(f"📥 Downloading {object_key}...")
                        s3_client.download_file(bucket_name, object_key, temp_heic.name)
                        
                        # Convert HEIC to JPG using Pillow
                        print(f"🔄 Converting {filename} to JPG...")
                        with Image.open(temp_heic.name) as img:
                            # Convert to RGB if necessary (HEIC might be in different color space)
                            if img.mode != 'RGB':
                                img = img.convert('RGB')
                            
                            # Save as JPG with high quality
                            img.save(temp_jpg.name, 'JPEG', quality=95, optimize=True)
                        
                        # Upload converted JPG back to S3
                        print(f"📤 Uploading {output_key}...")
                        s3_client.upload_file(
                            temp_jpg.name, 
                            bucket_name, 
                            output_key,
                            ExtraArgs={
                                'ContentType': 'image/jpeg',
                                'Metadata': {
                                    'original-file': object_key,
                                    'conversion-tool': 'convert_image.py',
                                    'format': 'jpeg'
                                }
                            }
                        )
                        
                        # Record successful conversion
                        conversion_info = {
                            'original_uri': s3_uri,
                            'original_key': object_key,
                            'converted_key': output_key,
                            'converted_uri': f"s3://{bucket_name}/{output_key}"
                        }
                        results['converted_files'].append(conversion_info)
                        results['successful_conversions'] += 1
                        
                        print(f"✅ Successfully converted {filename}")
                        
                    finally:
                        # Clean up temporary files
                        try:
                            os.unlink(temp_heic.name)
                            os.unlink(temp_jpg.name)
                        except OSError:
                            pass  # Ignore cleanup errors
                            
        except Exception as e:
            error_msg = f"Error converting {s3_uri}: {str(e)}"
            results['errors'].append(error_msg)
            results['failed_files'].append(s3_uri)
            results['failed_conversions'] += 1
            print(f"❌ {error_msg}")
    
    return results


def convert_images_from_bucket(bucket_name: str, prefix: str = "images/nylon_coffee_bags/") -> Dict[str, Any]:
    """
    Convenience function to convert all HEIC images from a specific S3 bucket prefix.
    
    Args:
        bucket_name: S3 bucket name
        prefix: S3 prefix to search for HEIC files
    
    Returns:
        Dictionary with conversion results
    """
    # Import s3_helper to get file list
    from .s3_helper import s3_helper
    
    # Get list of files from S3
    files = s3_helper(bucket_name, prefix)
    
    # Filter for HEIC files and convert to S3 URIs
    heic_files = [f for f in files if f.lower().endswith('.heic')]
    s3_uris = [f"s3://{bucket_name}/{file}" for file in heic_files]
    
    if not s3_uris:
        return {
            'total_files': 0,
            'successful_conversions': 0,
            'failed_conversions': 0,
            'converted_files': [],
            'failed_files': [],
            'errors': ['No HEIC files found in the specified location']
        }
    
    print(f"🔍 Found {len(s3_uris)} HEIC files to convert")
    return convert_heic_images(s3_uris)


if __name__ == "__main__":
    # Test the conversion function
    import sys
    
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python convert_image.py <bucket_name> [prefix]")
        print("  python convert_image.py s3://bucket/path/file.heic [s3://bucket/path/file2.heic ...]")
        print("\nExamples:")
        print("  python convert_image.py kafenox-data images/nylon_coffee_bags/")
        print("  python convert_image.py s3://kafenox-data/images/nylon_coffee_bags/IMG_5905.HEIC")
        sys.exit(1)
    
    if sys.argv[1].startswith('s3://'):
        # Convert specific S3 URIs
        s3_uris = sys.argv[1:]
        print(f"🚀 Converting {len(s3_uris)} specific HEIC files...")
        results = convert_heic_images(s3_uris)
    else:
        # Convert all HEIC files from bucket/prefix
        bucket = sys.argv[1]
        prefix = sys.argv[2] if len(sys.argv) > 2 else "images/nylon_coffee_bags/"
        print(f"🚀 Converting all HEIC files from s3://{bucket}/{prefix}")
        results = convert_images_from_bucket(bucket, prefix)
    
    # Print results
    print(f"\n📊 Conversion Results:")
    print(f"  Total files: {results['total_files']}")
    print(f"  ✅ Successful: {results['successful_conversions']}")
    print(f"  ❌ Failed: {results['failed_conversions']}")
    
    if results['converted_files']:
        print(f"\n✅ Successfully converted files:")
        for file_info in results['converted_files']:
            print(f"  • {file_info['original_key']} → {file_info['converted_key']}")
    
    if results['failed_files']:
        print(f"\n❌ Failed conversions:")
        for failed_file in results['failed_files']:
            print(f"  • {failed_file}")
    
    if results['errors']:
        print(f"\n🔍 Error details:")
        for error in results['errors']:
            print(f"  • {error}")