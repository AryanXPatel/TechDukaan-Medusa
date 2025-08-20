import { MedusaRequest, MedusaResponse } from "@medusajs/framework";
import { ProductService } from "@medusajs/medusa";

export const POST = async (req: MedusaRequest, res: MedusaResponse) => {
  const productService = req.scope.resolve<ProductService>("productService");

  try {
    const products = await productService.list({});

    for (const product of products) {
      console.log(`Syncing product: ${product.title}`);
      // In a real-world scenario, you would add your logic here to sync the product with an external service.
    }

    res.status(200).json({ message: "Product sync started successfully." });
  } catch (error) {
    console.error("Product sync failed:", error);
    res.status(500).json({ message: "Product sync failed." });
  }
};
