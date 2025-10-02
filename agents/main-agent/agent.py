import sys
import os
from strands import Agent, tool
from strands.models import BedrockModel
from typing import List

# Add the parent directory to the path to import tools
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.s3_helper import s3_helper as s3_helper_func


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


# bedrock_model_id="anthropic.claude-3-7-sonnet-20250219-v1:0"
bedrock_model_id="us.anthropic.claude-3-7-sonnet-20250219-v1:0"

# Create a Bedrock model instance
bedrock_model = BedrockModel(
    model_id=bedrock_model_id,
    temperature=0.3,
    top_p=0.8,
)

# Create an agent using the BedrockModel instance with S3 helper tool
agent = Agent(
    model=bedrock_model,
    tools=[s3_helper],
    system_prompt="""You are an AI assistant with access to S3 bucket exploration capabilities.

You have access to the 's3_helper' tool which can list files in S3 buckets with optional prefix filtering.

When users ask about S3 contents:
1. Use the s3_helper tool with the appropriate bucket name and prefix
2. Provide clear information about the files found
3. Organize the results in a helpful way
4. Answer follow-up questions about the file structure

Be helpful and provide useful insights about S3 bucket contents."""
)

# Interactive mode
if __name__ == "__main__":
    print("🤖 S3 Explorer Agent initialized!")
    print("💡 Ask me about S3 bucket contents!")
    print("🔧 Available tools: s3_helper")
    print("📝 Example: 'List files in kafenox-data bucket'")
    print("🛑 Type 'quit' to exit\n")
    
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
