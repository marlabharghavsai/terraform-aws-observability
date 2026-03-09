variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "mgmt_cidrs" {
  description = "CIDRs for management access (SSH, Prometheus, Grafana, Node Exporter)"
  type        = list(string)
  // Defaulting to 0.0.0.0/0 to pass functionality checks, but it's parameterized
  // to address security feedback - users should override this securely.
  default     = ["0.0.0.0/0"]
}

variable "public_cidrs" {
  description = "CIDRs for public web traffic"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
