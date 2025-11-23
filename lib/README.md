# 📁 Multi-App Architecture Documentation

## Overview

This Flutter project uses a **scalable multi-app architecture** that supports both Admin Web App and Parent App (mobile + web) while sharing common business logic.

## 🗂️ Project Structure

lib/
│
├── core/                         # 🔷 Shared logic across all apps
│   ├── config/                   # App-level configuration (theme, Firebase)
│   ├── constants/                # Constants & Firestore field names
│   ├── exceptions/               # Custom error handling
│   ├── models/                   # All Firestore models (menu_item, student, parent, etc.)
│   ├── providers/                # Global Riverpod providers
│   ├── services/                 # Shared services (auth, firestore, storage, analytics)
│   └── utils/                    # Utilities (logger, formatter, validators, etc.)
│
├── features/                     # 🎯 Feature-based modules
│   ├── admin/                    # Admin Web App only
│   │   ├── auth/                 # Login, registration, access control
│   │   ├── dashboard/            # Main dashboard with statistics
│   │   ├── menu/                 # Manage menu items and weekly menus
│   │   ├── orders/               # Order management
│   │   │   ├── orders_screen.dart            # Paginated orders list with filters
│   │   │   └── order_details_screen.dart     # Order detail view with status updates
│   │   ├── parents/              # Parent management
│   │   ├── reports/              # Analytics & reports
│   │   ├── settings/             # App settings & data seeding
│   │   ├── students/             # Student management
│   │   ├── topups/               # Top-up approval workflow
│   │   └── widgets/              # Admin-specific reusable UI components
│   │
│   └── parent/                   # Parent app (mobile + web)
│       ├── auth/                 # Login/signup
│       ├── dashboard/            # Parent dashboard
│       ├── orders/               # Place orders
│       ├── wallet/               # Balance, top-ups
│       ├── settings/             # Parent settings
│       └── widgets/              # Parent-specific reusable widgets
│
├── router/                       # 🧭 Centralized navigation
│   ├── router.dart               # Main router with platform detection
│   ├── admin_routes.dart         # Admin-only routes
│   └── parent_routes.dart        # Parent-only routes
│
├── app/                          # 🚀 Entry points
│   ├── main_admin_web.dart       # Admin web app entry
│   ├── main_parent_mobile.dart   # Parent mobile entry (mobile-only)
│   └── main_common.dart          # Shared initialization logic
│
└── shared/                       # 🎨 Shared UI components
    ├── theme/                    # (Empty - theme lives in core/config)
    ├── components/               # Shared widgets (loading, charts, etc.)
    └── layout/                   # Shared layouts

## 🎯 Design Principles

### 1. **Core Module (100% Reusable)**

- Contains all business logic, models, and services
- No UI components
- Shared across admin and parent apps
- Platform-agnostic

### 2. **Feature-Based Architecture**

- Each feature is self-contained
- Features own their UI and feature-specific logic
- Easy to navigate and maintain
- Clear separation of concerns

### 3. **Independent App Entry Points**

Each app can run independently:

- **Admin Web:** `lib/app/main_admin_web.dart`
- **Parent Mobile:** `lib/app/main_parent_mobile.dart` (mobile-only)

### 4. **Centralized Routing**

- Single source of truth for navigation
- Role-based access control
- Platform-specific route loading

## 📋 Admin Features Detail

### Orders Management System

The admin portal provides a comprehensive orders management interface with data table, filtering, and status tracking capabilities.

#### OrdersScreen (`features/admin/orders/orders_screen.dart`)

**Purpose:** Display all orders in a paginated data table with comprehensive filtering and search capabilities.

**Key Features:**
- **Data Table:** Columns for Order #, Student, Parent, Items, Amount, Status, Delivery Date, Actions
- **Filtering:**
  - Status filter dropdown (all, pending, confirmed, preparing, ready, completed, cancelled)
  - Date range picker for filtering by delivery date
  - Search box for order number or student ID lookup
  - Clear filters button to reset all filters
