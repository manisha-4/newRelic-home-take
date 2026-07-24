terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.53.0"
    }
  }

  backend "s3" {
     region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}
