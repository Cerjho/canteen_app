# Supabase Edge Functions Deployment Guide

## 📋 Overview

This directory contains Supabase Edge Functions that replace the previous Cloudflare Workers and Firebase Functions setup.

### Available Functions

1. **order_confirmation** - Handles order confirmation webhooks
2. **paymongo_webhook** - PayMongo payment processing and webhooks
3. **stripe_webhook** - Stripe payment processing and webhooks
4. **set_user_role** - User role management (replaces Firebase custom claims)

---

## 🚀 Quick Start

### 1. Install Supabase CLI

```bash
# Windows (PowerShell)
scoop install supabase

# Or using npm (cross-platform)
npm install -g supabase
```

### 2. Login to Supabase

```bash
supabase login
```

### 3. Link Your Project

```bash
# From your project root
supabase link --project-ref YOUR_PROJECT_REF
```

Get your project ref from: https://supabase.com/dashboard/project/YOUR_PROJECT/settings/general

### 4. Set Environment Secrets

```bash
# Required for all functions
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# For PayMongo
supabase secrets set PAYMONGO_SECRET=sk_test_your_key
supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsec_your_webhook_secret

# For Stripe (if used)
supabase secrets set STRIPE_SECRET=sk_test_your_key
supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# For order confirmation
supabase secrets set ORDER_CONFIRMATION_SECRET=your_random_secret
supabase secrets set ORDER_CONFIRMATION_URL=https://YOUR_PROJECT.supabase.co/functions/v1/order_confirmation
```

**Note:** Generate a secure random secret for `ORDER_CONFIRMATION_SECRET`:

```bash
# PowerShell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})

# Or use online generator: https://www.random.org/strings/
```

### 5. Deploy Functions

Deploy all functions:

```bash
supabase functions deploy
```

Or deploy individually:

```bash
supabase functions deploy order_confirmation
supabase functions deploy paymongo_webhook
supabase functions deploy stripe_webhook
supabase functions deploy set_user_role
```

### 6. Test Functions Locally

```bash
# Start local Supabase (includes all services)
supabase start

# Serve a specific function
supabase functions serve order_confirmation --no-verify-jwt

# Test with curl
curl -i --location --request POST 'http://localhost:54321/functions/v1/order_confirmation' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json' \
  --header 'X-Worker-Secret: test_secret' \
  --data '{"orderId":"test-123","amount":1000}'
```

---

## 🔐 Environment Variables Reference

### Auto-Configured (by Supabase)

- `SUPABASE_URL` - Your project URL
- `SUPABASE_ANON_KEY` - Public anonymous key
- `SUPABASE_SERVICE_ROLE_KEY` - Admin key (keep secret!)

### Required Secrets

| Secret | Used By | Description |
|--------|---------|-------------|
| `PAYMONGO_SECRET` | paymongo_webhook | PayMongo API secret key |
| `PAYMONGO_WEBHOOK_SECRET` | paymongo_webhook | PayMongo webhook signing secret |
| `STRIPE_SECRET` | stripe_webhook | Stripe API secret key |
| `STRIPE_WEBHOOK_SECRET` | stripe_webhook | Stripe webhook signing secret |
| `ORDER_CONFIRMATION_SECRET` | order_confirmation | Shared secret for webhook authentication |
| `ORDER_CONFIRMATION_URL` | paymongo_webhook, stripe_webhook | URL to forward confirmations |

### Managing Secrets

```bash
# List all secrets
supabase secrets list

# Set a secret
supabase secrets set KEY=value

# Set multiple secrets
supabase secrets set KEY1=value1 KEY2=value2

# Unset a secret
supabase secrets unset KEY
```

---

## 📡 Function URLs

After deployment, your functions are available at:

```
https://YOUR_PROJECT.supabase.co/functions/v1/FUNCTION_NAME
```

Example:
```
https://abcdefgh.supabase.co/functions/v1/order_confirmation
https://abcdefgh.supabase.co/functions/v1/paymongo_webhook
https://abcdefgh.supabase.co/functions/v1/stripe_webhook
https://abcdefgh.supabase.co/functions/v1/set_user_role
```

