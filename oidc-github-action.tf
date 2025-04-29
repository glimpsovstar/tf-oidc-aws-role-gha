# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2" # Change to your desired region
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "glimpsovstar" # Replace with your GitHub organization
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "pkr-RHEL9-SOE" # Replace with your GitHub repository
}

# Data source to get the TLS certificate thumbprint for GitHub's OIDC provider
data "tls_certificate" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"
}

# Create the OIDC identity provider
resource "aws_iam_openid_connect_provider" "github_oidc" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github_oidc.certificates[0].sha1_fingerprint]
}

# IAM policy document for the assume role policy
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_oidc.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/*"] # Restrict to your repo
    }
  }
}

# Create the IAM role for GitHub Actions
resource "aws_iam_role" "github_actions_role" {
  name               = "GitHubActionsRole"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Attach a policy to the role (example: EC2 full access for Packer)
resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Output the role ARN for use in GitHub Actions
output "role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "ARN of the IAM role for GitHub Actions"
}