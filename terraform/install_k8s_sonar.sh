#!/bin/bash

# Add 4GB Swap (Essential for SonarQube on t3.micro)
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# 1. System Config for SonarQube (Elasticsearch requirement)
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# 2. Install Docker
sudo apt update -y
sudo apt install -y docker.io
sudo usermod -aG docker ubuntu
sudo chmod 666 /var/run/docker.sock

# 3. Run SonarQube (Docker)
# Runs on port 9000. Default user/pass: admin/admin
docker run -d --name sonarqube --restart always -p 9000:9000 sonarqube:community

# 4. Install K3s (Lightweight Kubernetes)
# We add the AWS Public IP to the TLS SAN so you can access it remotely (e.g., from Jenkins)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --tls-san ${PUBLIC_IP} --write-kubeconfig-mode 644" sh -

# 5. Prepare Kubeconfig for the user
# Copy config to /home/ubuntu/kubeconfig for easy download
mkdir -p /home/ubuntu/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/kubeconfig
sudo chown ubuntu:ubuntu /home/ubuntu/kubeconfig
sudo chmod 644 /home/ubuntu/kubeconfig

# Replace localhost with Public IP in the config file so it works remotely
sed -i "s/127.0.0.1/${PUBLIC_IP}/g" /home/ubuntu/kubeconfig

# Install Helm (Optional but useful)
snap install helm --classic
