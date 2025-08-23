#!/bin/bash

# =====================================================================
# 🔧 Fresh Ubuntu VM Setup for TechDukaan Medusa Deployment
# =====================================================================
# Enhanced version of the original setup script with additional features:
# - Better error handling and logging
# - Performance optimizations for Medusa
# - Security configurations
# - Development tools setup

set -e  # Exit on any error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'
BOLD='\033[1m'

print_step() {
    echo -e "\n${BLUE}${BOLD}🔧 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step "Fresh Ubuntu VM Setup for TechDukaan Medusa Deployment"
echo "============================================================="
echo "📋 Installing: Docker, Node.js, Git, and production dependencies"
echo "⏱️  Estimated time: 5-10 minutes"
echo "🎯 Optimized for Medusa v2.8.x production deployment"
echo ""

# Get system information
echo "🔍 System Information:"
echo "   OS: $(lsb_release -d | cut -f2)"
echo "   Kernel: $(uname -r)"
echo "   Architecture: $(uname -m)"
echo "   User: $(whoami)"
echo "   Memory: $(free -h | awk 'NR==2{printf \"%.1fGB\", $2/1024}')"
echo "   Disk: $(df -h / | awk 'NR==2{print $4}' | sed 's/G/ GB/')"
echo ""

# 1. System Update
print_step "Step 1: Updating system packages"
sudo apt update && sudo apt upgrade -y
print_success "System packages updated"

# 2. Install essential packages
print_step "Step 2: Installing essential development packages"
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
    build-essential \
    vim \
    htop \
    tree \
    jq \
    zip \
    ufw \
    fail2ban
print_success "Essential packages installed"

# 3. Install Docker
print_step "Step 3: Installing Docker Engine"

# Remove old Docker versions
sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker for production
sudo mkdir -p /etc/docker
cat << EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "dns": ["8.8.8.8", "8.8.4.4"],
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 5
}
EOF

# Add user to docker group and configure service
sudo usermod -aG docker $USER
sudo systemctl start docker
sudo systemctl enable docker

print_success "Docker installed: $(docker --version)"
print_success "Docker Compose installed: $(docker compose version)"

# 4. Install Node.js v20 (LTS)
print_step "Step 4: Installing Node.js v20 LTS"
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Install global packages for development
sudo npm install -g npm@latest
sudo npm install -g yarn
sudo npm install -g pnpm

print_success "Node.js installed: $(node --version)"
print_success "npm installed: $(npm --version)"
print_success "yarn installed: $(yarn --version)"
print_success "pnpm installed: $(pnpm --version)"

# 5. Configure Git
print_step "Step 5: Configuring Git for deployment"
if ! git config --global user.name >/dev/null 2>&1; then
    git config --global user.name "TechDukaan Deployment"
    git config --global user.email "deployment@techdukaan.tech"
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.autocrlf input
fi
print_success "Git configured: $(git --version)"

# 6. Create deployment directory structure
print_step "Step 6: Creating deployment directory structure"
mkdir -p ~/deployments
mkdir -p ~/logs
mkdir -p ~/backups
mkdir -p ~/scripts
mkdir -p ~/.ssh

# Set proper permissions
chmod 755 ~/deployments ~/logs ~/backups ~/scripts
chmod 700 ~/.ssh

print_success "Directory structure created"

# 7. Configure firewall and security
print_step "Step 7: Configuring security and firewall"

# Configure UFW firewall
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 9000/tcp comment 'Medusa Backend'
sudo ufw allow 7700/tcp comment 'MeiliSearch'
sudo ufw allow 6379/tcp comment 'Redis'
sudo ufw --force enable

# Configure fail2ban for SSH protection
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

print_success "Firewall configured and enabled"
print_success "Fail2ban configured for SSH protection"

# 8. System optimizations for Medusa
print_step "Step 8: Optimizing system for Medusa production"

# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "root soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "root hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Optimize kernel parameters for Node.js
cat << EOF | sudo tee -a /etc/sysctl.conf

# Medusa/Node.js optimizations
net.core.somaxconn = 65536
net.ipv4.tcp_max_syn_backlog = 65536
net.ipv4.ip_local_port_range = 1024 65535
fs.file-max = 2097152
vm.max_map_count = 262144
EOF

sudo sysctl -p

# Configure swappiness for better performance
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

print_success "System optimized for production Node.js workloads"

# 9. Install monitoring tools
print_step "Step 9: Installing monitoring and diagnostic tools"
sudo apt install -y \
    htop \
    iotop \
    nethogs \
    ncdu \
    glances

print_success "Monitoring tools installed"

# 10. Create helpful scripts and aliases
print_step "Step 10: Setting up deployment utilities"

# Create deployment aliases
cat << 'EOF' >> ~/.bashrc

