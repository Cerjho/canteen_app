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