- **Pagination:** 10 rows per page with navigation controls
- **Status Chips:** Color-coded visual indicators (orange=pending, blue=confirmed, purple=preparing, teal=ready, green=completed, red=cancelled)
- **Actions Menu:** View Details, Update Status (conditional), Cancel Order
- **Lazy Loading:** Parent names resolved asynchronously via `_ParentNameCell` ConsumerWidget to prevent UI blocking

**Data Flow:**
```
ordersProvider (StreamProvider)
  ↓
_filterOrders() [applied client-side]
  ↓
DataTable display
  ↓
User selects action → _updateOrderStatus() or _cancelOrder()
  ↓
OrderService methods → Firestore update
```

**Key Methods:**
- `_selectDateRange()` - Date range picker dialog
- `_clearFilters()` - Reset all active filters
- `_filterOrders()` - Client-side filtering logic
- `_updateOrderStatus()` - Update order status via service
- `_cancelOrder()` - Cancel order with confirmation dialog
- `_buildStatusChip()` - Create color-coded status indicator

#### OrderDetailsScreen (`features/admin/orders/order_details_screen.dart`)

**Purpose:** Display full order information with student/parent details, item breakdown, and status management controls.

**Key Features:**
- **Order Header:** Order number, status badge, creation and delivery date/time
- **Student Info Card:** Student name, grade level with icon indicator
- **Parent Info Card:** Parent name, email with icon indicator
- **Items Breakdown:** Line-by-line itemization with name, quantity, unit price, and subtotal
- **Order Total:** Prominent display in primary color (₱ formatted)
- **Special Instructions:** Conditionally displayed when present
- **Status Update:** Dropdown selector (only enabled for non-completed/cancelled orders) with Update button
- **Cancel Order:** Button with confirmation dialog to prevent accidental cancellation
- **Refresh:** Icon button to reload order data from Firestore
- **Navigation:** Back button to return to orders list

**Data Flow:**
```
orderByIdProvider(orderId) [StreamProvider.family]
  ↓
Lazy load student info via studentsAsync
  ↓
Lazy load parent info via userByIdProvider
  ↓
Display with AsyncValue.when() for loading/error/data states
  ↓
User updates status or cancels
  ↓
OrderService methods → Firestore update → Auto-refresh via stream
```

**Key Widgets:**
- `_StudentInfoWidget` - ConsumerWidget for lazy student info resolution
- `_ParentInfoWidget` - ConsumerWidget for lazy parent info resolution

#### Shared Utilities

**ListExtensions** (`core/extensions/list_extensions.dart`)

Centralized extension to provide `firstWhereOrNull<T>` method on List:
```dart
extension FirstWhereOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
```

Used in both order screens for safe list searching without throwing exceptions.

#### Integration with Core Services

**Providers Used:**
- `ordersProvider` - StreamProvider<List<Order>> for all orders
- `studentsProvider` - StreamProvider<List<Student>> for student lookups
- `parentsProvider` - StreamProvider<List<Parent>> for parent lookups
- `userByIdProvider(parentId)` - StreamProvider.family for specific parent user info
- `orderServiceProvider` - Access to OrderService for updates and cancellations

**Service Methods:**
- `OrderService.updateOrderStatus(orderId, statusString)` - Update order status
- `OrderService.cancelOrder(orderId)` - Cancel order and log cancellation

**Models Used:**
- `Order` - Complete order document with all fields
- `OrderStatus` - Enum for valid status values
- `Student`, `Parent`, `AppUser` - For display information

## 🚀 Running the Apps

### Platform Dispatcher (Auto-detect)

```bash
# Automatically runs admin on web, parent on mobile
flutter run -d chrome              # Runs admin web
flutter run -d emulator-5554       # Runs parent mobile
```

### Explicit Entry Points

```bash
# Admin Web App
flutter run -d chrome --target lib/app/main_admin_web.dart

# Parent Mobile App
flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart
flutter run -d iPhone --target lib/app/main_parent_mobile.dart

// Parent Web App support removed. Use the mobile entrypoint for Parent app.
```

## 📦 Import Conventions

### From Features to Core

```dart
// From features/admin/dashboard/
import '../../../core/models/order.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/auth_service.dart';
```

### From Features to Shared

```dart
// From features/admin/dashboard/
import '../../../shared/components/loading_indicator.dart';
```

### Within Feature

