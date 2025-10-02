import sys
import os
from strands import Agent, tool
from strands.models import BedrockModel
from typing import List, Dict, Any

# Add the parent directory to the path to import tools
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.s3_helper import s3_helper as s3_helper_func
from tools.convert_image import convert_heic_images, convert_images_from_bucket
from tools.analyze_image import analyze_image


# Create a Strands tool from the s3_helper function
@tool
def s3_helper(s3_bucket_name: str, s3_prefix: str = "") -> List[str]:
    """
    List files in an S3 bucket with optional prefix filtering.
    
    Args:
        s3_bucket_name: The name of the S3 bucket to search
        s3_prefix: Optional prefix to filter files (e.g., 'images/nylon_coffee_bags/')
    
    Returns:
        List of S3 object keys (file paths)
    """
    return s3_helper_func(s3_bucket_name, s3_prefix)


# Create a Strands tool from the convert_heic_images function
@tool
def convert_images(s3_uris: List[str]) -> Dict[str, Any]:
    """
    Convert HEIC images from S3 URIs to JPG format and upload to processed folder.
    
    Args:
        s3_uris: List of S3 URIs pointing to HEIC image files
                Example: ['s3://kafenox-data/images/nylon_coffee_bags/IMG_5905.HEIC']
    
    Returns:
        Dictionary with conversion results including success/failure counts and details
    """
    return convert_heic_images(s3_uris)


# Create a Strands tool from the convert_images_from_bucket function
@tool
def convert_bucket_images(s3_bucket_name: str, s3_prefix: str = "images/nylon_coffee_bags/") -> Dict[str, Any]:
    """
    Convert all HEIC images from a specific S3 bucket prefix to JPG format.
    
    Args:
        s3_bucket_name: S3 bucket name
        s3_prefix: S3 prefix to search for HEIC files (default: 'images/nylon_coffee_bags/')
    
    Returns:
        Dictionary with conversion results including success/failure counts and details
    """
    return convert_images_from_bucket(s3_bucket_name, s3_prefix)


# Create a Strands tool from the analyze_image function
@tool
def analyze_image_tool(s3_bucket_name: str, s3_object: str) -> Dict[str, Any]:
    """
    Download a HEIC image from S3, convert it to JPEG, compress it to under 200KB, 
    and prepare it for Claude Sonnet 3.7 vision analysis.
    
    Args:
        s3_bucket_name: The name of the S3 bucket containing the image
        s3_object: The S3 object key (path) to the HEIC image file
    
    Returns:
        Dictionary containing image data formatted for Claude Sonnet 3.7 analysis
    """
    return analyze_image(s3_bucket_name, s3_object)


# bedrock_model_id="anthropic.claude-3-7-sonnet-20250219-v1:0"
bedrock_model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0"

# Create a Bedrock model instance
bedrock_model = BedrockModel(
    model_id=bedrock_model_id,
    temperature=0.3,
    top_p=0.8,
)

# Create an agent using the BedrockModel instance with S3, image conversion, and analysis tools
agent = Agent(
    model=bedrock_model,
    tools=[s3_helper, convert_images, convert_bucket_images, analyze_image_tool],
    system_prompt="""You are an AI assistant with access to S3 bucket exploration, image conversion, and image analysis capabilities.

You have access to these tools:
1. 's3_helper' - List files in S3 buckets with optional prefix filtering
2. 'convert_images' - Convert specific HEIC images to JPG format using S3 URIs
3. 'convert_bucket_images' - Convert all HEIC images from a bucket prefix to JPG format
4. 'analyze_image_tool' - Download JPG images from S3 and prepare them for Claude vision analysis

When users ask about S3 contents:
- Use the s3_helper tool with the appropriate bucket name and prefix
- Provide clear information about the files found
- Organize the results in a helpful way

When users ask about image conversion:
- Use convert_images for specific files (requires S3 URIs)
- Use convert_bucket_images to convert all HEIC files from a bucket/prefix
- Explain the conversion process and results clearly
- Converted images are saved to 'images/nylon_coffee_bags/processed/jpg/' prefix

When users ask about image analysis:
- Use analyze_image_tool to prepare HEIC images for Claude Sonnet 3.7 vision analysis
- Automatically converts HEIC to JPEG format and compresses to under 200KB
- Images are resized and optimized for Claude Sonnet 3.7 processing
- Provide insights about image content, colors, text, objects, and design elements

You can combine these tools for complete workflows:
- List files → Analyze HEIC images directly (no conversion needed)
- Find specific HEIC images → Prepare for analysis → Describe contents
- Convert HEIC to JPG for storage → Analyze original HEIC files for vision tasks

Be helpful and provide useful insights about S3 bucket contents, image processing, and visual analysis capabilities."""
)

# Interactive mode
if __name__ == "__main__":
    print("🤖 S3 Explorer, HEIC Image Converter & Analyzer Agent initialized!")
    print("💡 Ask me about S3 bucket contents, HEIC image conversion, and HEIC image analysis!")
    print("🔧 Available tools: s3_helper, convert_images, convert_bucket_images, analyze_image_tool")
    print("📝 Examples:")
    print("  • 'List files in kafenox-data bucket'")
    print("  • 'Convert all HEIC images in nylon coffee bags folder'")
    print("  • 'Analyze the HEIC image images/nylon_coffee_bags/IMG_5905.heic'")
    print("  • 'Describe what you see in the coffee bag image IMG_5906.heic'")
    print("  • 'Process and analyze all HEIC images in the bucket'")

    
    while True:
        try:
            user_input = input("Your question: ").strip()
            
            if user_input.lower() in ['quit', 'exit', 'q']:
                print("👋 Goodbye!")
                break
            
            if not user_input:
                continue
            
            print("🤔 Processing...")
            response = agent(user_input)
            print(f"🤖 Agent: {response}\n")
            
        except KeyboardInterrupt:
            print("\n👋 Goodbye!")
            break
        except Exception as e:
            print(f"❌ Error: {e}")
            print("💡 Please check your AWS credentials and try again\n")
