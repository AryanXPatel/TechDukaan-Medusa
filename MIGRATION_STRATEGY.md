# TechDukaan Azure Account Migration Strategy

## Overview

Rotate between 6 Azure Student accounts every ~2-3 months to maximize free credits.
Each account provides $100 credit, VM costs ~$35/month.

## What to Backup for Migration

### Critical Data (MUST backup)

- PostgreSQL database dump
- Environment variables (stored locally, not in GitHub)
- Domain/DNS configuration notes
- Azure resource naming conventions

### Code (Version controlled in GitHub)

- Medusa backend source code
- Docker configuration files
- Environment templates (without secrets)
- Deployment scripts
- Migration documentation

### Data NOT to backup (Can rebuild)

- MeiliSearch indices (rebuild from Medusa)
- Redis cache data
- Container images (rebuild from Dockerfile)

## Migration Process

### Before Credit Expiry

1. **Export Database**:

   ```bash
   # On current Azure VM
   docker exec techdukkan-postgres pg_dump -U postgres -d medusa-db > backup-YYYYMMDD.sql
   ```

2. **Document Current Setup**:
   - Note Azure PostgreSQL connection details
   - Save storage account keys locally
   - Document current domain DNS settings

### Setting Up New Account

1. **Provision Azure Resources** (same naming convention)
2. **Deploy Backend** using GitHub repo
3. **Import Database**:
   ```bash
   # Import to new Azure PostgreSQL
   psql "connection_string" < backup-YYYYMMDD.sql
   ```
4. **Re-sync Search Index**:
   ```bash
   # Re-index products in MeiliSearch
   node scripts/sync-products.js
   ```
5. **Update DNS** to point to new VM IP

## Security Best Practices

- Never commit production .env files to GitHub
- Store credentials locally in encrypted form
- Use different passwords for each Azure account
- Document but don't store Azure resource credentials in code

## Cost Optimization

- Account 1: Months 1-3 ($100 credit)
- Account 2: Months 4-6 ($100 credit)
- Account 3: Months 7-9 ($100 credit)
- Account 4: Months 10-12 ($100 credit)
- Account 5: Months 13-15 ($100 credit)
- Account 6: Months 16-18 ($100 credit)

Total: 18 months of hosting with ~$600 in credits
