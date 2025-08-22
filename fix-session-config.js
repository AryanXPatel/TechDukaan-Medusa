#!/usr/bin/env node

/**
 * Fix for Medusa v2.x Session Cookie Issue on External Domains
 * 
 * This script adds the necessary environment variables to fix the session
 * persistence issue where /admin/users/me returns 401 after successful login
 * when accessing Medusa from external domains.
 * 
 * Based on GitHub issues:
 * - #8578: /admin/users/me unauthorized, after login (via NGINX proxy server)
 * - #11722: Session Cookie Not Being Set
 */

const fs = require('fs');
const path = require('path');

console.log('🔧 Applying Medusa v2.x Session Cookie Fix...');

// Read current .env.production
const envPath = path.join(__dirname, '.env.production');
let envContent = fs.readFileSync(envPath, 'utf8');

// Add session-related environment variables if not present
const sessionEnvVars = [
  'SESSION_SECRET=' + (process.env.COOKIE_SECRET || 'eb57634bf9dd7338a655b17adf17c156'),
  'SESSION_COOKIE_HTTPONLY=true',
  'SESSION_COOKIE_SAMESITE=none',
  'SESSION_COOKIE_SECURE=true',
  'SESSION_COOKIE_NAME=medusa-session',
  'SESSION_COOKIE_MAX_AGE=604800000', // 7 days
];

// Check if session variables already exist
const hasSessionVars = sessionEnvVars.some(envVar => 
  envContent.includes(envVar.split('=')[0])
);

if (!hasSessionVars) {
  envContent += '\n\n# Session Configuration for External Domain Access\n';
  envContent += sessionEnvVars.join('\n') + '\n';
  
  fs.writeFileSync(envPath, envContent);
  console.log('✅ Added session configuration to .env.production');
} else {
  console.log('ℹ️  Session configuration already exists');
}

console.log('✨ Session cookie fix applied successfully!');
console.log('📋 Next steps:');
console.log('1. Git commit and push these changes');
console.log('2. On Azure VM: git pull');
console.log('3. On Azure VM: docker-compose -f docker-compose.production.yml down && docker-compose -f docker-compose.production.yml up -d');
console.log('4. Test admin login at http://52.237.83.34:9000/app');
