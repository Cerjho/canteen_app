# 🧹 Cleanup & Migration Checklist

This document outlines all the steps needed to complete the migration from Firebase + Cloudflare to Supabase.

---

## 📋 Phase 1: Files to Delete

### 1. Cloudflare Workers (entire directory)

```
✗ tools/cloudflare-worker/
  ├── .wrangler/
  ├── order_confirmation_worker.js
  ├── paymongo_worker.js
  ├── worker.js
  ├── wrangler.toml
  ├── wrangler.order_confirmation.toml
  ├── README-payments.md
  └── setup_wrangler_secrets.ps1
```

**Action:**

```powershell
Remove-Item -Path "tools/cloudflare-worker" -Recurse -Force
```

### 2. Firebase Admin Scripts

```
✗ tools/set_custom_claims.js
✗ tools/migrate_user_roles.js
✗ tools/serviceAccountKey.json
```

**Action:**

```powershell
Remove-Item -Path "tools/set_custom_claims.js" -Force
Remove-Item -Path "tools/migrate_user_roles.js" -Force
Remove-Item -Path "tools/serviceAccountKey.json" -Force
```

### 3. Firebase Configuration Files (optional - if fully migrating)

```
✗ firebase.json
✗ firestore.rules
✗ firestore.indexes.json
✗ deploy_firestore_rules.ps1
```

**Note:** Only delete these after migrating all Firestore data to Supabase Postgres.

---

## 📦 Phase 2: Update Dependencies

### Remove Firebase & Cloudflare Dependencies

**In `tools/package.json`:**

```powershell
cd tools
npm uninstall firebase firebase-admin wrangler
```

**In Flutter `pubspec.yaml`:**

Remove:

```yaml
dependencies:
  firebase_core: ^x.x.x
  firebase_auth: ^x.x.x
  cloud_firestore: ^x.x.x
  firebase_storage: ^x.x.x
  firebase_analytics: ^x.x.x
  firebase_crashlytics: ^x.x.x
```

Add:

```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

Run:

```bash
flutter pub get
```

---

## 🔄 Phase 3: Update Flutter App Code

### 1. Initialize Supabase (replace Firebase initialization)

**File:** `lib/main.dart`

Replace Firebase initialization:

```dart
// OLD - Remove this
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

With Supabase initialization:

```dart
// NEW - Add this
await Supabase.initialize(
  url: 'https://YOUR_PROJECT.supabase.co',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```

### 2. Update Authentication Calls

**OLD (Firebase Auth):**

```dart
final user = FirebaseAuth.instance.currentUser;
await FirebaseAuth.instance.signInWithEmailAndPassword(
  email: email,
  password: password,
);
```

**NEW (Supabase Auth):**

```dart
final user = Supabase.instance.client.auth.currentUser;
await Supabase.instance.client.auth.signInWithPassword(
  email: email,
  password: password,
);
```

### 3. Update Database Queries

**OLD (Firestore):**

```dart
final snapshot = await FirebaseFirestore.instance
  .collection('orders')
  .where('userId', isEqualTo: userId)
  .get();

final orders = snapshot.docs.map((doc) => Order.fromJson(doc.data())).toList();
```

**NEW (Supabase):**

```dart
final response = await Supabase.instance.client
  .from('orders')
  .select()
  .eq('user_id', userId);

final orders = (response as List).map((json) => Order.fromJson(json)).toList();
```

### 4. Update Storage Calls

**OLD (Firebase Storage):**

```dart
final ref = FirebaseStorage.instance.ref('uploads/avatar.png');
await ref.putFile(file);
final url = await ref.getDownloadURL();
```

**NEW (Supabase Storage):**

```dart
await Supabase.instance.client.storage
  .from('uploads')
  .upload('avatar.png', file);

final url = Supabase.instance.client.storage
  .from('uploads')
  .getPublicUrl('avatar.png');
```

### 5. Update Role Checking

**OLD (Firebase Custom Claims):**

```dart
final idTokenResult = await FirebaseAuth.instance.currentUser?.getIdTokenResult();
final isAdmin = idTokenResult?.claims?['admin'] == true;
final isParent = idTokenResult?.claims?['parent'] == true;
```

**NEW (Supabase User Metadata):**

```dart
final user = Supabase.instance.client.auth.currentUser;
final isAdmin = user?.userMetadata?['isAdmin'] == true;
final isParent = user?.userMetadata?['isParent'] == true;

// Refresh session to get updated metadata
await Supabase.instance.client.auth.refreshSession();
```

### 6. Update Payment Function Calls

**OLD (Cloudflare Worker):**

```dart
final response = await http.post(
  Uri.parse('https://your-worker.workers.dev/create-payment-session'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'amount': 10000}),
);
```

**NEW (Supabase Edge Function):**

```dart
final response = await Supabase.instance.client.functions.invoke(
  'paymongo_webhook/create-payment-session',
  body: {'amount': 10000, 'currency': 'PHP'},
);
```

---

## 🗄️ Phase 4: Database Migration

### 1. Export Firestore Data

```bash
# Install firebase-tools
npm install -g firebase-tools

# Export Firestore data
firebase firestore:export ./firestore-export
```

### 2. Create Supabase Tables

Create migration file: `supabase/migrations/001_initial_schema.sql`

Example:

