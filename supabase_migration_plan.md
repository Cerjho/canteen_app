# 🧭 **Supabase Migration Plan**

## 🎯 **Goal**

Completely migrate the project's backend from **Firebase + Cloudflare Workers** to **Supabase**.
All authentication, APIs, and storage should use **Supabase services** — no Firebase, no Cloudflare, and no credit card required.

---

## 🗂️ **New Folder Structure**

```
root/
├── lib/
├── macos/
├── linux/
├── test/
├── tools/
│   ✗ cloudflare-worker/             # Remove this entire folder
├── supabase/
│   ├── functions/
│   │   ├── order_confirmation/
│   │   │    └── index.ts
│   │   ├── paymongo_webhook/
│   │   │    └── index.ts
│   │   ├── stripe_webhook/
│   │   │    └── index.ts
│   │   └── set_user_role/
│   │         └── index.ts
│   ├── migrations/
│   ├── seeds/
│   └── config.toml
├── package.json
├── README.md
└── supabase_migration_plan.md
```

---

## 🧱 **1. Auth Migration**

* Remove Firebase Auth and `serviceAccountKey.json`.
* Add Supabase SDK:

  ```bash
  npm install @supabase/supabase-js
  ```
* In Flutter:

  ```dart
  import 'package:supabase_flutter/supabase_flutter.dart';

  await Supabase.initialize(
    url: 'https://YOUR_PROJECT.supabase.co',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  ```
* Use `user_metadata` for roles instead of Firebase custom claims:

  ```ts
  const { error } = await supabase.auth.admin.updateUserById(uid, {
    user_metadata: { role: 'parent' }
  });
  ```

---

## ⚙️ **2. Edge Functions Setup**

Each Cloudflare Worker (e.g. `order_confirmation_worker.js`) becomes a Supabase Edge Function.

### Example: `/supabase/functions/order_confirmation/index.ts`

```ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

serve(async (req) => {
  const data = await req.json();
  // your order confirmation logic here
  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
```

Deploy and test:

```bash
supabase functions deploy order_confirmation
supabase functions serve order_confirmation
```

---

## 💾 **3. Database Migration**

* Convert Firestore collections → Postgres tables.
* Example:

  | Firestore Collection | Supabase Table |
  | -------------------- | -------------- |
  | `orders`             | `orders`       |
  | `menus`              | `menus`        |
  | `students`           | `students`     |
* Add RLS (Row Level Security) policies to replace Firestore rules.

Example policy (students can only access their data):

```sql
create policy "Students can read own data"
on students
for select
using (auth.uid() = user_id);
```

---

## 🧰 **4. Storage**

* Replace Firebase Storage with **Supabase Storage**.

```ts
const { data, error } = await supabase.storage
  .from('uploads')
  .upload('avatars/user.png', file);
```

---

## 🧹 **5. Cleanup Tasks**

* [ ] Delete `/tools/cloudflare-worker/`
* [ ] Delete Firebase service files
* [ ] Remove Firebase and Cloudflare dependencies:

  ```bash
  npm uninstall firebase wrangler
  ```
* [ ] Commit and update environment variables:

  ```
  SUPABASE_URL=
  SUPABASE_ANON_KEY=
  SUPABASE_SERVICE_ROLE_KEY=
  ```

---

## 🚀 **6. End State**

* All backend logic runs via **Supabase Edge Functions**
* Auth handled by **Supabase Auth**
* Data stored in **Supabase Postgres**
* File uploads handled by **Supabase Storage**
* Entire project runs **free** and **serverless**

---

## 📋 **Detailed Migration Checklist**

### Phase 1: Setup Supabase Project
- [ ] Create Supabase account (free tier, no credit card)
- [ ] Create new project at https://supabase.com/dashboard
- [ ] Install Supabase CLI: `npm install -g supabase`
- [ ] Initialize local project: `supabase init`
- [ ] Link to remote: `supabase link --project-ref YOUR_PROJECT_REF`

### Phase 2: Migrate Edge Functions
- [x] Create `/supabase/functions/` structure
- [ ] Migrate `order_confirmation_worker.js` → `order_confirmation/index.ts`
- [ ] Migrate `paymongo_worker.js` → `paymongo_webhook/index.ts`
- [ ] Migrate `worker.js` (Stripe) → `stripe_webhook/index.ts`
- [ ] Migrate `set_custom_claims.js` → `set_user_role/index.ts`
- [ ] Set secrets: `supabase secrets set KEY=value`
- [ ] Deploy functions: `supabase functions deploy`

### Phase 3: Database Migration
- [ ] Export Firestore data to JSON
- [ ] Create Postgres schema in `/supabase/migrations/`
- [ ] Import data using SQL scripts or seeds
- [ ] Set up RLS policies
- [ ] Test data access patterns

### Phase 4: Update Flutter App
- [ ] Add `supabase_flutter` to `pubspec.yaml`
- [ ] Remove Firebase packages
- [ ] Update authentication calls
- [ ] Update database queries (Firestore → Supabase)
- [ ] Update storage calls
- [ ] Update Edge Function URLs

### Phase 5: Testing
- [ ] Test auth flows (sign up, sign in, sign out)
- [ ] Test payment webhooks locally
- [ ] Test role assignment
- [ ] Test order confirmation flow
- [ ] Load test critical paths

### Phase 6: Cleanup
- [ ] Delete `/tools/cloudflare-worker/`
- [ ] Delete `serviceAccountKey.json`
- [ ] Delete Firebase config files
- [ ] Remove Firebase/Cloudflare from `package.json`
- [ ] Update README with new deployment instructions
- [ ] Archive old Firebase project

---

## 🔐 **Environment Variables**

### Required Secrets for Edge Functions

Set these using: `supabase secrets set KEY=value`

```bash
# Supabase (auto-configured)
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# PayMongo
PAYMONGO_SECRET=sk_test_...
PAYMONGO_WEBHOOK_SECRET=whsec_...

# Stripe (if used)
STRIPE_SECRET=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Order Confirmation
ORDER_CONFIRMATION_SECRET=your_random_secret_here
```

---

## 📚 **Resources**

- [Supabase Documentation](https://supabase.com/docs)
- [Edge Functions Guide](https://supabase.com/docs/guides/functions)
- [Auth Guide](https://supabase.com/docs/guides/auth)
- [Database Guide](https://supabase.com/docs/guides/database)
- [Flutter SDK](https://supabase.com/docs/reference/dart/introduction)

---

## ⚠️ **Important Notes**

1. **Free Tier Limits**: 500k Edge Function invocations/month (plenty for most apps)
2. **No Credit Card**: Supabase free tier requires no payment method
3. **Postgres vs Firestore**: Learn SQL - Postgres is relational, not document-based
4. **RLS is Critical**: Set up Row Level Security policies for data protection
5. **Test Locally**: Use `supabase start` to run local dev environment
6. **Migrations**: Use version-controlled SQL migrations for schema changes

---

## 🆘 **Troubleshooting**

### Edge Function won't deploy
```bash
# Check function syntax
deno check supabase/functions/function-name/index.ts

# View logs
supabase functions logs function-name
```

### Auth issues
```bash
# Check user metadata
select * from auth.users where id = 'user-id';
```

### Database connection issues
```bash
# Reset local database
supabase db reset

# Pull remote schema
supabase db pull
```

---

**Last Updated**: November 1, 2025  
**Status**: 🚧 Migration in progress
