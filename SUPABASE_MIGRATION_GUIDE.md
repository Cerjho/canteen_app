# 🚀 SUPABASE MIGRATION IMPLEMENTATION GUIDE

## Overview

This guide provides step-by-step instructions to complete the Supabase migration for your Flutter canteen app. The migration has been **partially completed** with infrastructure in place.

---

## ✅ Completed Steps

1. **Supabase Edge Functions** - Deployed (order_confirmation, paymongo_webhook, stripe_webhook, set_user_role)
2. **Supabase SDK** - Integrated (supabase_flutter ^2.8.0)
3. **Firebase Removal** - All Firebase packages and config files removed
4. **Supabase Config Helper** - Created `lib/core/config/supabase_config.dart`
5. **Supabase Providers** - Created `lib/core/providers/supabase_providers.dart`
6. **Database Schema** - Created `supabase/migrations/00001_initial_schema.sql`

---

## 📋 Remaining Migration Tasks

### STEP 1: Deploy Database Schema to Supabase

```powershell
# Navigate to project root
cd c:\Developments\flutter\canteen_app

# Deploy migration
npx supabase db push

# Verify tables created
npx supabase db diff
```

**Expected Result:** All tables (users, parents, students, menu_items, weekly_menus, orders, parent_transactions, topup_requests, weekly_menu_analytics) created in Postgres.

---

### STEP 2: Update Interface Files

#### `lib/core/interfaces/i_auth_service.dart`

**Current:** Uses `firebase_auth` types
**Update:** Remove Firebase imports

```dart
// REMOVE
import 'package:firebase_auth/firebase_auth.dart';

// ADD
import 'package:supabase_flutter/supabase_flutter.dart' show User, AuthResponse;

// UPDATE method signatures:
// - Replace UserCredential with AuthResponse
// - Replace firebase User with supabase User
```

---

### STEP 3: Refactor Auth Service

#### `lib/core/services/auth_service.dart`

**Key Changes:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AuthService implements IAuthService {
  final SupabaseClient _supabase;
  final UserService _userService;
  final RegistrationService _registrationService;

  AuthService({
    required SupabaseClient supabase,
    required UserService userService,
    required RegistrationService registrationService,
  })  : _supabase = supabase,
        _userService = userService,
        _registrationService = registrationService;

  // Get current user
  @override
  User? get currentUser => _supabase.auth.currentUser;

  // Auth state stream
  @override
  Stream<User?> get authStateChanges => 
    _supabase.auth.onAuthStateChange.map((state) => state.session?.user);

  // Sign in with email/password
  @override
  Future<AuthResponse> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign up
  Future<AuthResponse> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  // Google Sign-In (Native + Supabase OAuth)
  @override
  Future<AuthResponse> signInWithGoogle() async {
    if (kIsWeb) {
      // Web: Use Supabase OAuth
      return await _supabase.auth.signInWithOAuth(
        Provider.google,
        redirectTo: 'https://your-app.com/auth/callback',
      );
    } else {
      // Mobile: Use native Google Sign-In
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw Exception('Google sign-in cancelled');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      return await _supabase.auth.signInWithIdToken(
        provider: Provider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );
    }
  }

  // Sign out
  @override
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Reset password
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // Get user role (from user_metadata)
  @override
  Future<UserRole?> getCurrentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    // Check user_metadata for role flags
    final isAdmin = user.userMetadata?['isAdmin'] as bool? ?? false;
    final isParent = user.userMetadata?['isParent'] as bool? ?? false;

    if (isAdmin) return UserRole.admin;
    if (isParent) return UserRole.parent;
    return null;
  }

  // Update password
  @override
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  // Reauthenticate (for sensitive operations)
  @override
  Future<void> reauthenticateWithPassword(String password) async {
    final user = currentUser;
    if (user == null || user.email == null) {
      throw Exception('No user signed in');
    }

    // Supabase doesn't have reauthenticate - just verify by signing in again
    await _supabase.auth.signInWithPassword(
      email: user.email!,
      password: password,
    );
  }

  // Delete account
  @override
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    // Delete user data from database first
    await _userService.deleteUser(user.id);

    // Call Edge Function to delete auth account (requires service role)
    await _supabase.functions.invoke('delete_user', body: {'user_id': user.id});
  }
}
```

---

### STEP 4: Refactor User Service

#### `lib/core/services/user_service.dart`

**Key Changes:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../constants/database_constants.dart'; // Renamed from firestore_constants
import '../interfaces/i_user_service.dart';

class UserService implements IUserService {
  final SupabaseClient _supabase;

  UserService({required SupabaseClient supabase}) : _supabase = supabase;

  @override
  Future<AppUser?> getUser(String userId) async {
    try {
      final response = await _supabase
          .from(DatabaseConstants.usersTable)
          .select()
          .eq('uid', userId)
          .maybeSingle();

      if (response == null) return null;
      return AppUser.fromMap(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<AppUser?> getUserStream(String userId) {
    return _supabase
        .from(DatabaseConstants.usersTable)
        .stream(primaryKey: ['uid'])
        .eq('uid', userId)
        .map((data) {
      if (data.isEmpty) return null;
      return AppUser.fromMap(data.first);
    });
  }

  @override
  Future<void> createUser(AppUser user) async {
    await _supabase
        .from(DatabaseConstants.usersTable)
        .insert(user.toMap());
  }

  @override
  Future<void> updateUser(AppUser user) async {
    await _supabase
        .from(DatabaseConstants.usersTable)
        .update(user.toMap())
        .eq('uid', user.uid);
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _supabase
        .from(DatabaseConstants.usersTable)
        .delete()
        .eq('uid', userId);
  }

  @override
  Future<UserRole?> getUserRole(String userId) async {
    final user = await getUser(userId);
    if (user == null) return null;

    if (user.isAdmin) return UserRole.admin;
    if (user.isParent) return UserRole.parent;
    return null;
  }

  Future<bool> doesEmailExist(String email) async {
    final response = await _supabase
        .from(DatabaseConstants.usersTable)
        .select('uid')
        .eq('email', email)
        .maybeSingle();

    return response != null;
  }
}
```

