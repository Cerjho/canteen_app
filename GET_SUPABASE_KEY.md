# 🔑 GET YOUR SUPABASE ANON KEY

## Quick Steps

### 1. Go to Your Supabase Dashboard

Open: <https://supabase.com/dashboard/project/rfossylqbksvffksutox>

### 2. Navigate to Settings

Click on **Settings** (gear icon) in the left sidebar

### 3. Go to API Settings

Click on **API** in the Settings menu

### 4. Copy Your Anon Key

Look for **Project API keys** section:

- Find **`anon` `public`** key
- Click the copy icon
- It looks like: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...`

### 5. Update .env File

Open `.env` file and replace:

```
SUPABASE_ANON_KEY=YOUR_ANON_KEY_HERE
```

With your actual key:

```
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

---

## ✅ After Updating .env

Run the app:

```powershell
# For mobile
flutter run

# For web admin
flutter run -d chrome --target lib/app/main_admin_web.dart
```

---

## 🎯 What I've Done

✅ Added `supabase_flutter` package to `pubspec.yaml`  
✅ Created `supabase_config.dart` for easy Supabase access  
✅ Updated `main_common.dart` to initialize Supabase  
✅ Updated `.env` file with Supabase URL  
✅ Ran `flutter pub get` to install dependencies  

---

## 📱 How to Use Supabase in Your Code

### Import

```dart
import 'package:canteen_app/core/config/supabase_config.dart';
```

### Get Supabase Client

```dart
final supabase = SupabaseConfig.client;
```

### Sign In

```dart
await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);
```

### Get Current User

```dart
final user = SupabaseConfig.currentUser;
final isAdmin = SupabaseConfig.isAdmin;
final isParent = SupabaseConfig.isParent;
```

### Query Database (when you migrate from Firestore)

```dart
final orders = await supabase
  .from('orders')
  .select()
  .eq('user_id', userId);
```

### Call Edge Function

```dart
final response = await SupabaseConfig.callFunction(
  'paymongo_webhook/create-payment-session',
  body: {'amount': 10000, 'currency': 'PHP'},
);
```

---

## 🔄 Migration Strategy

Your app now has **BOTH** Firebase and Supabase:

1. **Firebase** - Still active (for gradual migration)
2. **Supabase** - Ready to use (new features start here)

### Option A: Gradual Migration (Recommended)

- Keep existing Firebase code working
- Add new features using Supabase
- Migrate one feature at a time

### Option B: Full Migration

- Follow `CLEANUP_MIGRATION_CHECKLIST.md`
- Replace all Firebase calls with Supabase
- Remove Firebase after testing

---

## 🆘 Troubleshooting

### App crashes on start

- Make sure you added the anon key to `.env`
- Check the key doesn't have quotes around it
- Restart the app

### "Supabase not initialized" error

- The app initializes Supabase in `main_common.dart`
- Check the console for initialization errors

---

**Next:** Get your anon key and update `.env` file! 🚀
