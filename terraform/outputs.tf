output "aws_region" {
  description = "Deployment region."
  value       = var.aws_region
}

output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.main.endpoint
}

output "ecr_repository_url" {
  description = "Private ECR image repository URL."
  value       = aws_ecr_repository.api.repository_url
}

output "ecr_repository_name" {
  description = "Private ECR repository name."
  value       = aws_ecr_repository.api.name
}

output "database_admin_secret_arn" {
  description = "Secrets Manager ARN used only to bootstrap the least-privilege database role."
  value       = aws_secretsmanager_secret.database_admin.arn
}

output "database_app_secret_arn" {
  description = "Secrets Manager ARN containing the least-privilege application database credentials."
  value       = aws_secretsmanager_secret.database_app.arn
}

output "github_deploy_role_arn" {
  description = "Production-environment-only IAM role ARN for GitHub Actions deployment."
  value       = aws_iam_role.github_deploy.arn
}

output "github_build_role_arn" {
  description = "Main-branch-only IAM role ARN for publishing images to ECR."
  value       = aws_iam_role.github_build.arn
}

output "alarm_topic_arn" {
  description = "SNS topic ARN for Journal API 5xx alarms."
  value       = aws_sns_topic.api_alarm.arn
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch operations dashboard name."
  value       = aws_cloudwatch_dashboard.api.dashboard_name
}

output "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account."
  value       = aws_iam_role.alb_controller.arn
}

output "otel_collector_role_arn" {
  description = "IAM role ARN for the OpenTelemetry Collector service account."
  value       = aws_iam_role.otel_collector.arn
}



output "alb_cloudfront_security_group_id" {
  description = "Security group to attach to the ALB; inbound HTTP is restricted to CloudFront."
  value       = aws_security_group.alb_cloudfront.id
}

output "cloudfront_domain_name" {
  description = "CloudFront HTTPS hostname; null until the distribution is enabled."
  value       = try(aws_cloudfront_distribution.api[0].domain_name, null)
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID; null until the distribution is enabled."
  value       = try(aws_cloudfront_distribution.api[0].id, null)
}

output "openai_base_url" {
  description = "Configured OpenAI-compatible API base URL."
  value       = var.openai_base_url
}

output "openai_model" {
  description = "Configured model or provider deployment name."
  value       = var.openai_model
}

output "nat_gateway_public_ip" {
  description = "Single NAT gateway public IP, useful for controlled egress allow-lists."
  value       = aws_eip.nat.public_ip
}
