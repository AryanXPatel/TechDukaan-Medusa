# 🔒 Security Guidelines for TechDukaan

## CRITICAL: Never Commit These Files to GitHub

```
.env.production           # Contains production secrets
.env.local               # Contains local secrets
*.pem                    # SSH keys
azure-credentials.json   # Azure service credentials
backups/*.sql           # Database dumps may contain sensitive data
```

## Safe to Commit (Templates Only)

```
.env.production.template # Template with placeholders
.env.template           # Template with placeholders
docker-compose.*.yml    # Uses environment variables
```

## Deployment Process

### Local Development

1. Copy `.env.template` to `.env`
2. Fill in local development values
3. Never commit `.env` files

### Production Deployment

1. Copy `.env.production.template` to `.env.production`
2. Fill in production values from Azure Portal
3. Never commit `.env.production` files
4. Store credentials securely locally

### Azure Migration

1. Export database: `pg_dump`
2. Save environment variables locally (encrypted)
3. Deploy to new Azure account using templates
4. Import database and re-sync search

## Key Rotation Schedule

- JWT/Cookie secrets: Every 90 days
- Azure Storage keys: Every 180 days
- Database passwords: Every 180 days
- SSH keys: Every 365 days

## Emergency Response

If secrets are accidentally committed:

1. Immediately rotate all exposed credentials
2. Remove from Git history: `git filter-branch`
3. Force push: `git push --force`
4. Update all deployments with new credentials
