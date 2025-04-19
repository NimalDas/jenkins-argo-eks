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

# Output ECR Repository URI
output "ecr_repository_url" {
  value = aws_ecr_repository.nodejs_app.repository_url
}
