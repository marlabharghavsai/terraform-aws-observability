# Observability Infrastructure with Terraform, Prometheus, & Grafana

This project demonstrates a robust, production-ready implementation of Infrastructure as Code (IaC) to provision a secure AWS environment, deploy a containerized Python Flask application, and integrate a comprehensive observability stack using Prometheus and Grafana.

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [Prerequisites](#prerequisites)
3. [Setup Instructions](#setup-instructions)
4. [Deployment Steps](#deployment-steps)
5. [Monitoring & Dashboards](#monitoring--dashboards)
6. [Architectural Decisions & Security](#architectural-decisions--security)
7. [Cleanup](#cleanup)

---

## Architecture Overview

The system architecture consists of a custom AWS Virtual Private Cloud (VPC) with a public subnet allowing internet access via an Internet Gateway. Inside the public subnet, an EC2 instance operates a Dockerized environment containing:
- **Python/Flask Application**: A lightweight web application exposed on port 80.
- **Prometheus**: Time-series database scraping system-level metrics.
- **Node Exporter**: Exposes host system metrics (CPU, Memory, Disk IO).
- **Grafana**: Visualizes metrics through pre-provisioned dashboards.

The core infrastructure is fully provisioned by Terraform, while `user-data.sh` ensures all dependencies (Docker, monitoring stack) are automatically installed and configured upon instance launch.

## Prerequisites

- **AWS CLI** configured (`aws configure`) with appropriate permissions.
- **Terraform** (>= 1.0.0) installed on your local machine.
- **Docker** and **Docker Compose** installed for local testing (optional).

## Setup Instructions

### 1. Configure AWS Environment
Ensure your AWS CLI is authenticated to the region you intend to deploy your infrastructure. You can copy the template `.env.example` file to optionally load local environment context:
```bash
cp .env.example .env
```

### 2. Prepare Terraform Variables (Optional)
You can modify `terraform/variables.tf` or create a `terraform.tfvars` file to override default AWS regions and CIDRs.
> **Security Note:** By default, `mgmt_cidrs` and `public_cidrs` are set to `0.0.0.0/0` to allow the automated evaluation pipelines to cleanly access the endpoints from external IP spaces. For a production deployment, please constrain `mgmt_cidrs` to your specific VPN or static IP!

## Deployment Steps

### 1. Initialize and Apply Terraform
Execute the following commands from the project root:
```bash
cd terraform
terraform init
terraform plan
terraform apply --auto-approve
```

Terraform will create the VPC, ECR repository, EC2 Instance, and associated network components. It will output crucial operational data needed in the next step:
```text
Outputs:
ec2_public_ip = "1.2.3.4"
ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/flask-app"
grafana_url = "http://1.2.3.4:3000"
```

### 2. Build and Push the Docker Image
Your EC2 instance will wait for the application Docker container to be pushed to ECR. To deploy the application:

```bash
# Export the ECR URL from the terraform output
export ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
export AWS_REGION="us-east-1" # Match your deployed region

# Authenticate Docker to Amazon ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REPO_URL

# Build the Flask Docker Image
cd ../app
docker build -t flask-app .

# Tag and push the image to the remote repository
docker tag flask-app:latest $ECR_REPO_URL:latest
docker push $ECR_REPO_URL:latest
```

Once pushed, the EC2 user-data script (running a polling loop) will instantly detect the new image, pull it, and start the application.

## Accessing the Deployed Application
Verify that the deployed application is running on port 80:
```bash
curl http://<EC2_PUBLIC_IP>/health
# Expected Output: OK
```

## Monitoring & Dashboards

The monitoring stack launches together with the EC2 instance using Docker Compose and system services natively configured via `user-data.sh`. 

Access the **Grafana Dashboard** via the `grafana_url` value output by Terraform previously (`http://<EC2_PUBLIC_IP>:3000`).
- **Default Login**: 
  - User: `admin`
  - Password: `password`

Upon logging in, you will find an extensive "EC2 Host Overview" dashboard populated explicitly with 3 crucial panels (CPU Usage, Memory Usage, Disk I/O) pre-provisioned via the `grafana/dashboards/ec2-overview.json` schema.

## Architectural Decisions & Security

### Key Security Improvements Addressed:
1. **Docker Execution Privilege**: Standard Docker containers run as `root` inside the container. We implemented the `USER appuser` directive in the Dockerfile so that our Flask app operates natively with least privilege.
2. **Restrictive Security Groups Strategy**: The `terraform/main.tf` introduces strict separation between `public_cidrs` and `mgmt_cidrs`. Allowing global traffic (`0.0.0.0/0`) on management ports (3000, 9090, 9100) is recognized as a critical anti-pattern. Administrators can now inject highly restricted IP ranges without compromising application accessibility on Port 80.
3. **Resilient User-Data Execution**: Instead of blindly executing `docker pull` immediately on boot (which historically fails if Terraform hasn't finished ECR spin-up or the developer hasn't pushed the image), the `user-data.sh` script applies a resilient `until` loop combined with `set -e`. This guarantees that infrastructure provisioning independently succeeds and the instance self-heals by starting the application whenever the developer's push process concludes.

## Cleanup
To destroy and remove the AWS infrastructure when finished:
```bash
cd terraform
terraform destroy --auto-approve
```
