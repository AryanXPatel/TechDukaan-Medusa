import { MedusaRequest, MedusaResponse } from "@medusajs/framework";

export const POST = async (req: MedusaRequest, res: MedusaResponse) => {
  try {
    // Use type assertion for the productService to fix TypeScript error
    const productService = req.scope.resolve("productService") as any;
    
    const products = await productService.list({});

    for (const product of products) {
      console.log(`Syncing product: ${product.title}`);
      // In a real-world scenario, you would add your logic here to sync the product with an external service.
    }

    res.status(200).json({ 
      message: "Product sync started successfully.",
      synced_count: products.length 
    });
  } catch (error) {
    console.error("Product sync failed:", error);
    res.status(500).json({ 
      message: "Product sync failed.",
      error: error instanceof Error ? error.message : "Unknown error"
    });
  }
};
