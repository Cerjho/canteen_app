# School Canteen Admin App 🍽️

A modern Flutter project with two separate apps sharing core logic:

- Admin: Web-only Admin Dashboard (in `lib/admin/`)
- Parent: Mobile-only Parent App (in `lib/parent/`)

## 📋 Features

### Admin Features

- **Dashboard Overview**: Real-time statistics for orders, revenue, and pending top-ups
- **Student Management**: CRUD operations, assign students to parents
- **Parent Management**: View/edit parent profiles, manage balances
- **Menu Management**: Add/edit menu items with images, prices, allergens
- **Orders Management**: 
  - View all orders in paginated data table
  - Filter by status (pending, confirmed, preparing, ready, completed, cancelled)
  - Filter by date range with date picker
  - Search orders by order number or student ID
  - Quick actions: View details, update status, cancel order
  - Real-time order status updates with visual status chips
  - View order breakdown: items, quantities, unit prices, totals
  - View student and parent information linked to order
- **Top-up Management**: Approve/decline balance top-up requests
- **Reports**: Export orders and revenue to CSV/Excel
- **Settings**: App configuration and preferences

## 🏗️ Project Structure

lib/
├── core/                    # Shared code for both Admin & Parent apps
│   ├── models/             # Data models (Student, Parent, Order, etc.)
│   ├── services/           # Firebase services (Firestore, Auth, Storage)
│   ├── providers/          # Riverpod providers for state management
│   ├── utils/              # Utility functions (formatting, validation, export)
│   └── config/             # App configuration (theme, Firebase)
├── admin/                   # Admin app specific code (web)
│   ├── screens/            # Admin UI screens
│   │   ├── auth/          # Login screen
│   │   ├── dashboard/     # Dashboard with statistics
│   │   ├── students/      # Student management
│   │   ├── parents/       # Parent management
│   │   ├── menu/          # Menu item management
│   │   ├── orders/        # Order management
│   │   ├── topups/        # Top-up management
│   │   ├── reports/       # Reports and exports
│   │   └── settings/      # Settings
│   ├── widgets/           # Reusable admin widgets
│   └── router/            # Go Router configuration
└── parent/                 # Parent app (mobile-only)
   └── parent_app.dart    # Parent app entry point (mobile)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.9.2 or higher)
- Firebase account
- IDE (VS Code, Android Studio, etc.)

### Installation

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd admin_app
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure Firebase**

   You need to set up Firebase for your project:

   a. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)

   b. Enable the following services:
      - Authentication (Email/Password)
      - Cloud Firestore
      - Storage

   c. Get your Firebase configuration:
      - Go to Project Settings > General
      - Scroll down to "Your apps"
      - Click on the Web icon (</>)
      - Copy the configuration

   d. Update `lib/core/config/firebase_options.dart` with your Firebase configuration:

   ```dart
   static const FirebaseOptions web = FirebaseOptions(
     apiKey: 'YOUR_WEB_API_KEY',
     authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
     projectId: 'YOUR_PROJECT_ID',
     storageBucket: 'YOUR_PROJECT_ID.appspot.com',
     messagingSenderId: 'YOUR_SENDER_ID',
     appId: 'YOUR_WEB_APP_ID',
     measurementId: 'YOUR_MEASUREMENT_ID',
   );
   ```

4. **Set up Firestore Security Rules**

   In Firebase Console > Firestore Database > Rules, add:

   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       // Allow authenticated users to read/write
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }

5. **Create an admin user**

   In Firebase Console > Authentication > Users > Add User, create an admin account.

### Running the Apps

This repository now contains two separate entrypoints. Use the explicit --target flag to run the app you want.

#### Admin (Web)

Starts the Admin Dashboard in the browser (web-only).

```powershell
flutter run -d chrome --target lib/app/main_admin_web.dart
```

#### Parent (Mobile - Android/iOS)

Runs the Parent mobile app on an emulator or device.

```powershell
# Android emulator or device
flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart

# iOS simulator (on macOS)
flutter run -d <iPhone-device-id> --target lib/app/main_parent_mobile.dart
```

#### Build for production

```powershell
# Web (Admin)
flutter build web --target lib/app/main_admin_web.dart

# Android (Parent mobile)
flutter build apk --target lib/app/main_parent_mobile.dart

# iOS (Parent mobile)
flutter build ios --target lib/app/main_parent_mobile.dart
```

## 🎨 Tech Stack