---

## 🧪 Testing Functions

### Test order_confirmation

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/order_confirmation \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "X-Worker-Secret: YOUR_ORDER_CONFIRMATION_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "orderId": "test-123",
    "amount": 1000,
    "currency": "PHP",
    "status": "paid"
  }'
```

### Test set_user_role

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/set_user_role \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user-uuid-here",
    "isAdmin": true,
    "isParent": false
  }'
```

### Test PayMongo create payment session

```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/paymongo_webhook/create-payment-session \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100000,
    "currency": "PHP",
    "return_url": "https://yourapp.com/payment-success",
    "orderId": "ORDER-123"
  }'
```

---

## 📊 Monitoring & Logs

### View Function Logs

```bash
# View logs for a specific function
supabase functions logs order_confirmation

# Follow logs in real-time
supabase functions logs order_confirmation --follow

# View logs from all functions
supabase functions logs
```

### Dashboard Monitoring

View metrics and logs in the Supabase Dashboard:
https://supabase.com/dashboard/project/YOUR_PROJECT/functions

---

## 🔄 Webhook Configuration

### PayMongo Webhook Setup

1. Go to PayMongo Dashboard → Webhooks
2. Create new webhook with URL: `https://YOUR_PROJECT.supabase.co/functions/v1/paymongo_webhook/webhook`
3. Select events: `payment.paid`, `payment.failed`
4. Copy the webhook signing secret and set it:
   ```bash
   supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsec_...
   ```

### Stripe Webhook Setup

1. Go to Stripe Dashboard → Webhooks
2. Add endpoint: `https://YOUR_PROJECT.supabase.co/functions/v1/stripe_webhook/webhook`
3. Select events: `payment_intent.succeeded`, `payment_intent.payment_failed`
4. Copy the webhook signing secret:
   ```bash
   supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...
   ```

---

## 🛠️ Development Workflow

### Local Development

```bash
# Start local Supabase stack
supabase start

# Make changes to function code
# Functions are in: supabase/functions/*/index.ts

# Test locally
supabase functions serve function_name --no-verify-jwt

# Deploy when ready
supabase functions deploy function_name
```

### CI/CD with GitHub Actions

Create `.github/workflows/deploy-functions.yml`:

```yaml
name: Deploy Supabase Functions

on:
  push:
    branches: [main]
    paths:
      - 'supabase/functions/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        
      - name: Deploy functions
        run: supabase functions deploy --project-ref ${{ secrets.SUPABASE_PROJECT_REF }}
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
```

---

## 🐛 Troubleshooting

### Function deployment fails

```bash
# Check function syntax
deno check supabase/functions/function-name/index.ts

# View detailed logs
supabase functions logs function-name --follow
```

### "Cannot find module" errors in editor

These are expected - the Deno imports work in the Supabase Edge runtime. You can ignore these TypeScript errors, or add a `deno.json` configuration file.

### Webhook signature verification fails

- Ensure webhook secrets are correctly set
- Check webhook URL is correct in payment provider dashboard
- Verify you're using the signing secret, not the API key

### Function times out

- Edge Functions have a 150-second timeout
- For long-running tasks, consider using Supabase Database Webhooks or pg_cron

---

## 📚 Additional Resources

- [Supabase Edge Functions Docs](https://supabase.com/docs/guides/functions)
- [Deno Documentation](https://deno.land/manual)
- [PayMongo API Reference](https://developers.paymongo.com/reference)
- [Stripe API Reference](https://stripe.com/docs/api)

---

## 🔄 Migration Checklist

- [x] Create Edge Functions
- [ ] Deploy to Supabase
- [ ] Configure webhooks in payment providers
- [ ] Test all payment flows
- [ ] Update Flutter app to call new function URLs
- [ ] Remove Cloudflare Workers
- [ ] Remove Firebase Functions
- [ ] Delete `/tools/cloudflare-worker/` directory
- [ ] Update environment variables in Flutter app

---

**Last Updated:** November 1, 2025
