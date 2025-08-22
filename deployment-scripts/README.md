# Medusa Production Deployment Scripts

Production-grade deployment automation for Medusa v2.8.x e-commerce platform with admin interface session persistence fix.

## Overview

This deployment system provides infrastructure setup and validation scripts for deploying Medusa on Ubuntu servers. The scripts handle system dependencies, Docker orchestration, and include the proven fix for the Medusa v2.8.x admin interface session persistence issue.

**Key Principle: User maintains full control over all configuration and secrets.**

## Security Notice

⚠️ **CRITICAL**: These scripts do NOT auto-generate or populate secrets. You must provide all configuration values manually. Never commit `.env.production` or files containing secrets to version control.

## Script Structure

```
deployment-scripts/
├── 00-fresh-vm-setup.sh       # System dependencies installation
├── 01-clone-and-configure.sh  # Environment validation
├── 02-deploy-medusa.sh        # Application deployment
├── 03-verify-deployment.sh    # Comprehensive testing
├── config-templates/          # Configuration templates
└── utils/                     # Helper utilities
```

## Prerequisites

- Ubuntu 22.04 LTS server
- Minimum 2GB RAM, 20GB disk space
- Root/sudo access
- Azure PostgreSQL Flexible Server (configured separately)
- Azure Blob Storage account (optional)

## Deployment Process

### Step 1: System Setup

Install system dependencies on fresh Ubuntu server:

```bash
sudo ./deployment-scripts/00-fresh-vm-setup.sh
```

This installs:
- Docker Engine and Docker Compose
- Node.js v20 LTS
- Essential development tools
- Security configurations (UFW firewall, fail2ban)

### Step 2: Configuration

**You must manually configure the environment file:**

1. Copy the template:
   ```bash
   cp .env.production.template .env.production
   ```

2. Edit `.env.production` with your actual values:
   ```bash
   nano .env.production
   ```

3. Generate secure secrets:
   ```bash
   # Generate JWT secret (32 hex chars)
   openssl rand -hex 32
   
   # Generate cookie secret (16 hex chars) 
   openssl rand -hex 16
   ```

4. **Critical**: Set `SESSION_SECRET` to match `COOKIE_SECRET` exactly (required for admin interface fix)

5. Configure database connection string for your Azure PostgreSQL server

6. Set external IP in `MEDUSA_ADMIN_BACKEND_URL`

7. Validate configuration:
   ```bash
   ./deployment-scripts/01-clone-and-configure.sh
   ```

### Step 3: Deploy Application

Deploy Medusa with admin interface fix:

```bash
./deployment-scripts/02-deploy-medusa.sh
```

This process:
- Validates environment configuration
- Builds admin interface with proper backend URL
- Starts all services via Docker Compose
- Creates admin user (if configured)
- Applies session persistence fix

### Step 4: Verify Deployment

Run comprehensive testing:

```bash
./deployment-scripts/03-verify-deployment.sh
```

Tests performed:
- Infrastructure health (containers, ports)
- API functionality (health, store, admin endpoints)
- Database connectivity and migrations
- Authentication flow validation
- Configuration validation
- Security checks
- System resources

## Configuration Requirements

### Required Environment Variables

```bash
# Core
NODE_ENV=production
PORT=9000

# Database (update with your values)
DATABASE_URL=postgres://user:pass@server:5432/db?ssl=true

# Security (generate your own)
JWT_SECRET=your_32_hex_char_secret
COOKIE_SECRET=your_16_hex_char_secret
SESSION_SECRET=same_as_cookie_secret  # Critical for admin fix

# External access (update with your IP/domain)
MEDUSA_ADMIN_BACKEND_URL=http://your_ip:9000

# Admin user (set your own)
ADMIN_EMAIL=your@email.com
ADMIN_PASSWORD=your_secure_password
```

### Admin Interface Fix

The deployment includes the proven fix for Medusa v2.8.x admin interface session persistence:

1. **SESSION_SECRET must match COOKIE_SECRET exactly**
2. **Admin interface built with MEDUSA_ADMIN_BACKEND_URL**
3. **Cookie options configured for external HTTP access**

## Service Management

```bash
# View logs
docker-compose -f docker-compose.production.yml logs -f

# Check status
docker-compose -f docker-compose.production.yml ps

# Restart services
docker-compose -f docker-compose.production.yml restart

# Stop services
docker-compose -f docker-compose.production.yml down

# Rebuild (after changes)
docker-compose -f docker-compose.production.yml build --no-cache
docker-compose -f docker-compose.production.yml up -d
```

## Access Information

After successful deployment:

- **API**: http://your_ip:9000
- **Admin Interface**: http://your_ip:9000/app
- **Health Check**: http://your_ip:9000/health

## Security Considerations

1. **Never commit `.env.production` to version control**
2. **Use strong, randomly generated secrets**
3. **Restrict CORS origins for production**
4. **Configure firewall to allow only necessary ports**
5. **Set up SSL/TLS for production use**
6. **Regularly update system packages and Docker images**

## Troubleshooting

### Common Issues

**Admin interface login loop:**
- Verify `SESSION_SECRET` matches `COOKIE_SECRET`
- Check `MEDUSA_ADMIN_BACKEND_URL` is correct
- Confirm firewall allows port 9000

**Database connection failed:**
- Verify `DATABASE_URL` format and credentials
- Check Azure PostgreSQL firewall rules
- Ensure SSL is enabled

**Container startup issues:**
- Check logs: `docker-compose -f docker-compose.production.yml logs`
- Verify system resources (memory/disk)
- Check Docker daemon status

### Diagnostic Commands

```bash
# Test API health
curl http://localhost:9000/health

# Test admin authentication (replace with your credentials)
curl -H "Content-Type: application/json" \
     -d '{"email":"your@email.com","password":"yourpass"}' \
     http://localhost:9000/auth/user/emailpass

# Check container status
docker-compose -f docker-compose.production.yml ps

# View system resources
free -h && df -h

# Check network ports
netstat -tlpn | grep -E ":(9000|6379|7700)"
```

## Production Hardening

For production environments:

1. **SSL/TLS**: Configure reverse proxy (nginx) with SSL certificate
2. **Domain**: Set up proper domain and DNS
3. **Monitoring**: Implement health checks and alerting
4. **Backups**: Configure automated database backups
5. **Updates**: Establish update procedures for security patches

## Documentation

- **Admin Interface Fix Guide**: `../MEDUSA_ADMIN_FIX_COMPREHENSIVE_GUIDE.md`
- **Medusa Documentation**: https://docs.medusajs.com
- **Docker Compose Reference**: https://docs.docker.com/compose/

---

**Note**: This deployment system prioritizes security and user control. All secrets and configuration must be provided by the user. The scripts handle infrastructure setup and validation only.
