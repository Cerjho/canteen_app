/**
 * Supabase Edge Function: paymongo_webhook
 * 
 * Purpose:
 * - Handle PayMongo payment webhooks
 * - Create payment intents and payment links
 * - Verify webhook signatures
 * - Forward confirmed payments to order confirmation handler
 * 
 * Migrated from: tools/cloudflare-worker/paymongo_worker.js
 * 
 * Environment Variables (set via: supabase secrets set KEY=value):
 * - PAYMONGO_SECRET: PayMongo API secret key
 * - PAYMENT_PROVIDER_API_BASE: PayMongo API base URL (default: https://api.paymongo.com/v1)
 * - PAYMONGO_WEBHOOK_SECRET: PayMongo webhook signing secret
 * - ORDER_CONFIRMATION_URL: URL to forward payment confirmations (optional)
 * - ORDER_CONFIRMATION_SECRET: Secret for authenticating with order confirmation endpoint
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface PaymentRequest {
  amount: number;
  currency?: string;
  payment_method_id?: string;
  return_url?: string;
  metadata?: Record<string, unknown>;
  orderId?: string;
  description?: string;
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  try {
    // Route handling
    if (req.method === "POST" && url.pathname === "/create-payment") {
      return await handleCreatePayment(req);
    }

    if (req.method === "POST" && url.pathname === "/create-payment-session") {
      return await handleCreatePaymentSession(req);
    }

    if (req.method === "POST" && url.pathname === "/webhook") {
      return await handleWebhook(req);
    }

    // Health check
    return new Response(
      JSON.stringify({ ok: true, message: "PayMongo webhook handler active" }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Unexpected error:", error);
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : String(error) 
      }),
      { 
        status: 500, 
        headers: { "Content-Type": "application/json" } 
      }
    );
  }
});

/**
 * Create a PayMongo payment
 * Expects: { amount, currency, payment_method_id, return_url, metadata }
 */
