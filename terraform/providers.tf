provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project       = "kafenox"
      Environment   = var.environment
      Automation    = "Terraform"
      AutomationKey = "kafenox"
    }
  }
}