---

### STEP 5: Refactor Registration Service

#### `lib/core/services/registration_service.dart`

**Key Changes:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../models/parent.dart';
import '../constants/database_constants.dart';

class RegistrationService {
  final SupabaseClient _supabase;

  RegistrationService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Register new admin user
  Future<void> registerAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    // 1. Create auth account
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'is_admin': true,
        'is_parent': false,
      },
    );

    final user = authResponse.user;
    if (user == null) throw Exception('Failed to create auth account');

    // 2. Create user record in database
    final appUser = AppUser(
      uid: user.id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      isAdmin: true,
      isParent: false,
      createdAt: DateTime.now(),
    );

    await _supabase
        .from(DatabaseConstants.usersTable)
        .insert(appUser.toMap());

    // 3. Call Edge Function to set user role in user_metadata
    await _supabase.functions.invoke('set_user_role', body: {
      'user_id': user.id,
      'isAdmin': true,
      'isParent': false,
    });
  }

  /// Register new parent user
  Future<void> registerParent({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    String? address,
  }) async {
    // 1. Create auth account
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
        'is_admin': false,
        'is_parent': true,
      },
    );

    final user = authResponse.user;
    if (user == null) throw Exception('Failed to create auth account');

    // 2. Create user record
    final appUser = AppUser(
      uid: user.id,
      firstName: firstName,
      lastName: lastName,
      email: email,
      isAdmin: false,
      isParent: true,
      createdAt: DateTime.now(),
    );

    // 3. Create parent record
    final parent = Parent(
      userId: user.id,
      phone: phone,
      address: address,
      balance: 0.0,
      studentIds: [],
      createdAt: DateTime.now(),
    );

    // Use transaction to ensure both records are created
    await _supabase.rpc('register_parent_transaction', params: {
      'user_data': appUser.toMap(),
      'parent_data': parent.toMap(),
    });

    // 4. Call Edge Function to set user role
    await _supabase.functions.invoke('set_user_role', body: {
      'user_id': user.id,
      'isAdmin': false,
      'isParent': true,
    });
  }

  /// Register parent with existing Google OAuth account
  Future<void> registerParentWithExistingAuth({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    String? phone,
    String? address,
  }) async {
    // Create user and parent records (auth account already exists)
    final appUser = AppUser(
      uid: uid,
      firstName: firstName,
      lastName: lastName,
      email: email,
      isAdmin: false,
      isParent: true,
      createdAt: DateTime.now(),
    );

    final parent = Parent(
      userId: uid,
      phone: phone,
      address: address,
      balance: 0.0,
      studentIds: [],
      createdAt: DateTime.now(),
    );

    await _supabase.rpc('register_parent_transaction', params: {
      'user_data': appUser.toMap(),
      'parent_data': parent.toMap(),
    });

    // Set user metadata
    await _supabase.functions.invoke('set_user_role', body: {
      'user_id': uid,
      'isAdmin': false,
      'isParent': true,
    });
  }

  /// Check if email already exists
  Future<bool> doesEmailExist(String email) async {
    final response = await _supabase
        .from(DatabaseConstants.usersTable)
        .select('uid')
        .eq('email', email)
        .maybeSingle();

    return response != null;
  }
}
```

**Create Postgres Function for Transaction:**

```sql
-- supabase/migrations/00002_register_parent_transaction.sql

