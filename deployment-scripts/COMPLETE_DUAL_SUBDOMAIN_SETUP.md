# TechDukaan Complete Dual Subdomain Setup

## 🎯 ONE COMMAND SOLUTION

This script **completely automates** the dual subdomain setup process to **prevent routing confusion forever**.

### What This Replaces

Instead of running multiple manual steps that can cause routing conflicts:
```bash
# OLD WAY (Error-prone)
./configure-dual-subdomain-nginx.sh
sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech
./fix-meilisearch-dashboard-cors.sh
# Manual validation and troubleshooting...
```

### New Way (Bulletproof)
```bash
# NEW WAY (One command, zero confusion)
sudo ./setup-complete-dual-subdomain.sh
```

## 🚀 Features

- **🔧 Complete Configuration**: Sets up both subdomains with correct routing
- **🔒 SSL Automation**: Handles Let's Encrypt certificates automatically  
- **🌐 CORS Integration**: Includes MeiliSearch dashboard CORS fixes
- **✅ Built-in Validation**: Tests routing at every step
- **🔙 Smart Rollback**: Automatically reverts on any error
- **🧪 Comprehensive Testing**: Validates all endpoints before completion

## 📋 Prerequisites

Before running this script:

1. **DNS Records Configured**:
   ```
   api.techdukaan.tech    → A record → 20.198.176.252
   search.techdukaan.tech → A record → 20.198.176.252
   ```

2. **Docker Containers Running**:
   ```bash
   docker-compose -f docker-compose.production.yml up -d
   ```

3. **Azure NSG Ports Open**:
   - Port 80 (HTTP)
   - Port 443 (HTTPS)

## 🎯 Target Architecture

```
┌─────────────────────────────────────────┐
│             techdukaan.tech             │
│            (Vercel Frontend)            │
└─────────────────────────────────────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │     Azure VM Nginx    │
        │    (SSL Termination)  │
        └───────────────────────┘
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
┌──────────────┐      ┌──────────────────┐
│api.techdukaan│      │search.techdukaan │
│     .tech    │      │      .tech       │
│      │       │      │         │        │
│ Medusa API   │      │  MeiliSearch     │
│ (port 9000)  │      │  (port 7700)     │
└──────────────┘      └──────────────────┘
```

## 🔧 Usage

### Step 1: Make Script Executable
```bash
chmod +x setup-complete-dual-subdomain.sh
```

### Step 2: Run Complete Setup
```bash
sudo ./setup-complete-dual-subdomain.sh
```

### Step 3: Update Frontend Environment
After successful setup, update your frontend `.env.production`:
```env
NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://api.techdukaan.tech
NEXT_PUBLIC_MEILI_URL=https://search.techdukaan.tech
```

## ✅ Success Indicators

The script will show:
```
🎉 SETUP COMPLETE!

✅ Dual subdomain architecture successfully configured!

🔗 Your endpoints:
├── 🏪 Medusa API: https://api.techdukaan.tech
├── 🔧 Admin Panel: https://api.techdukaan.tech/app  
├── 🔍 MeiliSearch API: https://search.techdukaan.tech
└── 🎛️ MeiliSearch Dashboard: https://search.techdukaan.tech

📊 Health Check Results:
├── API Health: Medusa API healthy
└── Search Health: MeiliSearch is running

🚀 Ready for production use!
```

## 🔍 Validation Tests

The script automatically validates:
1. **Service Health**: Medusa and MeiliSearch responding
2. **Routing Accuracy**: No cross-service routing errors
3. **SSL Certificates**: HTTPS working for both domains
4. **CORS Configuration**: MeiliSearch dashboard functional
5. **Endpoint Accessibility**: All services reachable via subdomains

## 🔙 Rollback Protection

If anything fails:
- Automatic backup of existing configurations
- Smart rollback to previous working state
- Detailed error reporting for troubleshooting

## 🚨 Troubleshooting

### DNS Issues
```bash
# Check DNS propagation
dig +short api.techdukaan.tech
dig +short search.techdukaan.tech
```

### Container Issues  
```bash
# Check container status
docker ps
docker-compose -f docker-compose.production.yml logs
```

### SSL Issues
```bash
# Manual SSL setup if needed
sudo certbot --nginx -d api.techdukaan.tech -d search.techdukaan.tech
```

### Routing Validation
```bash
# Test routing manually
curl -s https://api.techdukaan.tech/health
curl -s https://search.techdukaan.tech/health
```

## 🎯 Why This Solution

This comprehensive script eliminates the routing confusion that occurred when running multiple configuration scripts separately. By handling everything in one validated sequence with built-in error handling, it ensures **consistent and reliable dual subdomain setup every time**.

**Never again will you see search.techdukaan.tech routing to Medusa!** 🎉
