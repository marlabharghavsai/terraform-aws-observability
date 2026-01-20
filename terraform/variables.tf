variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "my_ip" {
  description = "Your public IP with /32 for SSH access"
}
