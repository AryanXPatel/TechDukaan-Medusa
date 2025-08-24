# TechDukaan - Medusa E-commerce Platform

A production-ready e-commerce platform built with Medusa v2.8.8, featuring automated deployment scripts and comprehensive Docker Compose orchestration.

> **Production Status**: ✅ **Currently deployed and operational** on Azure VM with Docker Compose V2

## 🚀 Features

- **Medusa v2.8.8 Backend** - Latest stable headless e-commerce engine with integrated admin
- **Redis Caching** - High-performance session and data caching
- **Meilisearch** - Fast and relevant product search engine
- **Azure PostgreSQL** - Scalable cloud database with 12-month retention
- **Docker Compose V2** - Modern containerization with health checks
- **Automated Deployment** - Tested one-command setup across multiple scenarios
- **Production Hardened** - Security best practices and monitoring

## 📋 Prerequisites

### System Requirements

- **OS**: Ubuntu 22.04 LTS or newer
- **RAM**: Minimum 4GB (8GB recommended for production)
- **Storage**: 20GB free space
- **Network**: Internet access for package installation

### Required Software

- **Docker Engine**: Latest version with Compose V2 plugin
- **Git**: For repository cloning
- **curl**: For health checks and downloads

### Access Requirements

- SSH access to deployment server
- Azure PostgreSQL credentials (for existing database scenarios)
- GitHub repository access

## 🔧 **Azure Platform Prerequisites**

**⚠️ CRITICAL: Complete ALL Azure setup steps BEFORE cloning the repository!**

This ensures smooth deployment without mid-process Azure configuration failures.

### Step 1: Configure VM Inbound Port Rules

Your Azure VM needs specific ports open for TechDukaan services to be accessible.

**Required Ports:**

- **Port 22**: SSH access (usually already configured)
- **Port 9000**: Medusa API + Admin Interface (REQUIRED)
- **Port 7700**: MeiliSearch (optional, for debugging)
- **Port 6379**: Redis (optional, for debugging)

**Azure Portal Configuration:**

1. Go to **Azure Portal**
2. Navigate to: **Virtual Machines** > **[your-vm-name]**
3. Go to **Settings** > **Networking**
4. Click **Add inbound port rule**
5. Add each required port:

   **For Port 9000 (Medusa - REQUIRED):**

   - **Source**: Any
   - **Source port ranges**: \*
   - **Destination**: Any
   - **Destination port ranges**: 9000
   - **Protocol**: TCP
   - **Action**: Allow
   - **Priority**: 1000
   - **Name**: `Allow-Medusa-9000`

   **For Port 7700 (MeiliSearch - Optional):**

   - **Destination port ranges**: 7700
   - **Name**: `Allow-MeiliSearch-7700`
   - **Priority**: 1010

   **For Port 6379 (Redis - Optional):**

   - **Destination port ranges**: 6379
   - **Name**: `Allow-Redis-6379`
   - **Priority**: 1020

6. Click **Add** for each rule

**Alternative: Azure CLI**

```bash
# Get your resource group and VM name
az vm list --output table

# Add port 9000 (required)
az vm open-port --resource-group [your-rg] --name [your-vm] --port 9000 --priority 1000

# Add port 7700 (optional)
az vm open-port --resource-group [your-rg] --name [your-vm] --port 7700 --priority 1010

# Add port 6379 (optional)
az vm open-port --resource-group [your-rg] --name [your-vm] --port 6379 --priority 1020
```

### Step 2: Configure Azure PostgreSQL Firewall

**Get Your VM's External IP:**

```bash
# SSH into your VM and run:
curl ifconfig.me
# Note this IP address - you'll need it for firewall rules
```

**Add VM IP to PostgreSQL Firewall:**

**Option 1: Azure Portal (Recommended)**

