# 🎯 Supabase Migration Quick Reference

## ⚡ Quick Commands

### Deploy Everything

```powershell
.\deploy_supabase_functions.ps1
```

### Manual Deployment

```powershell
# Deploy all functions
supabase functions deploy

# Deploy specific function
supabase functions deploy order_confirmation
```

### View Logs

```powershell
# Specific function
supabase functions logs order_confirmation --follow

# All functions
supabase functions logs --follow
```

### Set Secrets

```powershell
supabase secrets set PAYMONGO_SECRET=sk_test_xxx
supabase secrets set STRIPE_SECRET=sk_test_xxx
```

---

## 📋 Function URLs

After deployment, your functions are at:

```
https://YOUR_PROJECT.supabase.co/functions/v1/order_confirmation
https://YOUR_PROJECT.supabase.co/functions/v1/paymongo_webhook
https://YOUR_PROJECT.supabase.co/functions/v1/stripe_webhook
https://YOUR_PROJECT.supabase.co/functions/v1/set_user_role
```

---

## 🔐 Required Secrets

| Secret | Purpose |
|--------|---------|
| `PAYMONGO_SECRET` | PayMongo API key |
| `PAYMONGO_WEBHOOK_SECRET` | PayMongo webhook signature verification |
| `STRIPE_SECRET` | Stripe API key |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signature verification |
| `ORDER_CONFIRMATION_SECRET` | Shared secret for order confirmation |

---

## 🧪 Test Function (curl)

```powershell
# Order Confirmation
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/order_confirmation `
  -H "Authorization: Bearer YOUR_ANON_KEY" `
  -H "X-Worker-Secret: YOUR_SECRET" `
  -H "Content-Type: application/json" `
  -d '{"orderId":"test-123","amount":1000}'

# Set User Role
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/set_user_role `
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" `
  -H "Content-Type: application/json" `
  -d '{"user_id":"uuid-here","isAdmin":true}'
```

---

## 📱 Flutter Integration

### Initialize Supabase

```dart
await Supabase.initialize(
  url: 'https://YOUR_PROJECT.supabase.co',
  anonKey: 'YOUR_ANON_KEY',
);
```

### Call Function

```dart
final response = await Supabase.instance.client.functions.invoke(
  'paymongo_webhook/create-payment-session',
  body: {'amount': 10000, 'currency': 'PHP'},
);
```

### Check User Role

```dart
final user = Supabase.instance.client.auth.currentUser;
final isAdmin = user?.userMetadata?['isAdmin'] ?? false;
```

---

## 🗂️ File Structure

```
supabase/
├── config.toml                              # Project config
└── functions/
    ├── README.md                            # Deployment guide
    ├── order_confirmation/
    │   └── index.ts                         # Order confirmation handler
    ├── paymongo_webhook/
    │   └── index.ts                         # PayMongo integration
    ├── stripe_webhook/
    │   └── index.ts                         # Stripe integration
    └── set_user_role/
        └── index.ts                         # User role management
```

---

## 🧹 Files to Delete (After Testing)

```
✗ tools/cloudflare-worker/                  # Entire directory
✗ tools/set_custom_claims.js
✗ tools/migrate_user_roles.js
✗ tools/serviceAccountKey.json
```

---

## 📚 Documentation Files

1. **Migration Plan** → `supabase_migration_plan.md`
2. **Deployment Guide** → `supabase/functions/README.md`
3. **Cleanup Checklist** → `CLEANUP_MIGRATION_CHECKLIST.md`
4. **Summary** → `MIGRATION_SUMMARY.md`
5. **This Card** → `QUICK_REFERENCE.md`

---

## 🆘 Troubleshooting

### Function won't deploy

```powershell
# Check if logged in
supabase login

# Check if linked
supabase projects list
```

### Can't see logs

```powershell
# Ensure function is deployed
supabase functions list

# View logs with details
supabase functions logs function-name --follow
```

### Webhook signature fails

- Verify webhook secret is correct
- Check webhook URL in provider dashboard
- Ensure using signing secret (not API key)

---

## 💡 Tips

- Use `.\deploy_supabase_functions.ps1` for easy deployment
- Test locally with `supabase start` first
- Monitor logs during testing
- Keep Firebase active until fully tested
- Use feature flags for gradual migration

---

## 🎯 Next Actions

1. ✅ Deploy functions: `supabase functions deploy`
2. ✅ Set secrets: `.\deploy_supabase_functions.ps1` → option 8
3. ✅ Test functions: See `supabase/functions/README.md`
4. ✅ Update webhooks in PayMongo/Stripe dashboards
5. ✅ Update Flutter app code
6. ✅ Test thoroughly
7. ✅ Clean up old code

---

**Quick Start:** Run `.\deploy_supabase_functions.ps1` to get started! 🚀
