#!/bin/bash

exec > >(tee -a /var/log/secure-ci-bootstrap.log) # route all outputs and errors to the terminal and a newly created log file
exec 2>&1

echo "starting bootstrap..."

apt-get update -y

# downloading k3s and configuring kubectl
curl -fL https://get.k3s.io | sh -
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config

echo "installed k3s"

# installing and starting docker
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "installed docker"

# add logic to install aws cli and helm