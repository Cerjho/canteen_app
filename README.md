# Loheca School Canteen App 🍽️

A comprehensive Flutter multi-app system for managing school canteen operations with real-time ordering, inventory, and payment management.

**Architecture:**

- **Admin Dashboard**: Web-only portal for administrators (lib/features/admin/)
- **Parent App**: Mobile app for parents/guardians to browse menu and place orders (lib/features/parent/)
- **Shared Core**: 100% reusable business logic, models, and services (lib/core/)

**Backend:** Supabase (PostgreSQL + Realtime + Auth + Storage)
**State Management:** Flutter Riverpod
**UI Framework:** Flutter Material Design 3

## 📋 Features

### 🎯 Admin Dashboard Features

- **Dashboard Overview**: Real-time statistics for orders, revenue, pending top-ups, and inventory status
- **Student Management**: CRUD operations, assign students to parents, track allergies and dietary restrictions
- **Parent Management**: View and edit parent profiles, manage wallet balance, track linked students
- **Menu Management**: Add/edit/delete menu items with images, set prices and availability, manage weekly menus
- **Orders Management**: View all orders with real-time updates, multi-filter by status/date/search, update status, cancel orders, view complete order breakdown
- **Top-up Management**: Review and approve/decline balance top-up requests with audit trail
- **Analytics & Reports**: Export orders and revenue reports to CSV/Excel, view popular menu items
- **Settings & Administration**: App configuration, data import/export, user role management

### 📱 Parent App Features

- **Authentication**: Google Sign-In and email/password login
- **Dashboard**: Quick view of linked students, recent orders, account balance
- **Menu Browsing**: View weekly menu with images and prices, filter by category, see allergen warnings
- **Order Placement**: Add items to cart by student and date, review summary, place orders
- **Wallet Management**: View balance, request top-ups, track transaction history
- **Order History**: Track placed orders and their status
- **Student Linking**: Link/unlink students to account
- **Settings**: Update profile, manage linked students, notification preferences## 🏗️ Project Structure

lib/
├── core/                         # 🔷 Shared code (100% reusable across all apps)
│   ├── config/                   # App configuration (theme, Supabase, environment)
│   ├── constants/                # Constants & Supabase table field names
│   ├── exceptions/               # Custom error handling
│   ├── extensions/               # Dart extensions for common operations
│   ├── interfaces/               # Service interfaces (I-prefixed for DI)
│   ├── models/                   # Data models (Student, Parent, Order, MenuItem, etc.)
│   ├── providers/                # Riverpod providers for state management
│   ├── services/                 # Supabase services (auth, user, student, order, menu, etc.)
│   ├── utils/                    # Utility functions (logger, formatters, validators, seeders)
│   ├── link_provider.dart        # Deep linking configuration
│   └── links_adapter.dart        # Link handler adapter
│
├── features/                     # 🎯 Feature-based modules
│   ├── admin/                    # Admin Web App only
│   │   ├── auth/                 # Login, registration, access control
│   │   ├── dashboard/            # Main dashboard with real-time statistics
│   │   ├── menu/                 # Menu items and weekly menu management
│   │   ├── orders/               # Order management with filters and status updates
│   │   ├── parents/              # Parent profile and balance management
│   │   ├── reports/              # Analytics, exports (CSV/Excel)
│   │   ├── settings/             # App settings and data seeding
│   │   ├── students/             # Student management and linking
│   │   ├── topups/               # Top-up request approval workflow
│   │   └── widgets/              # Admin-specific reusable UI components
│   │
│   ├── parent/                   # Parent App (Mobile + Web via dispatcher)
│   │   ├── auth/                 # Login/signup with Google Sign-In
│   │   ├── cart/                 # Shopping cart for order placement
│   │   ├── dashboard/            # Parent home screen with quick actions
│   │   ├── menu/                 # Browse weekly menu and items
│   │   ├── orders/               # Order history and tracking
│   │   ├── settings/             # Parent profile and preferences
│   │   ├── student_link/         # Student linking workflow
│   │   ├── wallet/               # Balance management and top-ups
│   │   └── widgets/              # Parent-specific reusable UI components
│   │
│   └── payments/                 # Payment processing (if implemented)
│
├── router/                       # 🧭 Centralized navigation
│   ├── router.dart               # Main router with platform detection
│   ├── admin_routes.dart         # Admin-only routes
│   └── parent_routes.dart        # Parent app routes
│
├── app/                          # 🚀 Entry points
│   ├── main_admin_web.dart       # Admin web app entry point
│   ├── main_parent_mobile.dart   # Parent mobile app entry point
│   └── main_common.dart          # Shared app initialization
│
├── shared/                       # 🎨 Shared UI components
│   ├── components/               # Reusable widgets (loading, charts, buttons, etc.)
│   ├── layout/                   # Shared layouts and scaffolds
│   └── theme/                    # Theme configuration (delegated to core/config)
│
└── main.dart                     # Platform dispatcher (routes to admin or parent)

   └── parent_app.dart    # Parent app entry point (mobile)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Firebase account
