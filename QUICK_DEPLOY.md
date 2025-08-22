# 🚀 Quick Deploy Guide

## One-Command Deployment

```bash
# Clone and deploy
git clone https://github.com/yourusername/TechDukaan.git
cd TechDukaan/medusa-backend
cp .env.production.template .env.production
nano .env.production  # Edit with your credentials
chmod +x deploy.sh
./deploy.sh
```

## What the Working Command Does

The successful deployment command that worked:

```bash
docker-compose -f docker-compose.production.yml run --rm -p 9000:9000 medusa-server sh -c "
cd /app/.medusa/server &&
npm install &&
cp /app/.env.production .env &&
NODE_ENV=production npm start
"
```

### Step-by-step breakdown:

1. **`docker-compose run`** - Runs a one-time container
2. **`--rm`** - Removes container when it stops
3. **`-p 9000:9000`** - Maps port 9000 (critical for external access)
4. **`cd /app/.medusa/server`** - Changes to built directory
5. **`npm install`** - Installs dependencies in built environment
6. **`cp /app/.env.production .env`** - Copies environment config
7. **`NODE_ENV=production npm start`** - Starts Medusa server

## Key Success Factors

1. **✅ Working Directory**: Must run from `/app/.medusa/server` (not `/app`)
2. **✅ Port Mapping**: Must explicitly map port with `-p 9000:9000`
3. **✅ Environment Variables**: MeiliSearch environment override removed
4. **✅ Azure NSG**: Port 9000 inbound rule configured
5. **✅ Dependencies**: Install npm packages in built directory

## Results Achieved

- **API Health**: ✅ `curl http://52.237.83.34:9000/health` → `OK`
- **Admin Interface**: ✅ `http://52.237.83.34:9000/app/` → Accessible
- **External Access**: ✅ Working from internet
- **All Services**: ✅ Medusa, Redis, MeiliSearch running

## Production Deployment Method

For ongoing production use:

```bash
# Use docker-compose up instead of run
docker-compose -f docker-compose.production.yml up -d
```

The `deploy.sh` script automates this entire process for consistent deployments.
