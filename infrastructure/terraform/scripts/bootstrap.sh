#!/bin/bash

exec > >(tee -a /var/log/secure-ci-bootstrap.log) # route all outputs and errors to the terminal and a newly created log file
exec 2>&1

echo "starting bootstrap..."

apt-get update -y
apt-get install -y ca-certificates curl gnupg git unzip

# installing and starting docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu noble stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

echo "installed docker"

# Installing aws cli

cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
./aws/install
echo "Installed AWS CLI"

# installing helm

curl -fSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
echo "Installed Helm"

# Install k3s
curl -sfL https://get.k3s.io | sh -

# Wait for kubeconfig to exist
while [ ! -f /etc/rancher/k3s/k3s.yaml ]; do
  sleep 2
done

# Configure kubectl for ubuntu user
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config

# Make kubectl always use this config
grep -qxF 'export KUBECONFIG=$HOME/.kube/config' /home/ubuntu/.bashrc || \
  echo 'export KUBECONFIG=$HOME/.kube/config' >> /home/ubuntu/.bashrc

# download github repo

mkdir -p /home/ubuntu/projects
cd /home/ubuntu/projects
sudo chown ubuntu:ubuntu /home/ubuntu/projects
git clone https://github.com/MantavyaS/secure-self-hosted-ci-platform.git
chown -R ubuntu:ubuntu /home/ubuntu/projects/secure-self-hosted-ci-platform
sudo -u ubuntu KUBECONFIG=/home/ubuntu/.kube/config kubectl create namespace nginx-test-n || true
sudo -u ubuntu KUBECONFIG=/home/ubuntu/.kube/config kubectl apply -f /home/ubuntu/projects/secure-self-hosted-ci-platform/kubernetes/nginx-test/nginx-dep.yaml
sudo -u ubuntu KUBECONFIG=/home/ubuntu/.kube/config kubectl apply -f /home/ubuntu/projects/secure-self-hosted-ci-platform/kubernetes/nginx-test/nginx-ingress.yaml

echo "Bootstrap Complete"