CREATE OR REPLACE FUNCTION register_parent_transaction(
  user_data JSONB,
  parent_data JSONB
) RETURNS void AS $$
BEGIN
  -- Insert user record
  INSERT INTO users (
    uid, first_name, last_name, email, is_admin, is_parent, created_at
  ) VALUES (
    (user_data->>'uid')::UUID,
    user_data->>'first_name',
    user_data->>'last_name',
    user_data->>'email',
    (user_data->>'is_admin')::BOOLEAN,
    (user_data->>'is_parent')::BOOLEAN,
    NOW()
  );

  -- Insert parent record
  INSERT INTO parents (
    user_id, phone, address, balance, student_ids, created_at
  ) VALUES (
    (parent_data->>'user_id')::UUID,
    parent_data->>'phone',
    parent_data->>'address',
    (parent_data->>'balance')::DECIMAL,
    ARRAY[]::TEXT[],
    NOW()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

### STEP 6: Refactor Storage Service

#### `lib/core/services/storage_service.dart`

**Key Changes:**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class StorageService {
  final SupabaseClient _supabase;

  StorageService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Upload image file
  Future<String> uploadImage({
    required Uint8List imageData,
    required String bucket,
    required String path,
  }) async {
    try {
      // Upload file to Supabase Storage
      await _supabase.storage
          .from(bucket)
          .uploadBinary(path, imageData);

      // Get public URL
      final url = _supabase.storage
          .from(bucket)
          .getPublicUrl(path);

      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Upload menu item image
  Future<String> uploadMenuItemImage(
    Uint8List imageData,
    String menuItemId, {
    String? oldImageUrl,
  }) async {
    // Delete old image if exists
    if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
      try {
        await deleteFileFromUrl(oldImageUrl);
      } catch (e) {
        // Ignore delete errors
      }
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${menuItemId}_$timestamp.jpg';

    return uploadImage(
      imageData: imageData,
      bucket: 'menu-items',
      path: fileName,
    );
  }

  /// Upload student photo
  Future<String> uploadStudentPhoto(Uint8List imageData, String studentId) async {
    return uploadImage(
      imageData: imageData,
      bucket: 'students',
      path: '$studentId.jpg',
    );
  }

  /// Upload parent photo
  Future<String> uploadParentPhoto(Uint8List imageData, String parentId) async {
    return uploadImage(
      imageData: imageData,
      bucket: 'parents',
      path: '$parentId.jpg',
    );
  }

  /// Upload topup proof
  Future<String> uploadTopupProof(Uint8List imageData, String topupId) async {
    return uploadImage(
      imageData: imageData,
      bucket: 'topup-proofs',
      path: '$topupId.jpg',
    );
  }

  /// Delete file from storage
  Future<void> deleteFile(String bucket, String path) async {
    await _supabase.storage.from(bucket).remove([path]);
  }

  /// Delete file from URL
  Future<void> deleteFileFromUrl(String url) async {
    // Parse bucket and path from URL
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    
    if (segments.length < 3) return;
    
    final bucket = segments[segments.length - 2];
    final filename = segments.last;
    
    await deleteFile(bucket, filename);
  }
}
```

**Create Storage Buckets in Supabase:**

```powershell
# Via Supabase Dashboard: Storage > Create Bucket
# Create buckets: menu-items, students, parents, topup-proofs
# Set all to Public access
```

---

### STEP 7: Update Model Files (Remove Firebase Timestamp)

For **ALL model files** in `lib/core/models/`:
- Remove `import 'package:cloud_firestore/cloud_firestore.dart';`
- Replace `Timestamp` with `DateTime`
- Update `toMap()` to use `.toIso8601String()`
- Update `fromMap()` to use `DateTime.parse()`

**Example: `lib/core/models/menu_item.dart`**

```dart
// REMOVE
import 'package:cloud_firestore/cloud_firestore.dart';

// UPDATE toMap()
Map<String, dynamic> toMap() {
  return {
    'id': id,
    'name': name,
    'price': price,
    'created_at': createdAt.toIso8601String(), // Changed from Timestamp
    'updated_at': updatedAt?.toIso8601String(),
  };
}

// UPDATE fromMap()
factory MenuItem.fromMap(Map<String, dynamic> map) {
  return MenuItem(
    id: map['id'],
    name: map['name'],
    price: (map['price'] as num).toDouble(),
    createdAt: DateTime.parse(map['created_at']), // Changed from Timestamp
    updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
  );
}
```

**Apply this pattern to:**
- cart_item.dart
- menu_item.dart
- order.dart
- parent.dart
- student.dart
- topup.dart
- user_role.dart
- weekly_menu.dart
- weekly_menu_analytics.dart

---

### STEP 8: Rename Constants File

```powershell
cd "c:\Developments\flutter\canteen_app\lib\core\constants"
ren firestore_constants.dart database_constants.dart
```

Update `lib/core/constants/database_constants.dart`:

```dart
/// Database constants for Supabase Postgres
class DatabaseConstants {
  DatabaseConstants._();

  // ==================== TABLE NAMES ====================
  
  static const String usersTable = 'users';
  static const String parentsTable = 'parents';
  static const String studentsTable = 'students';
  static const String menuItemsTable = 'menu_items';
  static const String weeklyMenusTable = 'weekly_menus';
  static const String ordersTable = 'orders';
  static const String transactionsTable = 'parent_transactions';
  static const String topupRequestsTable = 'topup_requests';
  static const String analyticsTable = 'weekly_menu_analytics';

  // ==================== COLUMN NAMES ====================
  
  // User columns
  static const String uid = 'uid';
  static const String firstName = 'first_name';
  static const String lastName = 'last_name';
  static const String email = 'email';
  static const String isAdmin = 'is_admin';
  static const String isParent = 'is_parent';
  static const String isActive = 'is_active';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';

  // Parent columns
  static const String userId = 'user_id';
  static const String phone = 'phone';
  static const String address = 'address';
  static const String balance = 'balance';
  static const String studentIds = 'student_ids';

  // Student columns
  static const String id = 'id';
  static const String parentUserId = 'parent_user_id';
  static const String gradeLevel = 'grade_level';
  static const String section = 'section';
  static const String photoUrl = 'photo_url';
  static const String allergies = 'allergies';
  static const String dietaryRestrictions = 'dietary_restrictions';

  // Menu item columns
  static const String name = 'name';
  static const String description = 'description';
  static const String price = 'price';
  static const String category = 'category';
  static const String imageUrl = 'image_url';
  static const String isAvailable = 'is_available';
  static const String allergens = 'allergens';
  static const String dietaryLabels = 'dietary_labels';
  static const String prepTimeMinutes = 'prep_time_minutes';

  // Order columns
  static const String orderNumber = 'order_number';
  static const String parentId = 'parent_id';
  static const String studentId = 'student_id';
  static const String items = 'items';
  static const String totalAmount = 'total_amount';
  static const String status = 'status';
  static const String orderType = 'order_type';
  static const String deliveryDate = 'delivery_date';
  static const String deliveryTime = 'delivery_time';
  static const String specialInstructions = 'special_instructions';
  static const String completedAt = 'completed_at';
  static const String cancelledAt = 'cancelled_at';

  // Transaction columns
  static const String type = 'type';
  static const String amount = 'amount';
  static const String balanceBefore = 'balance_before';
  static const String balanceAfter = 'balance_after';
  static const String referenceId = 'reference_id';
  static const String paymentMethod = 'payment_method';

  // Weekly menu columns
  static const String weekStart = 'week_start';
  static const String menuItemsByDay = 'menu_items_by_day';

  // ==================== QUERY LIMITS ====================
  
  static const int maxQueryLimit = 1000;
  static const int defaultPageSize = 50;
}
```

---

### STEP 9: Update Remaining Services

Apply similar patterns to:

1. **student_service.dart** - Replace Firestore with Supabase queries
2. **parent_service.dart** - Replace Firestore with Supabase queries
3. **order_service.dart** - Replace Firestore with Supabase queries
4. **menu_service.dart** - Replace Firestore with Supabase queries
5. **transaction_service.dart** - Replace Firestore with Supabase queries
6. **topup_service.dart** - Replace Firestore with Supabase queries
7. **weekly_menu_service.dart** - Replace Firestore with Supabase queries
8. **weekly_menu_analytics_service.dart** - Replace Firestore with Supabase queries

**Pattern for each service:**

```dart
// OLD Firestore pattern
final snapshot = await _firestore
    .collection('students')
    .where('parent_user_id', isEqualTo: parentId)
    .get();

final students = snapshot.docs
    .map((doc) => Student.fromMap(doc.data()))
    .toList();

// NEW Supabase pattern
final response = await _supabase
    .from('students')
    .select()
    .eq('parent_user_id', parentId);

final students = response
    .map<Student>((json) => Student.fromMap(json))
    .toList();
```

---

### STEP 10: Update UI Screens

For screens that directly query Firestore (wallet_screen.dart, transactions_screen.dart, cart_screen.dart, weekly_cart_screen.dart):

**Replace StreamBuilder with Supabase streams:**

```dart
// OLD Firebase pattern
stream: FirebaseFirestore.instance
    .collection('parent_transactions')
    .where('parent_id', isEqualTo: parentId)
    .orderBy('created_at', descending: true)
    .snapshots()

// NEW Supabase pattern
stream: SupabaseConfig.client
    .from('parent_transactions')
    .stream(primaryKey: ['id'])
    .eq('parent_id', parentId)
    .order('created_at', ascending: false)
```

---

### STEP 11: Fix Compile Errors

```powershell
# Run flutter analyze
flutter analyze

# Fix any remaining import errors
# Search for: firebase, Firestore, FirebaseAuth, FirebaseStorage
# Replace with Supabase equivalents
```

---

### STEP 12: Test Build

```powershell
# Clean build
flutter clean
flutter pub get

# Test build
flutter build apk --debug
flutter build web --debug

# Run app
flutter run
```

---

### STEP 13: Create Migration Commits

```powershell
# Stage changes
git add .

# Commit 1: Infrastructure
git commit -m "feat: Add Supabase providers and database schema

- Created supabase_providers.dart with SupabaseClient provider
- Added Postgres schema migration (00001_initial_schema.sql)
- Renamed firebase_providers.dart to supabase_providers.dart
- Updated app_providers.dart to export Supabase providers"

# Commit 2: Services
git commit -m "refactor: Migrate auth and user services to Supabase

- Refactored auth_service.dart to use Supabase Auth
- Updated user_service.dart to use Postgres queries
- Modified registration_service.dart for Supabase
- Replaced Firebase Auth methods with Supabase equivalents"

# Commit 3: Models
git commit -m "refactor: Update models to remove Firebase Timestamp

- Removed cloud_firestore dependency from all models
- Replaced Timestamp with DateTime
- Updated toMap/fromMap methods for Supabase compatibility
- Fixed serialization for Postgres"

# Commit 4: Constants
git commit -m "refactor: Rename Firestore constants to database constants

- Renamed firestore_constants.dart to database_constants.dart
- Updated constant names for Postgres (snake_case)
- Changed collection names to table names"

# Commit 5: Storage
git commit -m "refactor: Migrate storage service to Supabase Storage

- Updated storage_service.dart to use Supabase Storage buckets
- Replaced Firebase Storage methods
- Created buckets: menu-items, students, parents, topup-proofs"

# Commit 6: Remaining Services
git commit -m "refactor: Complete service migration to Supabase

- Updated student, parent, order, menu services
- Migrated transaction and topup services
- Replaced all Firestore queries with Supabase Postgres queries
- Updated weekly menu and analytics services"

# Commit 7: UI
git commit -m "refactor: Update UI screens to use Supabase streams

- Updated wallet_screen.dart with Supabase streams
- Modified transactions_screen.dart for Postgres
- Fixed cart_screen.dart and weekly_cart_screen.dart
- Replaced Firebase real-time listeners with Supabase streams"

# Commit 8: Final fixes
git commit -m "fix: Resolve all compile errors after migration

- Fixed remaining Firebase imports
- Updated provider dependencies
- Resolved type mismatches
- App builds successfully"
```

---

## 🧪 Testing Checklist

After migration, test these critical flows:

### Authentication
- [ ] Email/password sign in
- [ ] Email/password sign up
- [ ] Google Sign-In (web)
- [ ] Google Sign-In (mobile)
- [ ] Password reset
- [ ] Sign out

### User Management
- [ ] View user profile
- [ ] Update user profile
- [ ] Create admin user
- [ ] Create parent user

### Student Management
- [ ] Add student
- [ ] Edit student
- [ ] Delete student
- [ ] View student list

### Menu Management
- [ ] View menu items
- [ ] Add menu item with image
- [ ] Edit menu item
- [ ] Delete menu item
- [ ] Create weekly menu

### Orders
- [ ] Place order
- [ ] View order history
- [ ] Cancel order
- [ ] View order details

### Transactions
- [ ] Request top-up
- [ ] Process top-up (admin)
- [ ] View transaction history
- [ ] Check parent balance

### Storage
- [ ] Upload menu item image
- [ ] Upload student photo
- [ ] Upload topup proof
- [ ] Delete images

---

## 🔧 Troubleshooting

### Common Issues

**1. "Table doesn't exist" error**
```powershell
# Deploy schema
npx supabase db push
```

**2. "Row Level Security" policy error**
```sql
-- Check RLS policies in Supabase Dashboard
-- Ensure policies match your user roles
```

**3. "Authentication error"**
```dart
// Check Supabase URL and Anon Key in .env
// Verify SupabaseConfig.initialize() was called
```

**4. "Stream not updating"**
```dart
// Ensure you're using .stream(primaryKey: ['id'])
// Check that table has realtime enabled in Supabase
```

**5. "Google Sign-In not working"**
```
// Configure Google OAuth in Supabase Dashboard
// Auth > Providers > Google > Enable
// Add OAuth client credentials
```

---

## 📚 Resources

- [Supabase Flutter Docs](https://supabase.com/docs/reference/dart/introduction)
- [Supabase Auth Guide](https://supabase.com/docs/guides/auth)
- [Supabase Database Guide](https://supabase.com/docs/guides/database)
- [Supabase Storage Guide](https://supabase.com/docs/guides/storage)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)

---

## ✅ Migration Complete!

Once all steps are done and tests pass:

1. ✅ Deploy to production
2. ✅ Monitor error logs
3. ✅ Verify Edge Functions working
4. ✅ Check payment webhooks
5. ✅ Test real user flows

**You've successfully migrated from Firebase to Supabase!** 🎉
