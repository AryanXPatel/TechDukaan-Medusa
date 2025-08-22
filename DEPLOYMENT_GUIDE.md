# TechDukaan Medusa Backend - Azure VM Deployment Guide

## 🎯 Successful Deployment Summary

**Status**: ✅ FULLY OPERATIONAL

- **API Health**: http://52.237.83.34:9000/health → `OK`
- **Admin Interface**: http://52.237.83.34:9000/app/ → ✅ Accessible
- **Database**: Azure PostgreSQL Flexible Server → ✅ Connected
- **Search**: MeiliSearch → ✅ Running
- **Cache**: Redis → ✅ Running

## 🚀 One-Command Deployment Script

### Prerequisites

- Azure VM with Docker and Docker Compose installed
- Azure PostgreSQL Flexible Server configured
- Network Security Group with port 9000 inbound rule
- Domain DNS pointing to VM IP (optional)

### Quick Deploy

```bash
# Clone and deploy in one command
curl -sSL https://raw.githubusercontent.com/yourusername/TechDukaan/main/deploy.sh | bash
```

### Manual Deployment Steps

1. **Clone Repository**

```bash
git clone https://github.com/yourusername/TechDukaan.git
cd TechDukaan/medusa-backend
```

2. **Setup Environment**

```bash
cp .env.production.template .env.production
# Edit .env.production with your actual credentials
nano .env.production
```

3. **Deploy Services**

```bash
./deploy.sh
```

## 📁 Project Structure

```
medusa-backend/
├── deploy.sh                     # 🚀 One-command deployment
├── docker-compose.production.yml # Docker services configuration
├── Dockerfile                    # Medusa server image
├── .env.production.template      # Environment template
├── .env.production              # Production environment (create from template)
├── medusa-config.ts             # Medusa configuration
└── src/                         # Source code
```

## 🔧 Key Configuration Files

### 1. docker-compose.production.yml

- **Medusa Server**: Port 9000, production build from .medusa/server
- **Redis**: Port 6379, caching and job queue
- **MeiliSearch**: Port 7700, product search engine

### 2. .env.production

Critical environment variables:

- `DATABASE_URL`: Azure PostgreSQL connection
- `REDIS_URL`: Redis connection (docker service)
- `MEILI_HTTP_ADDR`: MeiliSearch endpoint (docker service)
- `MEILI_MASTER_KEY`: MeiliSearch authentication
- `JWT_SECRET` & `COOKIE_SECRET`: Security keys
- `STORE_CORS` & `ADMIN_CORS`: CORS configuration

## 🐛 Common Issues & Solutions

### Issue 1: MeiliSearch Authentication Error

**Error**: `The provided API key is invalid`
**Solution**: Ensure `MEILI_MASTER_KEY` is not overridden in docker-compose environment section

### Issue 2: Port Not Accessible Externally

**Error**: Connection timeout from external IP
**Solution**: Add Azure NSG inbound rule for port 9000

### Issue 3: Container Restart Loop

**Error**: Server restarts continuously
**Solution**: Ensure Dockerfile uses `/app/.medusa/server` as working directory after build

### Issue 4: Admin Interface Not Found

**Error**: Could not find index.html in admin build directory
**Solution**: Run from `.medusa/server` directory, not source directory

## 🔄 Deployment Workflow

### Development to Production Pipeline

1. **Local Development** → Test changes locally
2. **Git Commit & Push** → Version control
3. **Azure VM Pull** → `git pull origin main`
4. **Rebuild & Deploy** → `./deploy.sh`
5. **Health Check** → Verify endpoints

### Zero-Downtime Updates

```bash
# Pull latest changes
git pull origin main

# Build new image
docker-compose -f docker-compose.production.yml build --no-cache

# Rolling update
docker-compose -f docker-compose.production.yml up -d --force-recreate
```

## 🧪 Testing & Verification

### Health Checks

```bash
# API Health
curl http://52.237.83.34:9000/health

# Store API
curl http://52.237.83.34:9000/store/regions

# Admin Interface
curl -I http://52.237.83.34:9000/app/
```

### Service Status

```bash
# Check all containers
docker ps

# Check logs
docker-compose -f docker-compose.production.yml logs -f medusa-server
```

## 🔐 Security Considerations

### Environment Variables

- Never commit `.env.production` to version control
- Use strong random values for JWT_SECRET and COOKIE_SECRET
- Restrict CORS origins to actual domains

### Azure Security

- Configure NSG to allow only necessary ports (22, 9000, 80, 443)
- Use Azure Key Vault for sensitive credentials (future enhancement)
- Enable Azure monitoring and logging

## 📊 Performance & Monitoring

### Resource Usage

- **Memory**: ~2GB for all services
- **CPU**: 2 vCPUs recommended
- **Storage**: 20GB minimum for containers and data

### Monitoring Endpoints

- Health: `/health`
- Metrics: Enable Medusa metrics plugin
- Logs: Docker Compose logs

## 🚀 Production Optimizations

### Performance

- Enable Redis persistence
- Configure MeiliSearch index settings
- Use Azure Blob Storage for file uploads
- Implement CDN for static assets

### Scalability

- Separate worker processes (set `WORKER_MODE=worker`)
- Use Azure Database connection pooling
- Implement horizontal scaling with load balancer

## 🔄 Backup & Recovery

### Database Backup

```bash
# Automated daily backups
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
```

### Container Data

- MeiliSearch data: `/meili_data` volume
- Upload files: `/app/uploads` volume (use Azure Blob Storage)

## 📞 Support & Troubleshooting

### Quick Fixes

```bash
# Restart all services
docker-compose -f docker-compose.production.yml restart

# View real-time logs
docker-compose -f docker-compose.production.yml logs -f

# Check service health
docker-compose -f docker-compose.production.yml ps
```

### Debug Commands

```bash
# Execute in running container
docker-compose -f docker-compose.production.yml exec medusa-server bash

# Check environment variables
docker-compose -f docker-compose.production.yml exec medusa-server env
```

---

## ✅ Deployment Success Checklist

- [ ] API health endpoint returns `OK`
- [ ] Admin interface loads at `/app/`
- [ ] Database connection established
- [ ] MeiliSearch authentication working
- [ ] Redis connection established
- [ ] External port 9000 accessible
- [ ] CORS configured for your domains
- [ ] Environment variables secured

**🎉 Congratulations! Your TechDukaan Medusa backend is live and operational!**
