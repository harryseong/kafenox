#!/usr/bin/env python3
"""
S3 Helper - Simple S3 file listing utility

This module provides a simple function to list files in S3 buckets.
"""

import boto3
from typing import List


def s3_helper(s3_bucket_name: str, s3_prefix: str = "") -> List[str]:
    """
    List files in an S3 bucket with optional prefix filtering.
    
    Args:
        s3_bucket_name: The name of the S3 bucket to search
        s3_prefix: Optional prefix to filter files (e.g., 'images/nylon_coffee_bags/')
    
    Returns:
        List of S3 object keys (file paths)
    """
    try:
        # Initialize S3 client
        s3_client = boto3.client('s3', region_name='us-east-1')
        
        # List objects with pagination support
        paginator = s3_client.get_paginator('list_objects_v2')
        page_iterator = paginator.paginate(
            Bucket=s3_bucket_name,
            Prefix=s3_prefix
        )
        
        files = []
        
        # Process all pages
        for page in page_iterator:
            if 'Contents' in page:
                for obj in page['Contents']:
                    # Skip directories (keys ending with '/')
                    if not obj['Key'].endswith('/'):
                        files.append(obj['Key'])
        
        # Sort files for consistent ordering
        files.sort()
        
        return files
        
    except Exception as e:
        print(f"Error listing S3 files: {e}")
        return []


if __name__ == "__main__":
    # Test the function
    import sys
    
    if len(sys.argv) < 2:
        print("Usage: python s3_helper.py <bucket_name> [prefix]")
        print("Example: python s3_helper.py kafenox-data images/nylon_coffee_bags/")
        sys.exit(1)
    
    bucket = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 else ""
    
    print(f"🔍 Listing files in bucket '{bucket}' with prefix '{prefix}'...")
    
    files = s3_helper(bucket, prefix)
    
    if files:
        print(f"✅ Found {len(files)} files:")
        for file in files:
            print(f"  • {file}")
    else:
        print("📭 No files found")