```dart
// From features/admin/menu/ to features/admin/menu/widgets/
import 'widgets/menu_item_card.dart';

// From features/admin/dashboard/ to features/admin/widgets/
import '../widgets/admin_scaffold.dart';
```

### From Router

```dart
// From router/
import '../core/providers/app_providers.dart';
import '../features/admin/auth/login_screen.dart';
import '../features/parent/dashboard/parent_dashboard_screen.dart';
```

### From App Entry Points

```dart
// From app/
import '../core/config/app_theme.dart';
import '../router/router.dart';
```

## 🔐 Authentication & Authorization

### Role-Based Access Control

- **Admin:** Full access to admin features (web only)
- **Parent:** Access to parent features (mobile + web)

### Platform Enforcement

- **Web:** Enforces admin-only access
- **Mobile:** Enforces parent-only access

### Router Guards

The main router (`router/router.dart`) implements:

1. Authentication checks
2. Role-based redirects
3. Platform-specific route loading

## 🎨 Shared Components

Reusable widgets live in `shared/components/`:

- `loading_indicator.dart` - Loading spinner
- `stat_card.dart` - Dashboard stat cards
- `week_picker.dart` - Week selection widget
- `analytics_charts.dart` - Chart components
- `analytics_utils.dart` - Chart utilities
- `import_preview_dialog.dart` - CSV import preview

## 📝 Adding New Features

### Admin Feature

1. Create directory: `features/admin/new_feature/`
2. Add screens and widgets
3. Register routes in `router/admin_routes.dart`
4. Add navigation in `features/admin/widgets/admin_scaffold.dart`

### Parent Feature

1. Create directory: `features/parent/new_feature/`
2. Add screens and widgets
3. Register routes in `router/parent_routes.dart`

## Billing model note

Important: Students are imported entities and not authenticated users. The application charges orders to the linked parent's wallet (the `parents` collection). Student balance fields remain for administrative/reference purposes only. Order processing code and transactions deduct from the parent document, not student documents. If you need per-student billing, update the order creation and transaction logic accordingly.

### Shared Component

1. Add widget to `shared/components/`
2. Import from features: `import '../../../shared/components/my_widget.dart';`

## 🛠️ Common Models

All shared models live in `core/models/`:

- `menu_item.dart` - Food/drink items
- `weekly_menu.dart` - Weekly menu schedules
- `order.dart` - Order records
- `student.dart` - Student profiles
- `parent.dart` - Parent profiles
- `topup.dart` - Top-up requests
- `user_role.dart` - User role enum

## 🔧 Common Services

All shared services live in `core/services/`:

- `auth_service.dart` - Authentication
- `menu_service.dart` - Menu management
- `order_service.dart` - Order management
- `student_service.dart` - Student management
- `parent_service.dart` - Parent management
- `topup_service.dart` - Top-up management
- `storage_service.dart` - Firebase Storage
- `weekly_menu_service.dart` - Weekly menu operations

## 🎯 Benefits of This Architecture

### ✅ Scalability

- Easy to add new features
- Clear separation between apps
- Shared code reduces duplication

### ✅ Maintainability

- Feature-based organization
- Easy to navigate
- Clear dependencies

### ✅ Testability

- Core logic is isolated
- Features can be tested independently
- Mock services easily

### ✅ Team Collaboration

- Clear boundaries between features
- Multiple developers can work in parallel
- Reduced merge conflicts

## 🔄 Migration Notes

### From Old Structure

ui/screens/admin/    → features/admin/
ui/screens/parent/   → features/parent/
ui/widgets/          → shared/components/
ui/router/           → router/
main_web.dart        → app/main_admin_web.dart
main_mobile.dart     → app/main_parent_mobile.dart

### Import Updates

- `../../../core/` stays the same
- `../../../widgets/` → `../../../shared/components/`
- `../../screens/` → `../` (within features)

## 📚 Further Reading

- `MULTI_PLATFORM_ARCHITECTURE.md` - Detailed architecture guide
- `MULTI_PLATFORM_QUICK_REFERENCE.md` - Quick reference
- `HOW_TO_CREATE_ADMIN_ACCOUNT.md` - Admin setup
- `DEPLOYMENT_GUIDE.md` - Deployment instructions
