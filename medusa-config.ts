import { loadEnv, defineConfig } from '@medusajs/framework/utils'

loadEnv(process.env.NODE_ENV || 'development', process.cwd())

module.exports = defineConfig({
  projectConfig: {
    databaseUrl: process.env.DATABASE_URL,
    redisUrl: process.env.REDIS_URL,
    http: {
      storeCors: process.env.STORE_CORS || "http://localhost:3000",
      adminCors: process.env.ADMIN_CORS || "http://localhost:3000", 
      authCors: process.env.AUTH_CORS || "http://localhost:3000",
      jwtSecret: process.env.JWT_SECRET || "supersecret",
      cookieSecret: process.env.COOKIE_SECRET || "supersecret",
    },
    // Azure Blob Storage configuration
    ...(process.env.STORAGE_PROVIDER === 'azure' && {
      fileService: {
        azure: {
          connectionString: process.env.STORAGE_CONNECTION_STRING,
          containerName: process.env.STORAGE_CONTAINER || 'product-images',
        }
      }
    })
  },
  modules: {
    // MeiliSearch integration
    ...(process.env.MEILI_HTTP_ADDR && {
      searchService: {
        resolve: "@medusajs/search",
        options: {
          provider: "meilisearch",
          config: {
            host: process.env.MEILI_HTTP_ADDR,
            apiKey: process.env.MEILI_MASTER_KEY,
          }
        }
      }
    })
  },
  featureFlags: {
    product_categories: true,
  }
})