- **Framework**: Flutter 3.9.2
- **State Management**: Riverpod 2.6.1
- **Routing**: Go Router 14.8.1
- **Backend**: Firebase (Auth, Firestore, Storage)
- **UI**: Material Design 3
- **Data Export**: CSV, Excel

## 📦 Key Packages

- `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage` - Firebase integration
- `flutter_riverpod` - State management
- `go_router` - Declarative routing
- `intl` - Internationalization and formatting
- `csv`, `excel` - Data export
- `image_picker`, `file_picker` - File uploads
- `cached_network_image` - Image caching
- `fl_chart` - Charts and graphs

## 🔑 Default Credentials

**Note**: You need to create an admin user in Firebase Authentication first.

Example:

- Email: `admin@example.com`
- Password: `admin123`

## 📊 Database Schema

### Collections

#### students

- id, firstName, lastName, grade
- parentId, allergies, dietaryRestrictions
- balance, isActive, photoUrl
- createdAt, updatedAt

#### parents

- id, firstName, lastName, email
- phoneNumber, balance, studentIds
- isActive, photoUrl
- createdAt, updatedAt

#### menu_items

- id, name, description, price, category
- imageUrl, allergens[]
- isVegetarian, isVegan, isGlutenFree
- isAvailable, stockQuantity
- createdAt, updatedAt

#### orders

- id, orderNumber, parentId, studentId
- items[], totalAmount, status, orderType
- deliveryDate, deliveryTime
- specialInstructions, notes
- completedAt, cancelledAt
- createdAt, updatedAt

**Order Status Workflow:**
- `pending` - Order created, awaiting confirmation (orange)
- `confirmed` - Order confirmed by admin (blue)
- `preparing` - Kitchen is preparing the order (purple)
- `ready` - Order ready for pickup/delivery (teal)
- `completed` - Order delivered or picked up (green)
- `cancelled` - Order cancelled by admin or parent (red)

**Order Type:**
- `oneTime` - Single order for a specific date
- `weekly` - Recurring weekly order

**Integration Note:** Orders are charged to the linked parent's wallet, not individual student balances. Parents must top up their wallet to place orders for linked students.

#### topups

- id, parentId, parentName
- studentId, studentName, amount
- status, paymentMethod
- transactionReference, proofImageUrl
- notes, adminNotes, processedBy
- requestDate, processedAt
- createdAt, updatedAt

## 🔄 Firestore Update Operations & Permissions

### How Updates Work

- Updates to Firestore documents are performed using the `.update()` method for partial updates, or `.set(..., merge: true)` for merging new data.
- Most update operations also set an `updatedAt` timestamp to track changes.
- Update logic is encapsulated in service classes (see `lib/core/services/`).

### Update Permissions (by Collection)

| Collection    | Who Can Update?         | Updatable Fields (by non-admin)                | Notes |
|--------------|------------------------|------------------------------------------------|-------|
| users        | Admin only             | All fields                                     | Users cannot update their own role or isActive |
| parents      | Admin, Parent (self)   | Parents: address, phone, children[]             | Parents cannot update balance or userId        |
| students     | Admin only             | All fields                                     | Parents cannot update student info directly    |
| menu_items   | Admin only             | All fields                                     |                                             |
| orders       | Admin only             | status, notes                                  |                                             |
| topups       | Admin only             | status, adminNotes, processedBy, processedAt    |                                             |

Field-level security is enforced by Firestore security rules. See the `firestore.rules` file for details.

### Example Update Flows

#### Update User Profile (Admin)

```dart
await userService.updateUser(updatedUser);
```

#### Update Parent Contact Info (Parent)

```dart
await parentService.updateContactInfo(userId: parentId, address: 'New Address', phone: '123456789');
```

#### Update Student Balance (Admin)

```dart
await studentService.updateBalance(studentId, newBalance);
```

#### Update Menu Item Availability (Admin)

```dart
await menuService.updateAvailability(menuItemId, true);
```

#### Update Order Status (Admin)

```dart
await orderService.updateOrderStatus(orderId, 'completed');
```

#### Approve Top-up (Admin)

```dart
await topupService.approveTopup(topupId, adminId);
```

### Security Example

Parents can update their own address and phone, but cannot change their balance:

```js
// firestore.rules
allow update: if isAdmin() || (isOwnParentAccount(parentUserId) && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['balance', 'userId']));
```

For more, see the `firestore.rules` file and service class documentation.

To populate your database with test data:

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
