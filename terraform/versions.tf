terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # EKS module v21 requires provider >= 6.52.0, so this cannot go back to 5.x
      # without also downgrading that module off its access-entry support.
      version = "~> 6.52"
    }
  }
}

provider "aws" {
  region = var.region
}
