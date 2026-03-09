output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.app_repo.repository_url
}

output "grafana_url" {
  description = "The URL to access the Grafana dashboard"
  value       = "http://${aws_instance.web.public_ip}:3000"
}
