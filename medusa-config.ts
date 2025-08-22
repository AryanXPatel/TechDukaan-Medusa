import { loadEnv, defineConfig } from "@medusajs/framework/utils";

loadEnv(process.env.NODE_ENV || "development", process.cwd());

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
    // Cookie options for external domain access (available since v2.8.5)
    cookieOptions: {
      secure: false, // Set to false for HTTP external access
      sameSite: "lax", // Allow external IP access while maintaining security
      httpOnly: true, // Prevent XSS attacks
      maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
    },
    // Azure Blob Storage configuration
    ...(process.env.STORAGE_PROVIDER === "azure" && {
      fileService: {
        azure: {
          connectionString: process.env.STORAGE_CONNECTION_STRING,
          containerName: process.env.STORAGE_CONTAINER || "product-images",
        },
      },
    }),
  },
  plugins: [
    // MeiliSearch integration
    ...(process.env.MEILI_HTTP_ADDR
      ? [
          {
            resolve: "@rokmohar/medusa-plugin-meilisearch",
            options: {
              config: {
                host: process.env.MEILI_HTTP_ADDR,
                apiKey: process.env.MEILI_MASTER_KEY,
              },
              settings: {
                products: {
                  type: "products",
                  enabled: true,
                  fields: [
                    "id",
                    "title",
                    "description",
                    "handle",
                    "variant_sku",
                    "thumbnail",
                  ],
                  indexSettings: {
                    searchableAttributes: [
                      "title",
                      "description",
                      "variant_sku",
                    ],
                    displayedAttributes: [
                      "id",
                      "handle",
                      "title",
                      "description",
                      "variant_sku",
                      "thumbnail",
                    ],
                    filterableAttributes: ["id", "handle"],
                  },
                },
              },
            },
          },
        ]
      : []),
  ],
  featureFlags: {
    product_categories: true,
  },
});
