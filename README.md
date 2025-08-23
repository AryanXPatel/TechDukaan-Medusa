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

## ⚡ Quick Start

### Option 1: Automated Deployment (Recommended)

```bash
# Clone the repository
git clone https://github.com/AryanXPatel/TechDukaan-Medusa.git
cd TechDukaan-Medusa

# Run master deployment script
chmod +x deployment-scripts/master-deploy.sh
./deployment-scripts/master-deploy.sh

# The script will automatically:
# 1. Create .env.production from template
# 2. Offer to open nano for configuration
# 3. Validate your configuration
# 4. Deploy all services
```

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

| Service | Port | Description | Access |
|---------|------|-------------|---------|
| Medusa Server + Admin | 9000 | Main API + Admin Dashboard | External |
| Redis | 6379 | Cache (internal) | Internal only |
| Meilisearch | 7700 | Search engine (internal) | Internal only |
| PostgreSQL | 5432 | Database (Azure External) | External |

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
**Problem**: `Connection refused to PostgreSQL`
```bash
# Check database status
docker compose logs postgres

# Verify connection string
echo $DATABASE_URL

# Test connection
docker compose exec medusa-server npx medusa db:status
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
