# Use Node.js 20 Alpine for smaller image size
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    postgresql-client

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY . .

# Ensure .env file exists for production
RUN if [ -f .env.production ]; then cp .env.production .env; fi

# Build the application
RUN npm run build

# Install dependencies in the built directory
WORKDIR /app/.medusa/server
RUN npm install --production

# Copy environment file to built directory
RUN if [ -f /app/.env.production ]; then cp /app/.env.production .env; fi

# Create non-root user for security
RUN addgroup -g 1001 -S medusa && \
    adduser -S medusa -u 1001

# Change ownership of the app directory
RUN chown -R medusa:medusa /app

# Switch to non-root user
USER medusa

# Expose port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:9000/health || exit 1

# Default command (can be overridden for worker mode)
CMD ["sh", "-c", "NODE_ENV=production npm start"]
