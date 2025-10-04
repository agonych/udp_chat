#!/usr/bin/env bash
set -e

# Navigate to the terraform directory
cd "$(dirname "$0")/../terraform"

# Initialize and apply the Terraform configuration
terraform init -upgrade
terraform apply -auto-approve