- IDE (VS Code, Android Studio, etc.)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/Cerjho/canteen_app.git
   cd canteen_app
   flutter pub get
   ```

2. **Configure Supabase**

   a. Create a Supabase project at [Supabase Console](https://app.supabase.com)

   b. Enable the following:
      - Authentication (Email/Password, Google OAuth)
      - Realtime database
      - Storage

   c. Create `.env` file in project root:

   ```env
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your_anon_key
   BACKEND_BASE_URL=https://your-api.com  # Optional, for custom backend
   ```

   d. Database Schema (PostgreSQL):
      - Create tables: `users`, `students`, `parents`, `menu_items`, `orders`, `topups`, `weekly_menus`
      - See `supabase/migrations/` for migration files
      - See `supabase/seed/` for sample data seeding

3. **Enable Row Level Security (RLS) Policies**

   In Supabase Console > Authentication > Policies:
   - Admins can manage all data
   - Parents can only see their linked students and orders
   - Students data is read-only for authenticated users
   - Orders are created by parents for their linked students

4. **Configure Google Sign-In**

   a. Go to [Google Cloud Console](https://console.cloud.google.com)
   b. Create OAuth 2.0 Client IDs for Web, Android, and iOS
   c. Add redirect URIs in Supabase > Authentication > Providers > Google

5. **Set up Storage Buckets**

   Create public buckets in Supabase Storage:
   - `menu_items/` - Menu item photos
   - `students/` - Student profile photos
   - `parents/` - Parent profile photos
   - `order_proofs/` - Payment proof screenshots

### Running the Apps

**Platform Dispatcher** - Auto-detects platform in `lib/main.dart`:

- Web platform → runs Admin Dashboard
- Mobile platforms → runs Parent App

To explicitly run specific apps:

#### Admin Dashboard (Web)

```powershell
# Chrome browser
flutter run -d chrome --target lib/app/main_admin_web.dart

# Edge browser
flutter run -d edge --target lib/app/main_admin_web.dart
```

#### Parent App (Mobile)

```powershell
# Android emulator
flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart

# Android device
flutter run -d <device-id> --target lib/app/main_parent_mobile.dart

# iOS simulator
flutter run -d simulator --target lib/app/main_parent_mobile.dart
```

#### Build for Production

```powershell
# Web (Admin Dashboard)
flutter build web --target lib/app/main_admin_web.dart
flutter build web --release --target lib/app/main_admin_web.dart

# Android APK
flutter build apk --target lib/app/main_parent_mobile.dart

# Android App Bundle
flutter build appbundle --target lib/app/main_parent_mobile.dart

