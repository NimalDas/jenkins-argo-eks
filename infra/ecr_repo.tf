# ECR Repository for Node.js App
resource "aws_ecr_repository" "nodejs_app" {
  name                 = "nodejs-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# ECR Lifecycle Policy to Keep Last 10 Images
resource "aws_ecr_lifecycle_policy" "nodejs_app_policy" {
  repository = aws_ecr_repository.nodejs_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository for Jenkins Agent Images
resource "aws_ecr_repository" "jenkins_agents" {
  name                 = "jenkins-agents"
  image_tag_mutability = "MUTABLE" # Or IMMUTABLE if you prefer

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
    ManagedBy   = "Jenkins" # Optional: tag to indicate purpose
  }
}

# Optional: Lifecycle Policy for Jenkins Agents ECR (e.g., keep last few images)
resource "aws_ecr_lifecycle_policy" "jenkins_agents_policy" {
  repository = aws_ecr_repository.jenkins_agents.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images for Jenkins Agents"
        selection = {
          tagStatus  = "any"
          countType  = "imageCountMoreThan"
          countNumber = 5 # Adjust as needed
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# --- IAM Policy for Jenkins ECR Access ---
resource "aws_iam_policy" "jenkins_ecr_policy" {
  # Using a dynamic name based on account ID
  name        = "JenkinsECRPushPolicy"
  description = "Allows Jenkins Service Account to push and pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchDeleteImage", # Optional: Allows Jenkins to clean up old images
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:CreateRepository" # Optional: Allows Jenkins to create the ECR repo if it doesn't exist
        ],
        Resource = [
          aws_ecr_repository.nodejs_app.arn,
          aws_ecr_repository.jenkins_agents.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*" # GetAuthorizationToken does not support resource-level permissions
      },
    ],
  })
}

# --- IAM Role for Jenkins Service Account with OIDC Trust Policy ---
resource "aws_iam_role" "jenkins_ecr_role" {
  # Using a dynamic name based on cluster name
  name        = "JenkinsECRPushRole-${module.eks.cluster_name}"
  description = "IAM role for Jenkins Service Account (jenkins in jenkins namespace) to push to ECR"

  # Use the existing EKS OIDC provider data source for the assume role policy
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          # Use the ARN from the existing OIDC provider data source
          Federated = data.aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Use the URL from the existing EKS module output or data source
            # Ensure this matches the format expected by AWS (without https://)
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:aud" : "sts.amazonaws.com",
            # --- Targeting the 'jenkins' Service Account in the 'jenkins' namespace ---
            "${trimprefix(module.eks.cluster_oidc_issuer_url, "https://")}:sub" : "system:serviceaccount:jenkins:jenkins"
          }
        }
      },
    ],
  })

  # Attach the ECR policy to this role
  # Using aws_iam_role_policy_attachment for clarity
}

# --- Attach the ECR Policy to the Jenkins IAM Role ---
resource "aws_iam_role_policy_attachment" "jenkins_ecr_policy_attach" {
  role       = aws_iam_role.jenkins_ecr_role.name
  policy_arn = aws_iam_policy.jenkins_ecr_policy.arn
}


resource "kubernetes_annotations" "jenkins_service_account_irsa" {
  api_version = "v1"
  kind        = "ServiceAccount"

  metadata {
    namespace = "jenkins"
    name      = "jenkins" 
  }
  annotations = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.jenkins_ecr_role.arn
  }

}

# Output the Jenkins ECR Role ARN for verification ---
output "jenkins_ecr_role_arn" {
  description = "ARN of the IAM role for Jenkins ECR access"
  value       = aws_iam_role.jenkins_ecr_role.arn
}
# Output ECR Repository URI
output "ecr_repository_url" {
  value = aws_ecr_repository.nodejs_app.repository_url
}