# ===================================
# TechDukaan Medusa Deployment Aliases
# ===================================

# Docker management
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker-compose -f docker-compose.production.yml logs -f'
alias dstatus='docker-compose -f docker-compose.production.yml ps'
alias drestart='docker-compose -f docker-compose.production.yml restart'
alias dstop='docker-compose -f docker-compose.production.yml down'
alias dstart='docker-compose -f docker-compose.production.yml up -d'
alias drebuild='docker-compose -f docker-compose.production.yml build --no-cache && docker-compose -f docker-compose.production.yml up -d'

# Medusa management
alias medusa-logs='docker-compose -f docker-compose.production.yml logs -f medusa-server'
alias medusa-exec='docker-compose -f docker-compose.production.yml exec medusa-server bash'
alias medusa-cli='docker-compose -f docker-compose.production.yml exec medusa-server npx medusa'

# System monitoring
alias sysinfo='echo "=== CPU ===" && lscpu | grep "Model name" && echo "=== Memory ===" && free -h && echo "=== Disk ===" && df -h / && echo "=== Load ===" && uptime'
alias ports='netstat -tulpn | grep LISTEN'
alias processes='ps aux --sort=-%cpu | head -10'

# Navigation
alias cdmedusa='cd ~/medusa-deployment/medusa-backend'
alias cdlogs='cd ~/logs'

# Git shortcuts for deployment
alias gst='git status'
alias gpl='git pull'
alias glog='git log --oneline -10'

EOF

# Create system monitoring script
cat << 'EOF' > ~/scripts/system-status.sh
#!/bin/bash
echo "=== TechDukaan Medusa System Status ==="
echo "Date: $(date)"
echo ""
echo "=== System Info ==="
echo "Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F', load' '{print $1}')"
echo "Load: $(uptime | awk -F'load average: ' '{print $2}')"
echo "Memory: $(free -h | awk 'NR==2{printf "Used: %s/%s (%.1f%%)", $3,$2,$3*100/$2}')"
echo "Disk: $(df -h / | awk 'NR==2{printf "Used: %s/%s (%s)", $3,$2,$5}')"
echo ""
echo "=== Docker Services ==="
if command -v docker &> /dev/null; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not running"
else
    echo "Docker not installed"
fi
echo ""
echo "=== Network Ports ==="
netstat -tulpn | grep LISTEN | grep -E ':(9000|7700|6379)' || echo "No Medusa services detected"
EOF

chmod +x ~/scripts/system-status.sh

print_success "Deployment utilities and aliases created"

# 11. Final verification
print_step "Step 11: Verifying installation"

echo "📊 Installation Verification:"
echo "   ✅ Docker: $(docker --version)"
echo "   ✅ Docker Compose: $(docker compose version)"
echo "   ✅ Node.js: $(node --version)"
echo "   ✅ npm: $(npm --version)"
echo "   ✅ Git: $(git --version)"
echo "   ✅ UFW Status: $(sudo ufw status | head -1)"

# Test Docker access
echo ""
echo "🔍 Testing Docker access..."
if docker ps >/dev/null 2>&1; then
    print_success "Docker working without sudo"
else
    print_warning "Docker requires logout/login to work without sudo"
    print_warning "Run: newgrp docker"
fi

# System resources check
echo ""
echo "📈 System Resources:"
echo "   Memory: $(free -h | awk 'NR==2{printf "Total: %s, Available: %s", $2,$7}')"
echo "   Disk Space: $(df -h / | awk 'NR==2{printf "Total: %s, Available: %s", $2,$4}')"
echo "   CPU Cores: $(nproc)"

echo ""
print_success "FRESH VM SETUP COMPLETE!"
echo "========================================="
echo ""
echo "✅ Successfully Installed:"
echo "   • Docker Engine & Docker Compose"
echo "   • Node.js v20 LTS with npm, yarn, pnpm"
echo "   • Git with deployment configuration"
echo "   • Essential development tools"
echo "   • Security firewall and fail2ban"
echo "   • System optimizations for Medusa"
echo "   • Monitoring and diagnostic tools"
echo "   • Deployment aliases and utilities"
echo ""
echo "🚀 Next Steps:"
echo "   1. If Docker test failed: run 'newgrp docker' or logout/login"
echo "   2. Run deployment script to install Medusa"
echo "   3. Use '~/scripts/system-status.sh' to monitor system"
echo ""
echo "💡 Useful Commands:"
echo "   • Check status: ~/scripts/system-status.sh"
echo "   • Monitor system: htop"
echo "   • Check ports: ports"
echo "   • Go to deployment: cdmedusa"
echo ""
print_success "VM is ready for TechDukaan Medusa deployment!"

echo ""
echo "🔄 Refreshing shell environment..."
source ~/.bashrc