# iOS
flutter build ios --target lib/app/main_parent_mobile.dart
```

## 🎨 Tech Stack

- **Framework**: Flutter 3.9.2+
- **State Management**: Flutter Riverpod 2.6.1+
- **Routing**: Go Router 14.6.2+
- **Backend**: Supabase (PostgreSQL + Realtime + Auth + Storage)
- **Authentication**: Supabase Auth (Email/Password, Google Sign-In)
- **UI**: Material Design 3 with Flutter ScreenUtil for responsive design
- **Data Export**: CSV and Excel (via csv and excel packages)
- **HTTP Client**: Custom ApiClient with Supabase integration
- **Deep Linking**: app_links for URL handling
- **Charts**: fl_chart for analytics and reporting
- **Environment Config**: flutter_dotenv for .env file support
- **Form Handling**: flutter_form_builder with validators
- **Image Management**: CachedNetworkImage for efficient loading
- **File Operations**: file_picker and image_picker

## 📦 Key Packages

| Package | Purpose | Version |
|---------|---------|---------|
| `supabase_flutter` | Backend (Auth, Realtime, Storage, PostgreSQL) | ^2.8.0 |
| `flutter_riverpod` | State management with dependency injection | ^2.6.1 |
| `go_router` | Type-safe declarative routing | ^14.6.2 |
| `flutter_dotenv` | Environment configuration from .env | ^5.2.1 |
| `http` | HTTP client for API calls | ^1.5.0 |
| `intl` | Date/time and number formatting | ^0.20.1 |
| `uuid` | Unique ID generation | ^4.5.1 |
| `csv`, `excel` | Export orders and reports to files | ^6.0.0, ^4.0.6 |
| `cached_network_image` | Efficient image caching and loading | ^3.4.1 |
| `image_picker`, `file_picker` | File and image selection | ^1.1.2, ^8.1.4 |
| `fl_chart` | Charts and graphs for analytics | ^0.70.1 |
| `google_sign_in` | Google authentication | ^6.2.1 |
| `flutter_screenutil` | Responsive design scaling | ^5.9.3 |
| `flutter_form_builder` | Form creation and validation | ^10.2.0 |
| `logger` | Logging utilities | ^2.4.0 |
| `table_calendar` | Calendar widget for date selection | ^3.2.0 |
| `app_links` | Deep linking support | ^6.4.1 |
| `flutter_svg` | SVG rendering | ^2.0.16 |

## 🔑 Default Credentials

**Note**: You need to create an admin user through Supabase Authentication first.

Create a test user:

- Email: `admin@example.com`
- Password: `SecurePassword123!`
- Set `is_admin: true` in the users table

## 📊 Database Schema

### Supabase PostgreSQL Tables

#### users

- `id` (UUID, Primary Key) - Auth UID
- `first_name` (TEXT)
- `last_name` (TEXT)
- `email` (TEXT, Unique)
- `is_admin` (BOOLEAN)
- `is_parent` (BOOLEAN)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)
- `is_active` (BOOLEAN)

#### students

- `id` (UUID, Primary Key)
- `first_name` (TEXT)
- `last_name` (TEXT)
- `grade` (TEXT)
- `parent_id` (UUID, Foreign Key)
- `allergies` (JSONB)
- `dietary_restrictions` (JSONB)
- `balance` (DECIMAL) - Admin-only (billing to parent)
- `photo_url` (TEXT)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)
- `is_active` (BOOLEAN)

#### parents

- `id` (UUID, Primary Key)
- `user_id` (UUID, Foreign Key)
- `balance` (DECIMAL) - Wallet balance
- `address` (TEXT)
- `phone` (TEXT)
- `children` (JSONB)
- `photo_url` (TEXT)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)
- `is_active` (BOOLEAN)

#### menu_items

- `id` (UUID, Primary Key)
- `name` (TEXT)
- `description` (TEXT)
- `category` (TEXT)
- `price` (DECIMAL)
- `image_url` (TEXT)
- `allergens` (JSONB)
- `is_vegetarian` (BOOLEAN)
- `is_vegan` (BOOLEAN)
- `is_gluten_free` (BOOLEAN)
- `is_available` (BOOLEAN)
- `stock_quantity` (INT)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

#### weekly_menus

- `id` (UUID, Primary Key)
- `title` (TEXT)
- `items` (JSONB)
- `published_at` (TIMESTAMP)
- `published_by` (UUID, Foreign Key)
- `is_active` (BOOLEAN)
- `start_date` (DATE)
- `end_date` (DATE)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

#### orders

- `id` (UUID, Primary Key)
- `order_number` (TEXT, Unique)
- `parent_id` (UUID, Foreign Key)
- `student_id` (UUID, Foreign Key)
- `items` (JSONB)
- `total_amount` (DECIMAL)
- `status` (TEXT) - pending, confirmed, preparing, ready, completed, cancelled
- `order_type` (TEXT) - oneTime, weekly
- `delivery_date` (DATE)
- `delivery_time` (TIME)
- `special_instructions` (TEXT)
- `completed_at` (TIMESTAMP)
- `cancelled_at` (TIMESTAMP)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

#### topups

- `id` (UUID, Primary Key)
- `parent_id` (UUID, Foreign Key)
- `student_id` (UUID, Foreign Key, Optional)
- `amount` (DECIMAL)
- `status` (TEXT) - pending, approved, rejected
- `payment_method` (TEXT)
- `transaction_reference` (TEXT)
- `proof_image_url` (TEXT)
- `notes` (TEXT)
- `admin_notes` (TEXT)
- `processed_by` (UUID, Foreign Key, Optional)
- `request_date` (TIMESTAMP)
- `processed_at` (TIMESTAMP)
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

### Order Status Workflow

- `pending` - Order created, awaiting confirmation
- `confirmed` - Admin confirmed the order
- `preparing` - Kitchen is preparing the order
- `ready` - Order ready for pickup/delivery
- `completed` - Order fulfilled
- `cancelled` - Order cancelled

**Important**: Orders are charged to the linked parent's wallet, not individual student balances. Parents must have sufficient balance to place orders.

## 🔄 Supabase Row Level Security (RLS) Policies

### How Security Works

- Supabase enforces row-level security at the database level
- Policies control who can read/write/update/delete rows based on user ID and role
- All data access goes through the Supabase client with `auth.uid()`
- Update logic is encapsulated in service classes (see `lib/core/services/`)

### Update Permissions (by Table)

| Table | Admin | Parent (Self) | Parent (Others) | Notes |
|-------|-------|---------------|-----------------|-------|
| users | ✅ Full | ✅ Own record only | ❌ | Cannot change own role or is_active |
| parents | ✅ Full | ✅ Own record | ❌ | Cannot update balance directly |
| students | ✅ Full | ❌ | ❌ | Parents see via parent.children array |
| menu_items | ✅ Full | ❌ | ❌ | Read-only for parents |
| orders | ✅ Full | ✅ Create own, ❌ Update | ❌ | Admin can update status |
| topups | ✅ Full | ✅ Create own | ❌ | Admin approves/rejects |
| weekly_menus | ✅ Full | ❌ | ❌ | Read-only for parents |

### Example RLS Policies

```sql
-- Allow parents to read menu items
CREATE POLICY "menu_read_all"
  ON menu_items FOR SELECT
  USING (auth.role() = 'authenticated_user');

