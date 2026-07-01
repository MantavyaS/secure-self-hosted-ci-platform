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

# installing aws cli

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
-o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

echo "Installed aws cli"

# installing helm

curl -fSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
echo "Installed Helm"

# Install k3s
curl -sfL https://get.k3s.io | sh -
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

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

# wait for k3s to be installed and ready
until kubectl get nodes; do
  sleep 5
done

# Get the contents of the pem file from secrets manager
aws secretsmanager get-secret-value \
  --secret-id "${github_secret_id}" \
  --query SecretString \
  --output text > /tmp/github-app.pem
chmod 600 /tmp/github-app.pem

# create a namespace for the arc runner controller and install it using helm
helm install arc --namespace="arc-systems" \
  --create-namespace \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# create a namespace for the arc runner set and define variables and secrets
kubectl create namespace arc-runners
kubectl create secret generic pre-defined-secret \
  --namespace=arc-runners \
  --from-literal=github_app_id="${github_app_id}" \
  --from-literal=github_app_installation_id="${github_app_installation_id}" \
  --from-file=github_app_private_key=/tmp/github-app.pem

# install the arc runner set
helm install "arc-runner-set" \
  --namespace "arc-runners" \
  -f /home/ubuntu/projects/secure-self-hosted-ci-platform/helm/values.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

echo "Bootstrap Complete"