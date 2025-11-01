/**
 * Supabase Edge Function: stripe_webhook
 * 
 * Purpose:
 * - Handle Stripe payment webhooks
 * - Create Stripe PaymentIntents
 * - Verify webhook signatures
 * - Forward confirmed payments to order confirmation handler
 * 
 * Migrated from: tools/cloudflare-worker/worker.js
 * 
 * Environment Variables (set via: supabase secrets set KEY=value):
 * - STRIPE_SECRET: Stripe API secret key
 * - STRIPE_WEBHOOK_SECRET: Stripe webhook signing secret
 * - ORDER_CONFIRMATION_URL: URL to forward payment confirmations (optional)
 * - ORDER_CONFIRMATION_SECRET: Secret for authenticating with order confirmation endpoint
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface PaymentIntentRequest {
  amount: number;
  currency?: string;
  clientOrderId?: string;
  customerEmail?: string;
  metadata?: Record<string, unknown>;
}

serve(async (req: Request) => {
  const url = new URL(req.url);

  try {
    // Route handling
    if (req.method === "POST" && url.pathname === "/create-payment-intent") {
      return await handleCreatePaymentIntent(req);
    }

    if (req.method === "POST" && url.pathname === "/webhook") {
      return await handleWebhook(req);
    }

    // Health check
    return new Response(
      JSON.stringify({ ok: true, message: "Stripe webhook handler active" }),
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
 * Create a Stripe PaymentIntent
 * Returns client_secret for client-side confirmation
 */
async function handleCreatePaymentIntent(req: Request): Promise<Response> {
  const stripeKey = Deno.env.get("STRIPE_SECRET");
  
  if (!stripeKey) {
    return new Response("Stripe secret not configured", { status: 500 });
  }

  let body: PaymentIntentRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Invalid JSON body" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Validate amount
  const amount = Number(body.amount);
  const currency = body.currency || "usd";

  if (!Number.isFinite(amount) || amount <= 0) {
    return new Response(
      JSON.stringify({ error: "Invalid amount" }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    );
  }

  // Build form data for Stripe API
  const formData = new URLSearchParams();
  formData.append("amount", String(Math.round(amount)));
  formData.append("currency", currency);
  
  if (body.clientOrderId) {
    formData.append("metadata[clientOrderId]", body.clientOrderId);
  }
  if (body.customerEmail) {
    formData.append("metadata[customerEmail]", body.customerEmail);
  }
  
  // Add any additional metadata
  if (body.metadata) {
    for (const [key, value] of Object.entries(body.metadata)) {
      formData.append(`metadata[${key}]`, String(value));
    }
  }

  try {
    const response = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${stripeKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: formData.toString(),
    });

    const text = await response.text();
    
    // Parse response
    let json: any;
    try {
      json = JSON.parse(text);
    } catch {
      return new Response(text, {
        status: response.status,
        headers: { "Content-Type": "text/plain" }
      });
    }

    // Return client_secret and payment intent id
    return new Response(
      JSON.stringify({
        client_secret: json.client_secret,
        id: json.id,
        raw: json
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Stripe API error:", error);
    return new Response(
      JSON.stringify({ error: "Failed to create payment intent" }),
      { status: 502, headers: { "Content-Type": "application/json" } }
    );
  }
}

/**
 * Handle Stripe webhook events
 * Verifies signature and processes payment_intent.succeeded events
 */
async function handleWebhook(req: Request): Promise<Response> {
  const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
  const orderConfirmationUrl = Deno.env.get("ORDER_CONFIRMATION_URL");
  const orderConfirmationSecret = Deno.env.get("ORDER_CONFIRMATION_SECRET");

  if (!webhookSecret) {
    return new Response("Webhook secret not configured", { status: 500 });
  }

  // Read raw body for signature verification
  const bodyBuffer = await req.arrayBuffer();
  const payload = new TextDecoder().decode(bodyBuffer);

  // Get Stripe signature header
  const sigHeader = req.headers.get("stripe-signature") || "";

  // Verify signature
  const verified = await verifyStripeSignature(payload, sigHeader, webhookSecret);
  if (!verified) {
    console.error("Invalid Stripe webhook signature");
    return new Response("Invalid signature", { status: 400 });
  }

  // Parse event
  let event: any;
  try {
    event = JSON.parse(payload);
  } catch {
    return new Response("Invalid payload", { status: 400 });
  }

  console.log("Received Stripe webhook:", event.type);

  // Handle payment_intent.succeeded event
  if (event.type === "payment_intent.succeeded") {
    const paymentIntent = event.data.object;

    // Build confirmation payload
    const confirmation = {
      provider: "stripe",
      paymentIntentId: paymentIntent.id,
      amount_received: paymentIntent.amount_received || paymentIntent.amount,
      currency: paymentIntent.currency,
      metadata: paymentIntent.metadata || {},
      status: paymentIntent.status,
      created: paymentIntent.created,
      raw: paymentIntent,
    };

    // Forward to order confirmation endpoint if configured
    if (orderConfirmationUrl) {
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

  // Acknowledge other event types
  return new Response(
    JSON.stringify({ received: true }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
}

/**
 * Verify Stripe webhook signature using HMAC-SHA256
 * Stripe format: t=timestamp,v1=signature
 */
async function verifyStripeSignature(
  payload: string,
  sigHeader: string,
  webhookSecret: string
): Promise<boolean> {
  if (!sigHeader) return false;

  try {
    // Parse signature header
    const parts = sigHeader.split(",");
    let timestamp: string | null = null;
    let v1: string | null = null;

    for (const part of parts) {
      const [key, value] = part.split("=");
      if (key === "t") timestamp = value;
      if (key === "v1") v1 = value;
    }

    if (!timestamp || !v1) return false;

    // Create signed payload: timestamp.payload
    const signedPayload = `${timestamp}.${payload}`;

    // Compute HMAC-SHA256
    const encoder = new TextEncoder();
    const keyData = encoder.encode(webhookSecret);
    const msgData = encoder.encode(signedPayload);

    const key = await crypto.subtle.importKey(
      "raw",
      keyData,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );

    const signature = await crypto.subtle.sign("HMAC", key, msgData);
    const sigHex = Array.from(new Uint8Array(signature))
      .map(b => b.toString(16).padStart(2, "0"))
      .join("");

    // Compare signatures (Stripe uses hex encoding)
    return sigHex === v1;
  } catch (error) {
    console.error("Signature verification error:", error);
    return false;
  }
}
