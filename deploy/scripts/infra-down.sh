#!/usr/bin/env bash
set -e

# Navigate to the terraform directory
cd "$(dirname "$0")/../terraform"

# Destroy the Terraform-managed infrastructure
terraform destroy -auto-approve
