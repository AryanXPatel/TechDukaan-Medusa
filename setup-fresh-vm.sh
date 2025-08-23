#!/bin/bash

# ===============================================
# Fresh Ubuntu VM Setup for Medusa Deployment
# ===============================================
# This script installs ALL dependencies needed for Medusa on a fresh Ubuntu VM
# Run this FIRST on any new Ubuntu VM before deployment

set -e  # Exit on any error

echo "🚀 Setting up Fresh Ubuntu VM for Medusa Deployment"
echo "===================================================="
echo "📋 This will install: Docker, Node.js, Git, and all dependencies"
echo "⏱️  Estimated time: 5-10 minutes"
echo ""

# Get VM info
echo "🔍 VM Information:"
echo "   OS: $(lsb_release -d | cut -f2)"
echo "   Kernel: $(uname -r)"
echo "   Architecture: $(uname -m)"
echo "   User: $(whoami)"
echo ""

# 1. System Update
echo "📦 Step 1: Updating system packages..."
sudo apt update && sudo apt upgrade -y
echo "   ✅ System packages updated"

# 2. Install essential packages
echo "🛠️  Step 2: Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential
echo "   ✅ Essential packages installed"

# 3. Install Docker
echo "🐳 Step 3: Installing Docker..."
# Remove old versions if they exist
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

echo "   ✅ Docker installed: $(docker --version)"
echo "   ✅ Docker Compose installed: $(docker compose version)"

# 4. Install Node.js v20
echo "📦 Step 4: Installing Node.js v20..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

echo "   ✅ Node.js installed: $(node --version)"
echo "   ✅ npm installed: $(npm --version)"

# 5. Configure Git (optional but recommended)
echo "🔧 Step 5: Git configuration..."
if ! git config --global user.name >/dev/null 2>&1; then
    echo "   📝 Setting up basic Git configuration..."
    git config --global user.name "Medusa Deployment"
    git config --global user.email "deployment@techdukaan.tech"
    git config --global init.defaultBranch main
fi
echo "   ✅ Git configured: $(git --version)"

# 6. Create deployment directory structure
echo "📁 Step 6: Creating deployment directories..."
mkdir -p ~/deployments
mkdir -p ~/logs
mkdir -p ~/backups
echo "   ✅ Directory structure created"

# 7. Set up firewall rules (basic security)
echo "🔒 Step 7: Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 9000/tcp  # Medusa backend
sudo ufw allow 7700/tcp  # MeiliSearch
sudo ufw allow 6379/tcp  # Redis
sudo ufw --force enable
echo "   ✅ Firewall configured"

# 8. Optimize system for Medusa
echo "⚡ Step 8: Optimizing system settings..."
# Increase file descriptor limits for Node.js
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize Docker
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
sudo systemctl restart docker
echo "   ✅ System optimized for production"

# 9. Create helpful aliases
echo "🔧 Step 9: Setting up helpful aliases..."
cat << 'EOF' >> ~/.bashrc

# Medusa deployment aliases
alias medusa-logs='docker-compose -f docker-compose.production.yml logs -f'
alias medusa-status='docker-compose -f docker-compose.production.yml ps'
alias medusa-restart='docker-compose -f docker-compose.production.yml restart'
alias medusa-rebuild='docker-compose -f docker-compose.production.yml build --no-cache && docker-compose -f docker-compose.production.yml up -d'
EOF
source ~/.bashrc
echo "   ✅ Helpful aliases added"

# 10. Verify installation
echo "🔍 Step 10: Verifying installation..."
echo "   Docker: $(docker --version)"
echo "   Docker Compose: $(docker compose version)"
echo "   Node.js: $(node --version)"
echo "   npm: $(npm --version)"
echo "   Git: $(git --version)"

# Test Docker without sudo
echo "   Testing Docker access..."
if docker ps >/dev/null 2>&1; then
    echo "   ✅ Docker working without sudo"
else
    echo "   ⚠️  Docker requires logout/login to work without sudo"
    echo "      Run: newgrp docker"
fi

echo ""
echo "🎉 FRESH VM SETUP COMPLETE!"
echo "============================================="
echo ""
echo "✅ Installed Successfully:"
echo "   • Docker & Docker Compose"
echo "   • Node.js v20 & npm"
echo "   • Git with basic configuration"
echo "   • Essential build tools"
echo "   • Security firewall rules"
echo "   • Performance optimizations"
echo ""
echo "🚀 Next Steps:"
echo "   1. If Docker test failed above, run: newgrp docker"
echo "   2. Run the deployment script to deploy Medusa"
echo ""
echo "💡 Helpful Commands Added:"
echo "   • medusa-logs    - View container logs"
echo "   • medusa-status  - Check container status"
echo "   • medusa-restart - Restart services"
echo "   • medusa-rebuild - Full rebuild and restart"
echo ""
echo "✨ Your VM is now ready for Medusa deployment!"
