# TechDukaan API Subdomain Setup Guide

This guide walks you through setting up `api.techdukaan.tech` as your backend API endpoint using reverse proxy on your Azure VM.

## 🎯 Overview

**Before Setup:**

- Frontend: https://techdukaan.tech (Vercel)
- Backend: Direct IP access on port 9000
- MeiliSearch: Direct IP access on port 7700

**After Setup:**

- Frontend: https://techdukaan.tech (Vercel)
- Backend API: https://api.techdukaan.tech (Nginx → Medusa:9000)
- Search API: https://api.techdukaan.tech/search (Nginx → MeiliSearch:7700)

## 📋 Prerequisites

1. ✅ Azure VM with TechDukaan deployed
2. ✅ Domain `techdukaan.tech` already configured
3. ✅ DNS management access (GoDaddy, Namecheap, etc.)
4. ✅ SSH access to your Azure VM

## 🚀 Step-by-Step Implementation

### Step 1: Configure DNS

1. **Log into your domain registrar** (GoDaddy, Namecheap, etc.)

2. **Add A Record for API subdomain:**

   ```
   Type: A
   Name: api
   Value: [Your Azure VM Public IP]
   TTL: 300 (5 minutes)
   ```

3. **Verify DNS propagation** (may take 5-15 minutes):
   ```bash
   nslookup api.techdukaan.tech
   ```

### Step 2: Deploy Nginx Reverse Proxy

1. **SSH into your Azure VM:**

   ```bash
   ssh azureuser@[YOUR_VM_IP]
   ```

2. **Run the Nginx configuration script:**

   ```bash
   cd /path/to/TechDukaan/medusa-backend
   sudo chmod +x deployment-scripts/configure-nginx-reverse-proxy.sh
   sudo ./deployment-scripts/configure-nginx-reverse-proxy.sh
   ```

3. **Verify Nginx is running:**
   ```bash
   sudo systemctl status nginx
   ```

### Step 3: Obtain SSL Certificate

1. **Get Let's Encrypt certificate:**

   ```bash
   sudo certbot --nginx -d api.techdukaan.tech
   ```

2. **Follow the prompts:**

   - Enter your email address
   - Accept terms of service (Y)
   - Choose to share email with EFF (optional)
   - Select option 2: "Redirect HTTP to HTTPS"

3. **Verify SSL certificate:**
   ```bash
   sudo certbot certificates
   ```

### Step 4: Update Backend Configuration

1. **Update your .env.production file** with the new backend URL:

   ```bash
   MEDUSA_ADMIN_BACKEND_URL=https://api.techdukaan.tech
   ```

2. **Restart your Docker containers:**
   ```bash
   cd /path/to/TechDukaan/medusa-backend
   docker-compose -f docker-compose.production.yml down
   docker-compose -f docker-compose.production.yml up -d
   ```

### Step 5: Test the Setup

1. **Test Medusa API:**

   ```bash
   curl https://api.techdukaan.tech/store/products
   ```

2. **Test MeiliSearch:**

   ```bash
   curl https://api.techdukaan.tech/search/health
   ```

3. **Test from browser:**
   - Medusa: https://api.techdukaan.tech
   - MeiliSearch: https://api.techdukaan.tech/search
   - Health: https://api.techdukaan.tech/health

### Step 6: Deploy Frontend Changes

1. **Your frontend .env.production is already updated** with:

   ```bash
   NEXT_PUBLIC_MEDUSA_BACKEND_URL=https://api.techdukaan.tech
   NEXT_PUBLIC_MEILI_URL=https://api.techdukaan.tech/search
   ```

2. **Deploy to Vercel** (if using Vercel CLI):
   ```bash
   cd TechDukaan-FE
   vercel --prod
   ```

## 🔧 Configuration Details

### Nginx Configuration Features

- ✅ **Reverse Proxy**: Routes requests to correct services
- ✅ **SSL Termination**: Handles HTTPS encryption
- ✅ **CORS Headers**: Configured for techdukaan.tech frontend
- ✅ **Rate Limiting**: Protects against abuse
- ✅ **Security Headers**: XSS protection, frame options
- ✅ **Health Checks**: Monitoring endpoint available
- ✅ **Timeout Handling**: Proper timeout configurations

### URL Routing

```
https://api.techdukaan.tech/           → localhost:9000 (Medusa)
https://api.techdukaan.tech/store/*    → localhost:9000/store/* (Medusa Store API)
https://api.techdukaan.tech/admin/*    → localhost:9000/admin/* (Medusa Admin API)
https://api.techdukaan.tech/search/*   → localhost:7700/* (MeiliSearch)
https://api.techdukaan.tech/health     → Nginx health check
```

## 🛠 Troubleshooting

### DNS Issues

```bash
# Check if DNS is propagating
dig api.techdukaan.tech

# Check from different DNS servers
nslookup api.techdukaan.tech 8.8.8.8
```

### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificate manually
sudo certbot renew --dry-run
```

### Nginx Issues

```bash
# Check Nginx status
sudo systemctl status nginx

# Check Nginx error logs
sudo tail -f /var/log/nginx/error.log

# Test configuration
sudo nginx -t
```

### Backend Connection Issues

```bash
# Check if services are running
docker ps

# Check service logs
docker logs medusa-server
docker logs meilisearch
```

## 🔒 Security Notes

- ✅ CORS configured only for techdukaan.tech
- ✅ Rate limiting prevents API abuse
- ✅ Security headers protect against common attacks
- ✅ HTTPS-only access with SSL certificates
- ✅ No direct port access from internet

## 📱 Benefits of This Setup

1. **Professional API URLs**: Clean, branded endpoints
2. **SSL Security**: All traffic encrypted
3. **Single Entry Point**: One domain for all API access
4. **Rate Limiting**: Protection against abuse
5. **Easy Maintenance**: Centralized proxy configuration
6. **Future Scalability**: Easy to add more services

## 🎉 Success Indicators

After successful setup, you should see:

- ✅ Frontend loads from https://techdukaan.tech
- ✅ Products load via https://api.techdukaan.tech
- ✅ Search works via https://api.techdukaan.tech/search
- ✅ No CORS errors in browser console
- ✅ SSL certificates valid and auto-renewing
- ✅ All API calls use HTTPS

Your TechDukaan platform is now running with a professional, secure API infrastructure! 🚀
