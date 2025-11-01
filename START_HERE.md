# 🚀 EASY DEPLOYMENT GUIDE - START HERE

## What I've Done For You ✅

I've migrated all your Cloudflare Workers and Firebase Functions to Supabase Edge Functions:
- ✅ 4 Edge Functions created and ready to deploy
- ✅ All documentation written
- ✅ Deployment scripts ready

---

## 🎯 What YOU Need to Do (3 Simple Steps)

### **STEP 1: Create Supabase Account** (2 minutes)

1. Go to: https://supabase.com/dashboard
2. Click "Start your project"
3. Sign up with GitHub (easiest)
4. Create a new project:
   - Project name: `canteen-app` (or whatever you want)
   - Database password: (create a strong password and SAVE IT)
   - Region: Choose closest to you (e.g., Southeast Asia)
   - Click "Create new project"
5. **Wait 2-3 minutes** for project to initialize

---

### **STEP 2: Get Your Project Details** (1 minute)

Once your project is ready:

1. Go to: **Settings** → **API**
2. Copy these values (you'll need them):
   - ✅ **Project URL** (looks like: `https://xxxxx.supabase.co`)
   - ✅ **anon public key** (looks like: `eyJhbGc...`)
   - ✅ **service_role key** (looks like: `eyJhbGc...` - keep this SECRET!)

3. Go to: **Settings** → **General**
4. Copy:
   - ✅ **Reference ID** (looks like: `abcdefghijk`)

---

### **STEP 3: Deploy Functions** (5 minutes)

#### A. Link Your Project

Open PowerShell in this folder and run:

```powershell
# Login (will open browser)
npx supabase login

# Link to your project (use Reference ID from Step 2)
npx supabase link --project-ref YOUR_REFERENCE_ID
```

#### B. Set Secrets

Run these commands (replace with YOUR actual keys):

```powershell
# For PayMongo (if you use it)
npx supabase secrets set PAYMONGO_SECRET=sk_test_your_key_here
npx supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsec_your_webhook_secret

# For Stripe (if you use it)
npx supabase secrets set STRIPE_SECRET=sk_test_your_key_here
npx supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret

# For order confirmation (create a random 32-character string)
npx supabase secrets set ORDER_CONFIRMATION_SECRET=your_random_32_char_string

# Set the order confirmation URL (use YOUR project URL)
npx supabase secrets set ORDER_CONFIRMATION_URL=https://YOUR_PROJECT_URL.supabase.co/functions/v1/order_confirmation
```

**To generate a random secret:**
```powershell
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})
```

#### C. Deploy Functions

```powershell
# Deploy all 4 functions
npx supabase functions deploy
```

**That's it!** Your functions are now live! 🎉

---

## 🔗 Your Function URLs

After deployment, your functions will be at:

```
https://YOUR_PROJECT_URL.supabase.co/functions/v1/order_confirmation
https://YOUR_PROJECT_URL.supabase.co/functions/v1/paymongo_webhook
https://YOUR_PROJECT_URL.supabase.co/functions/v1/stripe_webhook
https://YOUR_PROJECT_URL.supabase.co/functions/v1/set_user_role
```

---

## 📱 Update Your Flutter App

### 1. Add Supabase Package

In `pubspec.yaml`, add:

```yaml
dependencies:
  supabase_flutter: ^2.0.0
```

Run:
```bash
flutter pub get
```

### 2. Initialize in main.dart

Replace Firebase initialization with:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://YOUR_PROJECT_URL.supabase.co',
    anonKey: 'YOUR_ANON_KEY',
  );
  
  runApp(MyApp());
}
```

### 3. Use Supabase in Your Code

```dart
// Get Supabase client
final supabase = Supabase.instance.client;

// Sign in
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);

// Get current user
final user = supabase.auth.currentUser;

// Call Edge Function
final response = await supabase.functions.invoke(
  'paymongo_webhook/create-payment-session',
  body: {'amount': 10000, 'currency': 'PHP'},
);
```

---

## 🧪 Test Your Functions

### Test Order Confirmation

```powershell
$headers = @{
    "Authorization" = "Bearer YOUR_ANON_KEY"
    "X-Worker-Secret" = "YOUR_ORDER_CONFIRMATION_SECRET"
    "Content-Type" = "application/json"
}

$body = @{
    orderId = "test-123"
    amount = 1000
    currency = "PHP"
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://YOUR_PROJECT_URL.supabase.co/functions/v1/order_confirmation" -Method POST -Headers $headers -Body $body
```

### Test Set User Role

```powershell
$headers = @{
    "Authorization" = "Bearer YOUR_SERVICE_ROLE_KEY"
    "Content-Type" = "application/json"
}

$body = @{
    user_id = "user-uuid-here"
    isAdmin = $true
    isParent = $false
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://YOUR_PROJECT_URL.supabase.co/functions/v1/set_user_role" -Method POST -Headers $headers -Body $body
```

---

## 🔄 Update Webhook URLs

### PayMongo
1. Go to PayMongo Dashboard → Webhooks
2. Create/update webhook URL to:
   ```
   https://YOUR_PROJECT_URL.supabase.co/functions/v1/paymongo_webhook/webhook
   ```

### Stripe
1. Go to Stripe Dashboard → Webhooks
2. Create/update webhook endpoint to:
   ```
   https://YOUR_PROJECT_URL.supabase.co/functions/v1/stripe_webhook/webhook
   ```

---

## 🧹 After Everything Works

Delete old files:

```powershell
Remove-Item -Path "tools\cloudflare-worker" -Recurse -Force
Remove-Item -Path "tools\set_custom_claims.js" -Force
Remove-Item -Path "tools\migrate_user_roles.js" -Force
Remove-Item -Path "tools\serviceAccountKey.json" -Force
```

---

## 🆘 Need Help?

### View Function Logs
```powershell
npx supabase functions logs order_confirmation --follow
```

### List Deployed Functions
```powershell
npx supabase functions list
```

### Check Secrets
```powershell
npx supabase secrets list
```

---

## 📊 Summary

✅ You have 4 Edge Functions ready to deploy  
✅ Everything is FREE (500k requests/month)  
✅ No credit card required  
✅ Faster and cleaner than Cloudflare + Firebase  

**Next:** Follow Step 1, 2, and 3 above! 🚀

---

**Questions?** Check the other docs:
- `supabase/functions/README.md` - Detailed deployment guide
- `CLEANUP_MIGRATION_CHECKLIST.md` - Complete Flutter migration guide
- `QUICK_REFERENCE.md` - Quick commands reference