```sql
-- Users table
create table users (
  id uuid references auth.users primary key,
  email text unique not null,
  full_name text,
  is_admin boolean default false,
  is_parent boolean default true,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Orders table
create table orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references users(id),
  amount integer not null,
  currency text default 'PHP',
  status text default 'pending',
  payment_intent_id text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Enable Row Level Security
alter table users enable row level security;
alter table orders enable row level security;

-- Users can read their own data
create policy "Users can read own data"
  on users for select
  using (auth.uid() = id);

-- Users can read their own orders
create policy "Users can read own orders"
  on orders for select
  using (auth.uid() = user_id);
```

### 3. Import Data

Create seed file: `supabase/seeds/seed.sql` or use a script to transform and import JSON data.

```bash
# Apply migration
supabase db push
```

---

## 🔐 Phase 5: Environment Variables

### Update Flutter Environment Variables

Create/update `.env` file:

```bash
# OLD - Remove these
FIREBASE_API_KEY=xxx
FIREBASE_PROJECT_ID=xxx
CLOUDFLARE_WORKER_URL=xxx

# NEW - Add these
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key
```

### GitHub Secrets (for CI/CD)

Update repository secrets:

1. Remove: `FIREBASE_SERVICE_ACCOUNT`, `CLOUDFLARE_API_TOKEN`
2. Add: `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`

---

## ✅ Phase 6: Testing Checklist

### Authentication

- [ ] Sign up new user
- [ ] Sign in existing user
- [ ] Sign out
- [ ] Password reset
- [ ] Email verification

### Database

- [ ] Read data (orders, menu items, etc.)
- [ ] Write data
- [ ] Update data
- [ ] Delete data
- [ ] Real-time subscriptions (if used)

### Storage

- [ ] Upload files
- [ ] Download files
- [ ] Delete files
- [ ] Get public URLs

### Payments

- [ ] Create payment session (PayMongo/Stripe)
- [ ] Handle successful payment webhook
- [ ] Handle failed payment webhook
- [ ] Order confirmation flow

### User Roles

- [ ] Set user as admin
- [ ] Set user as parent
- [ ] Check role in Flutter app
- [ ] Verify RLS policies work correctly

---

## 🚀 Phase 7: Deployment

### 1. Deploy Edge Functions

```bash
supabase functions deploy
```

### 2. Update Webhooks

- [ ] Update PayMongo webhook URL
- [ ] Update Stripe webhook URL
- [ ] Test webhook deliveries

### 3. Deploy Flutter App

```bash
flutter build appbundle  # For Android
flutter build ipa        # For iOS
flutter build web        # For Web
```

### 4. Monitor for Issues

- [ ] Check Supabase function logs
- [ ] Monitor error rates
- [ ] Test payment flows in production
- [ ] Verify user authentication

---

## 🗑️ Phase 8: Final Cleanup

After confirming everything works:

### 1. Archive Firebase Project

- Download final backup of Firestore data
- Disable Firebase services (but keep for historical reference)
- Remove Firebase config from Flutter app

### 2. Delete Cloudflare Workers

- Delete workers from Cloudflare dashboard
- Remove wrangler.toml files

### 3. Clean Up Git Repository

```bash
git rm -r tools/cloudflare-worker
git rm tools/set_custom_claims.js
git rm tools/migrate_user_roles.js
git rm tools/serviceAccountKey.json

git commit -m "chore: migrate from Firebase+Cloudflare to Supabase"
git push
```

### 4. Update Documentation

- [ ] Update README.md
- [ ] Update API documentation
- [ ] Update deployment instructions
- [ ] Archive old Firebase/Cloudflare docs

---

## 📊 Migration Progress Tracker

| Component | Status | Notes |
|-----------|--------|-------|
| Supabase Edge Functions | ✅ Created | All 4 functions migrated |
| Firebase → Supabase Auth | ⏳ Pending | Update Flutter code |
| Firestore → Postgres | ⏳ Pending | Create schema & migrate data |
| Firebase Storage → Supabase Storage | ⏳ Pending | Update Flutter code |
| Cloudflare Workers | ⏳ Pending | Delete after testing |
| Environment Variables | ⏳ Pending | Update in Flutter & CI/CD |
| Payment Webhooks | ⏳ Pending | Update URLs in provider dashboards |
| Testing | ⏳ Pending | Full QA pass |
| Deployment | ⏳ Pending | Deploy to production |
| Cleanup | ⏳ Pending | Remove old files |

---

## 🆘 Rollback Plan

If issues arise during migration:

### Quick Rollback Steps

1. **Keep Firebase credentials** until fully tested
2. **Use feature flags** to switch between Firebase and Supabase
3. **Test in staging** environment first
4. **Gradual rollout** - migrate one feature at a time

### Rollback Command

```dart
// Feature flag example
const useSupabase = false; // Set to true when ready

final authService = useSupabase 
  ? SupabaseAuthService() 
  : FirebaseAuthService();
```

---

**Migration Started:** November 1, 2025  
**Expected Completion:** [Your target date]  
**Status:** 🚧 In Progress

---

## 📝 Notes

- Test thoroughly in development before production deployment
- Keep Firebase active until migration is 100% complete and tested
- Monitor Supabase usage against free tier limits
- Document any custom business logic during migration

---

## 🎯 Success Criteria

Migration is complete when:

- ✅ All Edge Functions deployed and working
- ✅ All Firebase dependencies removed from codebase
- ✅ All authentication flows work with Supabase
- ✅ All database queries migrated to Postgres
- ✅ All payment webhooks tested and working
- ✅ Zero Firebase API calls in production
- ✅ Cloudflare Workers deleted
- ✅ Documentation updated
