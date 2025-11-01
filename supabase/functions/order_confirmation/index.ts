/**
 * Supabase Edge Function: order_confirmation
 * 
 * Purpose:
 * - Receive forwarded payment confirmations from payment webhook handlers
 * - Validate requests using shared secret authentication
 * - Process order confirmations and update database
 * 
 * Migrated from: tools/cloudflare-worker/order_confirmation_worker.js
 * 
 * Environment Variables (set via: supabase secrets set KEY=value):
 * - ORDER_CONFIRMATION_SECRET: Shared secret for authenticating incoming requests
 * - SUPABASE_URL: Auto-configured by Supabase
 * - SUPABASE_SERVICE_ROLE_KEY: Auto-configured by Supabase
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface OrderConfirmation {
  orderId?: string;
  paymentIntentId?: string;
  amount?: number;
  currency?: string;
  status?: string;
  metadata?: Record<string, unknown>;
  provider?: string;
  raw?: unknown;
}

serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    // Validate shared secret
    const secret = Deno.env.get("ORDER_CONFIRMATION_SECRET");
    if (!secret) {
      console.error("ORDER_CONFIRMATION_SECRET not configured");
      return new Response("Server configuration error", { status: 500 });
    }

    // Check authentication - supports both Authorization header and X-Worker-Secret
    const authHeader = req.headers.get("authorization") || "";
    const secretHeader = req.headers.get("x-worker-secret") || "";
    
    const providedSecret = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7).trim()
      : secretHeader;

    if (!providedSecret || providedSecret !== secret) {
      return new Response("Unauthorized", { status: 401 });
    }

    // Parse request body
    let body: OrderConfirmation;
    try {
      body = await req.json();
    } catch (err) {
      console.error("Invalid JSON:", err);
      return new Response("Invalid JSON", { status: 400 });
    }

    // Initialize Supabase client with service role key for admin access
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Log the confirmation
    console.log("Order confirmation received:", JSON.stringify(body));

    // TODO: Add your business logic here
    // Examples:
    // 1. Update order status in database
    // 2. Send notification to user
    // 3. Update inventory
    // 4. Trigger fulfillment workflow

    // Example: Update order status (uncomment and modify based on your schema)
    /*
    if (body.orderId) {
      const { error } = await supabase
        .from('orders')
        .update({ 
          status: 'paid',
          payment_confirmed_at: new Date().toISOString(),
          payment_intent_id: body.paymentIntentId,
          payment_amount: body.amount,
          payment_currency: body.currency,
        })
        .eq('id', body.orderId);

      if (error) {
        console.error("Failed to update order:", error);
        return new Response(
          JSON.stringify({ error: "Failed to update order" }),
          { status: 500, headers: { "Content-Type": "application/json" } }
        );
      }
    }
    */

    // Return success response
    return new Response(
      JSON.stringify({ 
        ok: true, 
        message: "Order confirmation processed",
        orderId: body.orderId 
      }),
      { 
        status: 200, 
        headers: { "Content-Type": "application/json" } 
      }
    );

  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        message: error instanceof Error ? error.message : String(error)
      }),
      { 
        status: 500, 
        headers: { "Content-Type": "application/json" } 
      }
    );
  }
});
