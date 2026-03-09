#!/bin/bash
set -e

# Redirect stdout and stderr to a log file
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Updating system and installing Docker..."
sudo yum update -y
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install Node Exporter 
echo "Installing Node Exporter..."
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
sudo mv node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
sudo useradd -rs /bin/false node_exporter

cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create local Prometheus and Grafana stack (simulating the local dev setup directly on the EC2 host for monitoring)
echo "Setting up monitoring config files..."
sudo mkdir -p /home/ec2-user/monitoring/prometheus
sudo mkdir -p /home/ec2-user/monitoring/grafana/datasources
sudo mkdir -p /home/ec2-user/monitoring/grafana/dashboards

# Prometheus Config
cat <<'EOF' > /home/ec2-user/monitoring/prometheus/prometheus.yml
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Grafana Datasource
cat <<'EOF' > /home/ec2-user/monitoring/grafana/datasources/prometheus.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://localhost:9090
    access: proxy
    isDefault: true
    version: 1
    editable: false
EOF

# Grafana Dashboard
cat <<'EOF' > /home/ec2-user/monitoring/grafana/dashboards/ec2-overview.json
{
  "title": "EC2 Host Overview",
  "panels": [
    {
      "title": "CPU Usage",
      "type": "timeseries",
      "targets": [{ "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)" }]
    },
    {
      "title": "Memory Usage",
      "type": "timeseries",
      "targets": [{ "expr": "100 * (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes" }]
    },
    {
      "title": "Disk I/O",
      "type": "timeseries",
      "targets": [{ "expr": "rate(node_disk_io_time_seconds_total[5m])" }]
    }
  ],
  "schemaVersion": 30
}
EOF

# Docker Compose for Monitoring Server
cat <<'EOF' > /home/ec2-user/monitoring/docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus
    network_mode: host
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
  grafana:
    image: grafana/grafana
    network_mode: host
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=password
volumes:
  prometheus_data:
  grafana_data:
EOF

sudo chown -R ec2-user:ec2-user /home/ec2-user/monitoring
cd /home/ec2-user/monitoring

echo "Starting monitoring stack..."
sudo /usr/local/bin/docker-compose up -d

# App Deployment
echo "Preparing to pull and run Flask application from ECR..."
# Retrieve AWS Region and Account ID dynamically
AWS_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F\" '{print $4}')
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region $AWS_REGION)
ECR_REPO_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/flask-app"

# Authenticate Docker with ECR
echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region ${AWS_REGION} | sudo docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# We loop here because the Terraform script creates the EC2 instance and ECR concurrently. 
# The user must build and push the image *after* Terraform finishes.
# By continuously checking, the EC2 instance will self-recover and deploy the app as soon as it's pushed.
echo "Waiting for Docker image to be pushed to ECR..."
until sudo docker pull ${ECR_REPO_URL}:latest; do
  echo "Image not found yet. Retrying in 30 seconds..."
  sleep 30
done

echo "Image downloaded! Starting application container..."
sudo docker run -d -p 80:80 --name flask_app --restart always ${ECR_REPO_URL}:latest
echo "User data execution completed successfully."