async function handleCreatePayment(req: Request): Promise<Response> {
  const providerSecret = Deno.env.get("PAYMONGO_SECRET");
  const apiBase = Deno.env.get("PAYMENT_PROVIDER_API_BASE") || "https://api.paymongo.com/v1";

  if (!providerSecret) {
    return new Response("Payment provider secret not configured", { status: 500 });
  }

  let body: PaymentRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  if (!body.amount) {
    return new Response(
      JSON.stringify({ error: "Missing required field: amount" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Build PayMongo payment payload
  const paymongoPayload = {
    data: {
      attributes: {
        amount: body.amount,
        currency: body.currency || "PHP",
        ...(body.payment_method_id && {
          payment_method: { type: "token", token: body.payment_method_id }
        }),
        ...(body.return_url && { return_url: body.return_url }),
        ...(body.metadata && { metadata: body.metadata }),
      }
    }
  };

  const endpoint = `${apiBase}/payments`;
  
  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(providerSecret + ":")}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify(paymongoPayload),
    });

    const text = await response.text();
    return new Response(text, {
      status: response.status,
      headers: { "Content-Type": "application/json" }
    });
  } catch (error) {
    console.error("PayMongo API error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to create payment" }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * Create a PayMongo hosted checkout session (Payment Link)
 * Expects: { amount, currency, return_url, metadata, orderId, description }
 */
async function handleCreatePaymentSession(req: Request): Promise<Response> {
  const providerSecret = Deno.env.get("PAYMONGO_SECRET");
  const apiBase = Deno.env.get("PAYMENT_PROVIDER_API_BASE") || "https://api.paymongo.com/v1";

  if (!providerSecret) {
    return new Response("Payment provider secret not configured", { status: 500 });
  }

  let body: PaymentRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  if (!body.amount) {
    return new Response(
      JSON.stringify({ error: "Missing required field: amount" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Build PayMongo Payment Link payload
  const payload = {
    data: {
      attributes: {
        amount: body.amount,
        currency: body.currency || "PHP",
        redirect: {
          success: body.return_url || "",
          failed: body.return_url || ""
        },
        metadata: body.metadata || {},
        description: body.description || `Order ${body.orderId || ""}`
      }
    }
  };

  const endpoint = `${apiBase}/links`;

  try {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(providerSecret + ":")}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      body: JSON.stringify(payload),
    });

    const json = await response.json();
    
    // Extract checkout URL from PayMongo response
    const checkoutUrl = json.data?.attributes?.url || json.checkout_url || null;
    
    return new Response(
      JSON.stringify({ checkout_url: checkoutUrl, raw: json }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("PayMongo API error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to create payment session" }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * Handle PayMongo webhook events
 * Verifies signature and forwards successful payments to order confirmation
 */
async function handleWebhook(req: Request): Promise<Response> {
  const webhookSecret = Deno.env.get("PAYMONGO_WEBHOOK_SECRET");
  const orderConfirmationUrl = Deno.env.get("ORDER_CONFIRMATION_URL");
  const orderConfirmationSecret = Deno.env.get("ORDER_CONFIRMATION_SECRET");

  // Read raw body for signature verification
  const bodyBuffer = await req.arrayBuffer();
  const payload = new TextDecoder().decode(bodyBuffer);

  // Get signature header (PayMongo uses various header names)
  const sigHeader = 
    req.headers.get("paymongo-signature") ||
    req.headers.get("Paymongo-Signature") ||
    req.headers.get("signature") ||
    "";

  // Verify signature if webhook secret is configured
  if (webhookSecret) {
    const verified = await verifyPaymongoSignature(payload, sigHeader, webhookSecret);
    if (!verified) {
      console.error("Invalid webhook signature");
      return new Response("Invalid signature", { status: 400 });
    }
  }

  // Parse event
  let event: any;
  try {
    event = JSON.parse(payload);
  } catch {
    return new Response("Invalid JSON payload", { status: 400 });
  }

  console.log("Received PayMongo webhook:", event.type);

  // Forward successful payment events to order confirmation endpoint
  if (orderConfirmationUrl) {
    const confirmation = {
      provider: "paymongo",
      event: event.type || null,
      data: event.data || event,
    };

    try {
      await fetch(orderConfirmationUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(orderConfirmationSecret && {
            "X-Worker-Secret": orderConfirmationSecret
          })
        },
        body: JSON.stringify(confirmation),
      });
      console.log("Forwarded confirmation to:", orderConfirmationUrl);
    } catch (error) {
      console.error("Failed to forward confirmation:", error);
      // Don't fail the webhook - we've received it
    }
  }

  return new Response(
    JSON.stringify({ received: true }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
}

/**
 * Verify PayMongo webhook signature using HMAC-SHA256
 * Supports both timestamped (Stripe-style) and simple HMAC signatures
 */
async function verifyPaymongoSignature(
  payload: string,
  sigHeader: string,
  secret: string,
  toleranceSeconds = 300
): Promise<boolean> {
  if (!sigHeader) return false;

  try {
    // Parse signature header for timestamp and signature
    const parts = sigHeader.split(",").map(p => p.trim());
    let timestamp: string | null = null;
    let v1: string | null = null;

    for (const part of parts) {
      const [key, value] = part.split("=");
      if (!key || !value) continue;
      if (key === "t") timestamp = value;
      if (key === "v1") v1 = value;
    }

    const encoder = new TextEncoder();
    const keyData = encoder.encode(secret);
    const key = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    // Timestamped signature (t=timestamp, v1=signature)
    if (timestamp && v1) {
      // Validate timestamp freshness
      const now = Math.floor(Date.now() / 1000);
      const ts = Number(timestamp);
      if (!Number.isFinite(ts)) return false;
      if (Math.abs(now - ts) > toleranceSeconds) {
        console.warn("Webhook timestamp outside tolerance window");
        return false;
      }

      const signedPayload = `${timestamp}.${payload}`;
      const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(signedPayload));
      const sigHex = Array.from(new Uint8Array(signature))
        .map(b => b.toString(16).padStart(2, "0"))
        .join("");

      if (sigHex === v1) return true;

      // Try base64 comparison
      const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)));
      if (sigB64 === v1) return true;

      return false;
    }

    // Simple HMAC signature (no timestamp)
    const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(payload));
    const sigHex = Array.from(new Uint8Array(signature))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    if (sigHex === sigHeader) return true;

    // Try base64
    const sigB64 = btoa(String.fromCharCode(...new Uint8Array(signature)));
    if (sigB64 === sigHeader) return true;

    return false;
  } catch (error) {
    console.error("Signature verification error:", error);
    return false;
  }
}