1. Go to **Azure Portal**
2. Navigate to: **Azure Database for PostgreSQL flexible servers**
3. Select your database: `psql-techdukaan-prod`
4. Go to **Settings** > **Networking**
5. Under **Firewall rules**, click **+ Add current client IP address**
6. Or manually add rule:
   - **Rule name**: `VM-TechDukaan-Access`
   - **Start IP**: `[your-vm-ip]` (e.g., 20.198.176.252)
   - **End IP**: `[your-vm-ip]` (same as start IP)
7. Click **Save**

**Option 2: Azure CLI**

```bash
# Add firewall rule for your VM
az postgres flexible-server firewall-rule create \
  --resource-group [your-resource-group] \
  --name psql-techdukaan-prod \
  --rule-name VM-TechDukaan-Access \
  --start-ip-address [your-vm-ip] \
  --end-ip-address [your-vm-ip]
```

### Step 3: Verify Azure Storage Account Access

Ensure your Azure Storage account is accessible and you have the access key.

**Get Storage Account Key:**

1. Go to **Azure Portal**
2. Navigate to: **Storage Accounts** > **sttechdukaanprod**
3. Go to **Security + networking** > **Access keys**
4. Copy either **key1** or **key2** (you'll need this for .env.production)

### Step 4: Test Azure Connectivity

**Test VM Port Access:**

```bash
# From another machine, test if port 9000 is accessible
# Replace [your-vm-ip] with actual VM IP
telnet [your-vm-ip] 9000

# Should connect (even if it immediately closes, connection success means port is open)
```

**Test PostgreSQL Connection:**

```bash
# SSH into your VM and test database connection
psql "postgres://[username]:[password]@psql-techdukaan-prod.postgres.database.azure.com:5432/postgres?sslmode=require"

# Should connect successfully without errors
# Type \q to exit
```

### ✅ Azure Prerequisites Checklist

Before proceeding to deployment, ensure:

- [ ] VM inbound rule for port 9000 is configured and active
- [ ] VM inbound rule for port 22 (SSH) is working
- [ ] VM external IP added to PostgreSQL firewall rules
- [ ] PostgreSQL connection test successful from VM
- [ ] Azure Storage account access key obtained
- [ ] VM can reach external internet (curl ifconfig.me works)

**If any test fails, fix the Azure configuration before proceeding!**

## 🌐 **Dual Subdomain SSL/Domain Configuration (Recommended)**

**Optional but highly recommended for production deployments.**

Set up professional HTTPS API endpoints with dedicated subdomains:

- **Medusa API**: `https://api.techdukaan.tech`
- **MeiliSearch**: `https://search.techdukaan.tech`

### Step 1: Configure DNS (One-time Setup)

**Add A Records for both API and Search subdomains:**

1. **Log into your domain registrar** (GoDaddy, Namecheap, etc.)
2. **Add DNS A Records:**

   ```
   Type: A
   Name: api
   Value: [Your Azure VM Public IP]
   TTL: 300 (5 minutes)

   Type: A
   Name: search
   Value: [Your Azure VM Public IP]
   TTL: 300 (5 minutes)
   ```

3. **Verify DNS propagation** (5-15 minutes):
   ```bash
   nslookup api.techdukaan.tech
   nslookup search.techdukaan.tech
   # Both should return your VM IP address
   ```

### Step 2: Configure Additional Azure Ports

**For SSL certificates, you need ports 80 and 443 open:**

**Azure Portal Method:**

1. Go to **Azure Portal** > **Virtual Machines** > **[your-vm]** > **Networking**
2. **Add these inbound port rules:**

   **Port 80 (HTTP - for SSL validation):**

   - **Destination port ranges**: 80
   - **Protocol**: TCP
   - **Action**: Allow
   - **Priority**: 1030
   - **Name**: `Allow-HTTP-80`

   **Port 443 (HTTPS - for secure traffic):**

   - **Destination port ranges**: 443
   - **Protocol**: TCP
   - **Action**: Allow
   - **Priority**: 1040
   - **Name**: `Allow-HTTPS-443`

**Azure CLI Method:**

```bash
# Add port 80 for SSL validation
az vm open-port --resource-group [your-rg] --name [your-vm] --port 80 --priority 1030

# Add port 443 for HTTPS traffic
az vm open-port --resource-group [your-rg] --name [your-vm] --port 443 --priority 1040
```

### Step 3: Automated Dual Subdomain SSL Setup

**Use our automated script for one-command dual subdomain SSL configuration:**

```bash
# After completing Steps 1-2 above, run:
sudo ./deployment-scripts/configure-dual-subdomain-nginx.sh

# Then get SSL certificates for both domains:
sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech
```

**Manual setup** (if you prefer step-by-step control):

```bash
# Configure dual subdomain Nginx setup
sudo ./deployment-scripts/configure-dual-subdomain-nginx.sh

# Get SSL certificates for both domains
sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech
```

### Step 4: Verify HTTPS Endpoints

After SSL setup, test your new dual subdomain endpoints:

```bash
# Test Medusa API
curl -I https://api.techdukaan.tech

# Test MeiliSearch API
curl -I https://search.techdukaan.tech/health

# Test MeiliSearch Dashboard
curl -I https://search.techdukaan.tech

# Test API health check
curl -I https://api.techdukaan.tech/health
```

### ✅ SSL/Domain Benefits

- ✅ **Professional URLs**: `https://api.techdukaan.tech` and `https://search.techdukaan.tech`
- ✅ **SSL Security**: All API traffic encrypted
- ✅ **Service Isolation**: Clean separation between Medusa and MeiliSearch
- ✅ **No Static Asset Conflicts**: MeiliSearch dashboard works perfectly
- ✅ **CORS Compliance**: Browsers trust HTTPS endpoints
- ✅ **SEO Friendly**: Search engines prefer HTTPS
- ✅ **Production Ready**: Matches industry standards for microservices

**📚 Detailed Guide**: See [WINDOWS_TO_AZURE_WORKFLOW.md](../WINDOWS_TO_AZURE_WORKFLOW.md) for comprehensive dual subdomain setup instructions.

## ⚡ Quick Start

**Prerequisites:** Complete the "Azure Platform Prerequisites" section above first!

### Automated Deployment (Recommended)

```bash
# 1. Clone the repository (Azure setup should be done first!)
git clone https://github.com/AryanXPatel/TechDukaan-Medusa.git
cd TechDukaan-Medusa

# 2. Set up environment configuration
cp .env.production.template .env.production

# 3. Edit configuration with your actual values
nano .env.production
# Replace ALL placeholder values:
# - USERNAME:PASSWORD in DATABASE_URL
# - All GENERATE_* secrets (use commands below)
# - YOUR_VM_IP with actual IP address (from: curl ifconfig.me)
# - Azure storage keys (from Azure Portal)

# 4. Generate required secrets:
openssl rand -base64 32    # For JWT_SECRET
openssl rand -base64 16    # For SESSION_SECRET and COOKIE_SECRET (use SAME value!)
openssl rand -hex 16       # For MEILI_MASTER_KEY

# 5. Run deployment (will validate configuration and deploy)
chmod +x deployment-scripts/master-deploy.sh
./deployment-scripts/master-deploy.sh

# 6. (Optional) Setup Professional Dual Subdomain Architecture
# For api.techdukaan.tech (Medusa) and search.techdukaan.tech (MeiliSearch)
sudo chmod +x deployment-scripts/configure-dual-subdomain-nginx.sh
sudo ./deployment-scripts/configure-dual-subdomain-nginx.sh
# Then get SSL: sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech

# 7. Access your deployment:
# API Health: http://[your-vm-ip]:9000/health
# Admin Interface: http://[your-vm-ip]:9000/app
```

### 🚀 Expected Results

After successful deployment:

- ✅ **API Health Check**: `curl http://[your-vm-ip]:9000/health` returns `{"status":"ok"}`
- ✅ **Admin Interface**: Accessible at `http://[your-vm-ip]:9000/app`
- ✅ **All Services**: `docker ps` shows 3 running containers
- ✅ **Database Connected**: Migrations completed successfully

## � **CRITICAL: Azure PostgreSQL Firewall Setup**

**⚠️ IMPORTANT: Do this BEFORE running the deployment script!**

Your Azure PostgreSQL database has firewall rules that block connections by default. You MUST add your VM's IP address to the firewall rules, or the deployment will fail with connection errors.

### 📍 Get Your VM's External IP Address

```bash
# Method 1: Get external IP from your VM
curl ifconfig.me

# Method 2: Check Azure Portal
# Go to: Azure Portal > Virtual Machines > [your-vm] > Overview > Public IP address

# Method 3: From Azure CLI (if installed)
az vm list-ip-addresses --resource-group [your-rg] --name [your-vm]
```

### 🔧 Add IP to Azure PostgreSQL Firewall

**Option 1: Azure Portal (Recommended)**

1. Go to **Azure Portal**
2. Navigate to: **Azure Database for PostgreSQL flexible servers**
3. Select your database: `psql-techdukaan-prod`
4. Go to **Settings > Networking**
5. Under **Firewall rules**, click **+ Add current client IP address**
6. Or manually add rule:
   - **Rule name**: `VM-TechDukaan-Access`
   - **Start IP**: `[your-vm-ip]` (e.g., 20.198.176.252)
   - **End IP**: `[your-vm-ip]` (same as start IP)
7. Click **Save**

**Option 2: Azure CLI**

```bash
# Add firewall rule for your VM
az postgres flexible-server firewall-rule create \
  --resource-group [your-resource-group] \
  --name psql-techdukaan-prod \
  --rule-name VM-TechDukaan-Access \
  --start-ip-address [your-vm-ip] \
  --end-ip-address [your-vm-ip]
```

### ✅ Test Database Connection

Before proceeding with deployment, test the database connection:

```bash
# Test connection using psql (if available)
psql "postgres://[username]:[password]@psql-techdukaan-prod.postgres.database.azure.com:5432/postgres?sslmode=require"

# Or test with telnet
telnet psql-techdukaan-prod.postgres.database.azure.com 5432
```

**If connection fails, double-check your firewall rules and VM IP address!**

---

## �📋 Configuration Guide

### 🔍 Finding Your VM IP Address

```bash
# Method 1: External IP (for MEDUSA_ADMIN_BACKEND_URL)
curl ifconfig.me

# Method 2: Check Azure Portal
# Go to Azure Portal > Virtual Machines > Your VM > Overview > Public IP

# Method 3: Internal IP (if needed)
ip addr show | grep 'inet ' | grep -v 127.0.0.1
```

### 🔐 Generating Security Secrets

```bash
# Generate all secrets at once:
echo "JWT_SECRET=$(openssl rand -base64 32)"
echo "SESSION_AND_COOKIE_SECRET=$(openssl rand -base64 16)"
echo "MEILI_MASTER_KEY=$(openssl rand -hex 16)"

# Important: Use the SAME value for both SESSION_SECRET and COOKIE_SECRET
```

### 🗄️ Azure Storage Configuration

```bash
# Find your Azure Storage Account Key:
# 1. Go to Azure Portal
# 2. Navigate to: Storage Accounts > [your-storage-account] > Access keys
# 3. Copy either key1 or key2

# Your storage account details:
AZURE_STORAGE_ACCOUNT_NAME=sttechdukaanprod
AZURE_STORAGE_ACCOUNT_KEY=[key-from-azure-portal]
AZURE_STORAGE_CONTAINER_NAME=medusa-uploads
```

### 🗃️ Database Configuration

```bash
# Azure PostgreSQL Flexible Server format:
DATABASE_URL=postgres://[username]:[password]@[server-name].postgres.database.azure.com:5432/[database-name]?ssl=true

# Example:
DATABASE_URL=postgres://techdukaan:MyPassword123@psql-techdukaan-prod.postgres.database.azure.com:5432/postgres?ssl=true
```

### ✅ Configuration Checklist

Before running deployment, ensure you have:

- [ ] Replaced USERNAME:PASSWORD in DATABASE_URL
- [ ] Generated and set JWT_SECRET (32+ characters)
- [ ] Generated SESSION_SECRET and COOKIE_SECRET (same value)
- [ ] Generated MEILI_MASTER_KEY
- [ ] Set YOUR_VM_IP to actual external IP
- [ ] Added Azure storage account key
- [ ] Set admin email and password

### Option 2: Manual Step-by-Step

Choose your deployment scenario below for detailed instructions.

## 🎯 Deployment Scenarios

> **Important**: The current production setup uses **Azure PostgreSQL** as the external database. Local PostgreSQL deployment is not configured in the current docker-compose.production.yml file.

### Scenario 1: Fresh VM + Existing Azure PostgreSQL (Current Setup)

**Use Case**: Complete new deployment connecting to existing Azure PostgreSQL database

```bash
# 1. Fresh VM Setup
./deployment-scripts/00-fresh-vm-setup.sh

# 2. Clone and Configure
./deployment-scripts/01-clone-and-configure.sh

# 3. Deploy Medusa services
./deployment-scripts/02-deploy-medusa.sh

# 4. Verify Deployment
./deployment-scripts/03-verify-deployment.sh
```

**Environment Configuration**:

```bash
# The deployment script will auto-create .env.production from template
# You'll be prompted to edit it with your actual values:

# Generate secrets with these commands:
openssl rand -base64 32    # For JWT_SECRET
openssl rand -base64 16    # For SESSION_SECRET and COOKIE_SECRET (use same value!)
openssl rand -hex 16       # For MEILI_MASTER_KEY

# Example .env.production values:
DATABASE_URL=postgresql://techdukaan:password@psql-techdukaan-prod.postgres.database.azure.com:5432/postgres?ssl=true
REDIS_URL=redis://redis:6379
JWT_SECRET=your_generated_jwt_secret
SESSION_SECRET=your_generated_session_secret
COOKIE_SECRET=your_generated_session_secret  # Must match SESSION_SECRET!
MEDUSA_ADMIN_BACKEND_URL=http://YOUR_VM_IP:9000
ADMIN_EMAIL=admin@techdukaan.com
ADMIN_PASSWORD=secure_admin_password
```

### Scenario 2: Fresh VM + Different Azure PostgreSQL Instance

**Use Case**: Deploy to new server connecting to a different Azure PostgreSQL database

```bash
# 1. Fresh VM Setup
./deployment-scripts/00-fresh-vm-setup.sh

# 2. Update Environment Configuration
# Edit .env.production with your Azure PostgreSQL credentials
nano .env.production
# Update DATABASE_URL to point to your PostgreSQL instance

# 3. Clone and Configure
./deployment-scripts/01-clone-and-configure.sh

# 4. Deploy Application Services
./deployment-scripts/02-deploy-medusa.sh

# 5. Verify Deployment
./deployment-scripts/03-verify-deployment.sh
```

**Environment Configuration**:

```bash
# .env.production for Azure PostgreSQL
DATABASE_URL=postgresql://medusa@your-server:password@your-server.postgres.database.azure.com:5432/medusa_production?sslmode=require
REDIS_URL=redis://redis:6379
MEDUSA_ADMIN_EMAIL=admin@techdukaan.com
MEDUSA_ADMIN_PASSWORD=secure_admin_password
SESSION_SECRET=your_session_secret_here
```

### Scenario 3: Existing VM + Current Configuration

**Use Case**: Deploy TechDukaan to existing server with current Azure PostgreSQL setup

```bash
# 1. Update existing system
sudo apt update && sudo apt upgrade -y

# 2. Install Docker Compose V2 (if not present)
sudo apt install docker-compose-plugin -y

# 3. Clone and setup
git clone https://github.com/AryanXPatel/TechDukaan-Medusa.git
cd TechDukaan-Medusa
./deployment-scripts/01-clone-and-configure.sh

# 4. Deploy services (uses existing .env.production)
docker compose -f docker-compose.production.yml up -d

# 5. Run migrations
docker compose -f docker-compose.production.yml exec medusa-server npx medusa migrations run

# 6. Create admin user (if needed)
docker compose -f docker-compose.production.yml exec medusa-server npx medusa user -e admin@techdukaan.com -p secure_password --invite
```

### Scenario 4: Development Setup

**Use Case**: Local development environment with hot reloading

```bash
# 1. Clone repository
git clone https://github.com/AryanXPatel/TechDukaan-Medusa.git
cd TechDukaan-Medusa

# 2. Install dependencies
npm install

# 3. Start development environment
docker compose up -d
npm run dev

# 4. Access development admin
# API: http://localhost:9000
# Admin: http://localhost:9000/app
# Note: In production, admin and API run on the same port
```

## 🔧 Configuration Reference

### Docker Compose Files

- `docker-compose.yml` - Development environment (not included in current setup)
- `docker-compose.production.yml` - Production deployment with:
  - **medusa-server**: Main Medusa backend + admin interface
  - **redis**: Caching and session storage
  - **meilisearch**: Product search engine
  - **Note**: PostgreSQL runs externally on Azure

### Service Ports

| Service               | Port | Description                | Access        |
| --------------------- | ---- | -------------------------- | ------------- |
| Medusa Server + Admin | 9000 | Main API + Admin Dashboard | External      |
| Redis                 | 6379 | Cache (internal)           | Internal only |
| Meilisearch           | 7700 | Search engine (internal)   | Internal only |
| PostgreSQL            | 5432 | Database (Azure External)  | External      |

### Environment Variables

**Required Variables**:

```bash
# Database (Azure PostgreSQL)
DATABASE_URL=postgresql://user:password@server.postgres.database.azure.com:5432/database?ssl=true

# Redis (Docker container)
REDIS_URL=redis://redis:6379

# Security Secrets
JWT_SECRET=your_32_character_secret
COOKIE_SECRET=your_32_character_secret
SESSION_SECRET=your_32_character_secret

# Admin Credentials
MEDUSA_ADMIN_EMAIL=admin@your-domain.com
MEDUSA_ADMIN_PASSWORD=secure_password

# MeiliSearch
MEILI_HTTP_ADDR=meilisearch:7700
MEILI_MASTER_KEY=your_meilisearch_key
```

**Optional Variables**:

```bash
# Environment
NODE_ENV=production
PORT=9000

# CORS Configuration
STORE_CORS=https://your-domain.com,http://localhost:3000
ADMIN_CORS=*
AUTH_CORS=https://your-domain.com,http://localhost:3000

# Azure Storage (if using blob storage)
STORAGE_PROVIDER=azure
AZURE_STORAGE_ACCOUNT_NAME=your_storage_account
AZURE_STORAGE_ACCOUNT_KEY=your_storage_key
AZURE_STORAGE_CONTAINER_NAME=medusa-uploads
```

## 🏥 Health Checks & Verification

### Service Health

```bash
# Check all services status
docker compose -f docker-compose.production.yml ps

# Check specific service logs
docker compose -f docker-compose.production.yml logs medusa-server

# Health check endpoints
curl http://localhost:9000/health
curl http://localhost:7700/health

# Admin interface access
# Visit: http://localhost:9000/app
```

### Database Verification

```bash
# Check database connection
docker compose -f docker-compose.production.yml exec medusa-server npx medusa db:status

# List migrations
docker compose -f docker-compose.production.yml exec medusa-server npx medusa migrations:show
```

### Admin Access

```bash
# Reset admin password
docker compose -f docker-compose.production.yml exec medusa-server npx medusa user --email admin@techdukaan.com --password new_password

# Create new admin user
docker compose -f docker-compose.production.yml exec medusa-server npx medusa user -e newadmin@techdukaan.com -p password --invite
```

## 🛠️ Troubleshooting

### Common Issues

#### Docker Compose V1 vs V2

**Problem**: `docker-compose command not found`

```bash
# Solution: Install Docker Compose V2
sudo apt install docker-compose-plugin -y

# Use V2 syntax
docker compose up -d  # ✅ Correct
docker-compose up -d  # ❌ Legacy
```

#### Migration Errors

**Problem**: `Missing script: migration:run`

```bash
# Solution: Use Medusa CLI directly
docker compose exec medusa-server npx medusa migrations run  # ✅ Correct
docker compose exec medusa-server npm run migration:run     # ❌ Incorrect
```

#### Database Connection Issues

**Problem**: `Connection refused to PostgreSQL` or `Connection reset by peer`

**Most Common Cause**: Azure PostgreSQL firewall blocking VM IP

```bash
# 1. Check your VM's IP address
curl ifconfig.me

# 2. Add this IP to Azure PostgreSQL firewall rules:
#    Azure Portal > PostgreSQL flexible servers > psql-techdukaan-prod > Networking > Firewall rules

# 3. Test database connection
psql "postgres://[username]:[password]@psql-techdukaan-prod.postgres.database.azure.com:5432/postgres?sslmode=require"

# 4. Check container database connectivity
docker compose exec medusa-server npx medusa db:status

# 5. Verify connection string in container
docker compose exec medusa-server env | grep DATABASE_URL
```

#### Port Conflicts

**Problem**: `Port already in use`

```bash
# Find processes using ports
sudo netstat -tulpn | grep :9000

# Kill conflicting processes
sudo kill -9 $(sudo lsof -t -i:9000)
```

### Advanced Troubleshooting

#### Container Logs

```bash
# View all logs
docker compose -f docker-compose.production.yml logs

# Follow specific service logs
docker compose -f docker-compose.production.yml logs -f medusa-server

# View logs from last 10 minutes
docker compose -f docker-compose.production.yml logs --since 10m
```

#### Performance Issues

```bash
# Check resource usage
docker stats

# Inspect container details
docker compose -f docker-compose.production.yml exec medusa-server top

# Database performance
docker compose -f docker-compose.production.yml exec postgres psql -U medusa -d medusa_db -c "SELECT * FROM pg_stat_activity;"
```

## 🔒 Security Considerations

### Production Hardening

1. **Change Default Passwords**

   ```bash
   # Generate secure passwords
   openssl rand -base64 32
   ```

2. **Enable SSL/TLS**

   ```bash
   # Add SSL certificates to nginx proxy
   # Update environment variables for HTTPS
   ```

3. **Network Security**

   ```bash
   # Configure firewall
   sudo ufw allow 22,80,443/tcp
   sudo ufw enable
   ```

4. **Database Security**
   ```bash
   # Use SSL connections for Azure PostgreSQL
   DATABASE_URL="postgresql://user:pass@host:5432/db?sslmode=require"
   ```

### Environment Secrets

**Never commit these to version control**:

- Database passwords
- Session secrets
- API keys
- SSL certificates

Use environment variables or secret management systems.

## 🚀 Production Deployment Checklist

### Current Production Status ✅

- [x] Server meets minimum requirements (Ubuntu 22.04+)
- [x] Docker Compose V2 installed and tested
- [x] Azure PostgreSQL database configured and accessible
- [x] Environment variables properly configured
- [x] Docker services (medusa-server, redis, meilisearch) deployed
- [x] Health checks passing
- [x] Admin user created and accessible
- [x] Migration commands fixed (npx medusa migrations run)
- [x] Docker Compose V2 syntax implemented

### For New Deployments

- [ ] Server meets minimum requirements
- [ ] Docker Compose V2 installed
- [ ] Environment variables configured (.env.production)
- [ ] Database accessible (Azure PostgreSQL)
- [ ] Firewall rules configured (ports 22, 9000)
- [ ] SSL certificates configured (if applicable)
- [ ] Backup strategy implemented
- [ ] Monitoring configured
- [ ] Health checks passing
- [ ] Admin user created
- [ ] Initial products loaded

## 📊 Monitoring & Maintenance

### Log Management

```bash
# Rotate logs to prevent disk space issues
docker system prune -f

# Set up log rotation in production
# Add to /etc/logrotate.d/docker
```

### Regular Maintenance

```bash
# Update container images
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d

# Database maintenance
docker compose -f docker-compose.production.yml exec postgres vacuumdb -U medusa -d medusa_db
```

## 📚 Additional Resources

- [Medusa Documentation](https://docs.medusajs.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [Azure PostgreSQL Documentation](https://docs.microsoft.com/en-us/azure/postgresql/)
- [Ubuntu Server Guide](https://ubuntu.com/server/docs)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Search existing GitHub issues
3. Create a new issue with:
   - Deployment scenario used
   - Error messages and logs
   - System configuration details
   - Steps to reproduce

## 📞 Contact

- **Project Maintainer**: [Aryan Patel](mailto:aryan@techdukaan.com)
- **Repository**: [github.com/AryanXPatel/TechDukaan-Medusa](https://github.com/AryanXPatel/TechDukaan-Medusa)
- **Documentation**: [TechDukaan Deployment Guide](https://github.com/AryanXPatel/TechDukaan-Medusa/blob/main/README.md)

## 🚀 Complete Dual Subdomain Setup (ONE COMMAND)

**NEW: Automated zero-confusion setup for production domains**

```bash
# Run this ONCE to set up everything correctly:
sudo ./deployment-scripts/setup-complete-dual-subdomain.sh
```

This replaces multiple manual steps and prevents routing configuration errors.

**Result**: 
- ✅ `api.techdukaan.tech` → Medusa (correct)
- ✅ `search.techdukaan.tech` → MeiliSearch (correct)
- ✅ SSL certificates automatically configured
- ✅ CORS fixes applied for MeiliSearch dashboard
- ✅ All routing validated and tested

See `deployment-scripts/COMPLETE_DUAL_SUBDOMAIN_SETUP.md` for full details.

---

**Built with ❤️ for the TechDukaan community**

This starter is compatible with versions >= 2 of `@medusajs/medusa`.

## Getting Started

Visit the [Quickstart Guide](https://docs.medusajs.com/learn/installation) to set up a server.

Visit the [Docs](https://docs.medusajs.com/learn/installation#get-started) to learn more about our system requirements.

## What is Medusa

Medusa is a set of commerce modules and tools that allow you to build rich, reliable, and performant commerce applications without reinventing core commerce logic. The modules can be customized and used to build advanced ecommerce stores, marketplaces, or any product that needs foundational commerce primitives. All modules are open-source and freely available on npm.

Learn more about [Medusa’s architecture](https://docs.medusajs.com/learn/introduction/architecture) and [commerce modules](https://docs.medusajs.com/learn/fundamentals/modules/commerce-modules) in the Docs.

## Community & Contributions

The community and core team are available in [GitHub Discussions](https://github.com/medusajs/medusa/discussions), where you can ask for support, discuss roadmap, and share ideas.

Join our [Discord server](https://discord.com/invite/medusajs) to meet other community members.

## Other channels

- [GitHub Issues](https://github.com/medusajs/medusa/issues)
- [Twitter](https://twitter.com/medusajs)
- [LinkedIn](https://www.linkedin.com/company/medusajs)
- [Medusa Blog](https://medusajs.com/blog/)