-- Allow parents to create their own orders
CREATE POLICY "orders_insert_own"
  ON orders FOR INSERT
  WITH CHECK (parent_id = auth.uid());

-- Allow parents to view own orders
CREATE POLICY "orders_select_own"
  ON orders FOR SELECT
  USING (parent_id = auth.uid() OR auth.jwt() ->> 'is_admin' = 'true');

-- Allow admins full access
CREATE POLICY "admin_all"
  ON orders FOR ALL
  USING (auth.jwt() ->> 'is_admin' = 'true');
```

## 🛠️ Core Services & Models

### Service Classes

All shared services live in `lib/core/services/`:

- `auth_service.dart` - Authentication (login, signup, sign out)
- `user_service.dart` - User management
- `student_service.dart` - Student CRUD and import/export
- `parent_service.dart` - Parent profile and balance management
- `order_service.dart` - Order creation and status updates
- `topup_service.dart` - Top-up request handling
- `menu_service.dart` - Menu item management
- `weekly_menu_service.dart` - Weekly menu scheduling
- `storage_service.dart` - File uploads to Supabase Storage
- `registration_service.dart` - New user registration flow
- `api_client.dart` - Custom HTTP client for backend calls (optional)
- `cart_persistence_service.dart` - Persist shopping cart locally

### Model Classes

All shared models live in `lib/core/models/`:

- `user_role.dart` - User role enum (admin, parent)
- `student.dart` - Student profile model
- `parent.dart` - Parent profile model
- `order.dart` - Order model with status enum
- `menu_item.dart` - Menu item model
- `weekly_menu.dart` - Weekly menu model
- `topup.dart` - Top-up request model
- `cart_item.dart` - Shopping cart item
- `parent_transaction.dart` - Transaction history
- `weekly_menu_analytics.dart` - Analytics data

### Providers

All providers live in `lib/core/providers/`:

- `supabase_providers.dart` - Supabase client instance
- `auth_providers.dart` - Authentication and user service providers
- `user_providers.dart` - Student and parent service providers
- `menu_providers.dart` - Menu and weekly menu providers
- `transaction_providers.dart` - Order and top-up providers
- `storage_providers.dart` - Storage service provider
- `app_providers.dart` - Central export file for all providers

## 📱 App Entry Points

### Admin Web App

```dart
// lib/app/main_admin_web.dart
// Platform: Web only (Chrome, Edge, etc.)
// Features: Complete admin dashboard
// Run: flutter run -d chrome --target lib/app/main_admin_web.dart
```

### Parent Mobile App

```dart
// lib/app/main_parent_mobile.dart
// Platform: Android, iOS (mobile-only)
// Features: Browse menu, place orders, manage wallet
// Run: flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart
```

### Platform Dispatcher

```dart
// lib/main.dart
// Routes to appropriate app based on platform
// if (kIsWeb) -> Admin Dashboard
// else -> Parent Mobile App
```

1. Import the seed utility in your code:

   ```dart
   import 'lib/core/utils/seed_data_util.dart';
   ```

2. Call the seed function:

   ```dart
   final seedUtil = SeedDataUtil();
   await seedUtil.seedAll();
   ```

This will create sample students, parents, menu items, orders, and top-ups.

## 🤝 Shared Architecture

This project is designed to support both **Admin App** and **Parent App** with a shared core:

- `lib/core/` contains all shared code (models, services, utilities)
- `lib/admin/` contains admin-specific UI and logic
- `lib/parent/` (placeholder) will contain parent-specific UI and logic

Both apps use the same:

- Firebase backend
- Data models
- Service layer
- Utilities

## 🔐 Security Considerations

For production:

1. Update Firestore security rules to restrict admin-only operations
2. Implement role-based access control
3. Use environment variables for sensitive configuration
4. Enable Firebase App Check
5. Implement rate limiting
6. Regular security audits

## 📱 Future Enhancements

- [ ] Parent mobile app implementation
- [ ] Push notifications for order updates
- [ ] Multi-language support
- [ ] Advanced analytics and reporting
- [ ] Inventory management
- [ ] QR code scanning for orders
- [ ] Payment gateway integration
- [ ] Email notifications

## 🐛 Troubleshooting

## ⚠️ Important Billing Model Change

Note: Students in this system are imported entities and not first-class authenticated users. As of this update, orders are billed to the linked parent's wallet. Student balance fields are kept for administrative/reference purposes, but the runtime deduction for orders now always occurs against the parent's wallet. This means:

- Parents must top up their own wallet to place orders for linked students.
- Student documents are not automatically debited when orders are placed.
- Admins can still view and manage student.balance via the admin UI or `StudentService` if you want to maintain separate student-level balances.

If you need a different billing model (per-student balances, split-billing between students, etc.), adjust the order creation logic and Firestore transaction accordingly.

**Issue**: Firebase initialization error

- **Solution**: Ensure Firebase configuration is correct in `firebase_options.dart`

**Issue**: Authentication errors

- **Solution**: Check that Email/Password auth is enabled in Firebase Console

**Issue**: Firestore permission denied

- **Solution**: Update Firestore security rules to allow authenticated access

## 📄 License

This project is licensed under the MIT License.

---

Made with ❤️ using Flutter

## 🔥 Billing-Free MVP (Updated Firebase Architecture)

This project can run as a billing-free MVP without any Cloud Functions. All server-side logic is implemented in the Flutter apps (Admin web and Parent mobile). This reduces complexity and keeps the project within Firebase's free tier while you validate the product.

Key changes for the Billing-Free MVP:

- No Cloud Functions required. All business logic executes in the Flutter clients.
- Payments are handled manually (no Stripe/secure gateways). Orders use a "pending_payment" → "paid" workflow.
- FCM Topic messaging is used for broadcast notifications (e.g., when a new menu is published).

Services used (free-tier friendly):

- Firebase Authentication — user sign-in and roles (Admin, Parent)
- Cloud Firestore — primary database for menus, orders, users
- Cloud Storage for Firebase — pictures for menu items and payment receipts
- Firebase Cloud Messaging (FCM) — notifications via Topics
- Firebase Hosting — deploy Admin Web (optional)

When to keep this architecture:

- You don't have a billing payment method to enable Functions/paid services.
- You want to iterate quickly and validate flows before adding server-side enforcement.

Trade-offs / Risks:

- Client-side logic is inherently less trusted than server-side. Be careful with security rules and assume client can be manipulated.
- Sensitive operations that require secret keys (e.g., generating Stripe payment intents) are NOT possible here.
- Admin actions are still protected by Firebase Auth and Firestore rules — make sure rules enforce role checks.

### Data & User Flows (No Cloud Functions)

1) Admin publishes a weekly menu

    - Admin (web) creates a new document in `weeklyMenus` collection.
    - The Admin web app also sends a direct FCM topic message to the `new_menu` topic so all parents are notified.

    Example Firestore write (pseudo):

    ```dart
    final menuDoc = FirebaseFirestore.instance.collection('weeklyMenus').doc();
    await menuDoc.set({
       'title': 'Week of Oct 27',
       'items': [...],
       'publishedAt': FieldValue.serverTimestamp(),
       'publishedBy': adminUid,
    });
    ```

    Example: send topic notification from Admin web app (Flutter):

    - On web, you can use the Firebase Cloud Messaging REST v1 API to send messages if you have a server key — but that requires a secret and thus a backend. Instead, use the legacy FCM HTTP endpoint only from the Admin web app if you accept that the server key will be embedded in the build (NOT recommended). Safer: have the Admin app call the Firebase console's Notification composer or deploy a tiny admin-only Cloud Function later when billing is ready.

    - A practical, billing-free approach: use the Admin app to write a `published` flag and rely on parent apps to poll or listen to `weeklyMenus` changes in Firestore. You can also use FCM Topics with the Firebase Console to send a topic notification manually when publishing.

2) Parent places an order

    - Parent reads the new menu from `weeklyMenus`.
    - On "Place Order" the Parent app writes a new document to `orders` with `status: 'pending_payment'` and optional `paymentInfo` fields (transactionReference, proofImageUrl).

    Example order write:

    ```dart
    final orders = FirebaseFirestore.instance.collection('orders');
    await orders.add({
       'parentId': parentUid,
       'studentId': studentId,
       'items': items, // list of {menuItemId, qty, price}
       'totalAmount': totalAmount,
       'status': 'pending_payment',
       'createdAt': FieldValue.serverTimestamp(),
       'paymentInfo': {
          'method': 'GCash',
          'transactionReference': '',
          'proofImageUrl': null,
       }
    });
    ```

    - The app shows payment instructions (e.g., GCash number, cash on pickup) and allows the parent to upload a screenshot to `storage` and save `proofImageUrl` in the order.

3) Admin confirms payment

    - Admin reviews `orders` in the Admin web portal, verifies the external payment (GCash/Maya/cash), and updates `status` to `paid` and optionally deducts balance fields if you maintain a parent wallet.

    Example status update:

    ```dart
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
       'status': 'paid',
       'paidAt': FieldValue.serverTimestamp(),
       'processedBy': adminUid,
    });
    ```

### FCM Topics (Client-side usage)

- Parent apps subscribe to a topic such as `new_menu` when they initialize and after login:

```dart
await FirebaseMessaging.instance.subscribeToTopic('new_menu');
```

- When the Admin publishes a menu and you want to notify parents, you can send a topic message from the Firebase Console (Messaging → Send your first message → Target: Topic → new_menu). This is free and does not require a server.

- If you want to automate topic sends from the Admin web UI, you will need a server or Cloud Functions to safely store the FCM server key. Until then, use Firestore listeners or manual Firebase Console messages.

### Security Rules Guidance (important)

- With client-side logic, secure your Firestore rules carefully. At minimum:

  - Only allow Admin users to write to `menu_items` and set `published` flags.
  - Allow Parents to create `orders` but disallow them from setting arbitrary `status` values (e.g., prevent clients from writing `status: 'paid'`).

   Example snippet (conceptual):

   ```rules
   match /orders/{orderId} {
      allow create: if request.auth != null && request.resource.data.parentId == request.auth.uid &&
                           request.resource.data.status == 'pending_payment';
      allow update: if isAdmin() || (request.auth.uid == resource.data.parentId && !(request.resource.data.keys().hasAny(['status']) && request.resource.data.status != resource.data.status));
   }
   ```

  - Replace `isAdmin()` with your role-check implementation (custom claims or `roles` collection lookup).

### Manual Payment UX Recommendations

- Provide clear payment instructions when parents place orders (GCash number, account name, preferred reference format).
- Allow parents to optionally upload a receipt image; store the image in Cloud Storage and save the URL in the order document.
- Display an order status timeline in the Parent app (Pending Payment → Awaiting Verification → Paid → Completed).
- On Admin portal, provide filters for `pending_payment` and quick actions to mark as `paid` or request more info.

### Small code helpers

- Upload proof image to Storage and return URL (simplified):

```dart
final ref = FirebaseStorage.instance.ref().child('order_proofs/$orderId/${file.name}');
final uploadTask = await ref.putFile(file);
final url = await ref.getDownloadURL();
// save url to order.paymentInfo.proofImageUrl
```

- Place an order and optionally upload proof in one UX flow: write order with placeholder proof URL, upload image, then update the order with the real URL.

## ✅ Next steps & Verification

- I've added the Billing-Free MVP guidance to this README. Update your Firestore rules to enforce roles and the `pending_payment` constraint.
- If you'd like, I can:
  - Add example Firestore security rules to `firestore.rules` that match the flows above.
  - Add a small Admin UI helper in the web app to mark orders as paid and optionally record `transactionReference`.
  - Add integration docs for using the Firebase Console to send FCM topic messages.

## ⚙️ Setting admin custom claims (quick utility)

For production it's recommended to use Firebase custom claims for role checks. To help with this, a small Node.js utility is included at `tools/set_custom_claims.js` that sets or removes the `admin` claim for a user.

Usage (requires a Firebase service account JSON key):

```powershell
# Install dependencies once in the repo root
npm install firebase-admin

# Run the script
node tools/set_custom_claims.js .\path\to\serviceAccountKey.json <USER_UID> true
# To remove admin claim:
node tools/set_custom_claims.js .\path\to\serviceAccountKey.json <USER_UID> false
```

Alternatives:

- Use the Firebase Admin SDK inside Cloud Functions or a trusted server to set claims programmatically.

- For smaller teams, you can still keep roles in `users/{uid}.role` in Firestore, but prefer custom claims when you can because they cannot be altered by clients.

Security note: keep service account keys secure and never commit them to source control. Use environment variables or Secret Manager in CI systems.

If you want me to make any of the follow-ups, tell me which one and I'll implement it next.
