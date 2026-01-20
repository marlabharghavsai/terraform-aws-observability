#!/bin/bash
set -e

yum update -y
yum install docker -y
systemctl start docker
systemctl enable docker

# Node Exporter
useradd --no-create-home node_exporter
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xvf node_exporter-*.tar.gz
mv node_exporter*/node_exporter /usr/local/bin/
node_exporter &
