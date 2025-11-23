# 📁 Multi-App Architecture Documentation

## Overview

This Flutter project implements a **scalable multi-app architecture** supporting an Admin Web Dashboard and Parent Mobile App, with 100% shared core business logic via Riverpod dependency injection and Supabase backend.

**Key Architecture Benefits:**
- Single codebase with two independent apps (Admin & Parent)
- Shared models, services, and business logic in lib/core/
- Feature-based organization for maintainability
- Role-based access control at routing and database level
- Supabase PostgreSQL with Row Level Security (RLS)
- Riverpod for efficient state management and testing

## 🗂️ Project Structure

```
lib/
│
├── core/                         # 🔷 Shared code (100% reusable)
│   ├── config/                   # Configuration (theme, Supabase, env)
│   ├── constants/                # Constants & database field names
│   ├── exceptions/               # Custom exceptions
│   ├── extensions/               # Dart extensions
│   ├── interfaces/               # Service interfaces (for DI)
│   ├── models/                   # Data models
│   ├── providers/                # Riverpod providers
│   ├── services/                 # Business logic services
│   ├── utils/                    # Utilities, logger, formatters
│   ├── link_provider.dart        # Deep linking config
│   └── links_adapter.dart        # Link handler
│
├── features/                     # 🎯 Feature modules
│   ├── admin/                    # Admin Web App
│   │   ├── auth/                 # Login & access control
│   │   ├── dashboard/            # Main dashboard
│   │   ├── menu/                 # Menu management
│   │   ├── orders/               # Order management & tracking
│   │   ├── parents/              # Parent management
│   │   ├── reports/              # Analytics & exports
│   │   ├── settings/             # Admin settings
│   │   ├── students/             # Student management
│   │   ├── topups/               # Top-up approvals
│   │   └── widgets/              # Admin UI components
│   │
│   ├── parent/                   # Parent App (Mobile)
│   │   ├── auth/                 # Auth flow
│   │   ├── cart/                 # Shopping cart
│   │   ├── dashboard/            # Home screen
│   │   ├── menu/                 # Browse menu
│   │   ├── orders/               # Order history
│   │   ├── settings/             # Settings
│   │   ├── student_link/         # Link students
│   │   ├── wallet/               # Balance & top-ups
│   │   └── widgets/              # Parent UI components
│   │
│   └── payments/                 # Payment processing
│
├── router/                       # 🧭 Navigation
│   ├── router.dart               # Main router
│   ├── admin_routes.dart         # Admin routes
│   └── parent_routes.dart        # Parent routes
│
├── app/                          # 🚀 Entry points
│   ├── main_admin_web.dart       # Admin app entry
│   ├── main_parent_mobile.dart   # Parent app entry
│   └── main_common.dart          # Shared initialization
│
├── shared/                       # 🎨 Shared UI
│   ├── components/               # Reusable widgets
│   ├── layout/                   # Layouts & scaffolds
│   └── theme/                    # Theme (delegated to core)
│
└── main.dart                     # Platform dispatcher
```

## 🎯 Design Principles

### 1. **Core Module (100% Reusable)**

All business logic, models, and services live in lib/core/ with no UI components:

- Models define data structure (Order, Student, Parent, MenuItem, etc.)
- Services encapsulate business logic (OrderService, StudentService, etc.)
- Providers manage dependency injection and state (Riverpod)
- Utilities provide shared functions (logger, formatters, validators)
- Configuration centralizes app settings (theme, Supabase, environment)

### 2. **Feature-Based Architecture**

Each feature is self-contained in its own directory:

features/admin/orders/
├── orders_screen.dart           # Main UI screen
├── widgets/
│   └── order_card.dart          # Feature-specific widgets
└── models/                      # Feature-specific models (if any)

Benefits:
- Features can be worked on independently
- Easy to locate and modify feature code
- Clear separation of concerns
- Minimal cross-feature dependencies

### 3. **Service Interfaces for Testing**

All services implement interfaces for easy mocking:

```dart
// lib/core/interfaces/i_order_service.dart
abstract class IOrderService {
  Stream<List<Order>> getOrders();
  Future<void> updateOrderStatus(String orderId, String status);
}

// lib/core/services/order_service.dart
class OrderService implements IOrderService { /* ... */ }

// Tests can mock easily
final mockService = MockOrderService();
```

### 4. **Riverpod Providers for Dependency Injection**

All dependencies are provided via Riverpod:

```dart
// lib/core/providers/transaction_providers.dart
final orderServiceProvider = Provider<IOrderService>((ref) {
  return OrderService(supabase: ref.watch(supabaseProvider));
});

// Use in UI
Consumer(
  builder: (context, ref, child) {
    final orderService = ref.watch(orderServiceProvider);
    // ...
  },
)
```

### 5. **Supabase with Row Level Security**

Database security is enforced at the RLS policy level:

```sql
-- Admins can update any order
CREATE POLICY "admin_update_orders"
  ON orders FOR UPDATE
  USING (auth.jwt() ->> 'is_admin' = 'true');

-- Parents can only see their own orders
CREATE POLICY "parent_read_own_orders"
  ON orders FOR SELECT
  USING (parent_id = auth.uid());
```

## 🚀 Running the Apps

### Platform Auto-Detection

```bash
# Web → Admin Dashboard
flutter run -d chrome

# Mobile → Parent App
flutter run -d emulator-5554
```

### Explicit Entry Points

```powershell
# Admin Dashboard
flutter run -d chrome --target lib/app/main_admin_web.dart

# Parent Mobile
flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart

# Build Web
flutter build web --target lib/app/main_admin_web.dart

# Build Mobile
flutter build apk --target lib/app/main_parent_mobile.dart
```

## 📦 Core Module Details

### Service Architecture

Services implement interfaces and are provided via Riverpod:

```dart
// Service interface
abstract class IStudentService {
  Stream<List<Student>> getStudents();
  Future<Student?> getStudentById(String id);
  Future<void> addStudent(Student student);
  Future<void> updateStudent(Student student);
  Future<void> deleteStudent(String id);
}

// Implementation
class StudentService implements IStudentService {
  final SupabaseClient _supabase;
  
  StudentService({SupabaseClient? supabase}) 
    : _supabase = supabase ?? SupabaseConfig.client;
  
  @override
  Stream<List<Student>> getStudents() {
    return _supabase
        .from('students')
        .stream(primaryKey: ['id'])
        .map((data) => data.map(Student.fromMap).toList());
  }
}

// Provider
final studentServiceProvider = Provider<IStudentService>((ref) {
  return StudentService(supabase: ref.watch(supabaseProvider));
});
```

### Provider Organization

Providers are organized by domain and exported centrally:

```dart
// lib/core/providers/app_providers.dart
export 'supabase_providers.dart';     // Supabase client
export 'auth_providers.dart';         // Auth & user
export 'user_providers.dart';         // Students & parents
export 'menu_providers.dart';         // Menu items & weekly menus
export 'transaction_providers.dart';  // Orders & topups
export 'storage_providers.dart';      // File storage

// Usage in features
import '../../../core/providers/app_providers.dart';
final order = ref.watch(orderByIdProvider(orderId));
```

### Data Models

All models use toMap/fromMap pattern for Supabase serialization:

```dart
class Order {
  final String id;
  final String orderNumber;
  final String parentId;
  final String studentId;
  final List<OrderItem> items;
  final Decimal totalAmount;
  final OrderStatus status;
  final DateTime deliveryDate;
  final DateTime createdAt;
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_number': orderNumber,
      'parent_id': parentId,
      'student_id': studentId,
      'items': jsonEncode(items),
      'total_amount': totalAmount,
      'status': status.name,
      'delivery_date': deliveryDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as String,
      orderNumber: map['order_number'] as String,
      parentId: map['parent_id'] as String,
      studentId: map['student_id'] as String,
      items: (jsonDecode(map['items']) as List)
          .map((i) => OrderItem.fromMap(i))
          .toList(),
      totalAmount: Decimal.parse(map['total_amount'].toString()),
      status: OrderStatus.values.byName(map['status'] as String),
      deliveryDate: DateTime.parse(map['delivery_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
```

## 📝 Adding New Features

### Admin Feature Example

1. **Create directory:**
   ```
   lib/features/admin/inventory/
   ├── inventory_screen.dart
   └── widgets/
       ├── inventory_table.dart
       └── add_item_dialog.dart
   ```

2. **Create screen:**
   ```dart
   class InventoryScreen extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final items = ref.watch(menuItemsProvider);
       return items.when(
         data: (data) => InventoryTable(items: data),
         loading: () => const Loader(),
         error: (e, st) => ErrorDisplay(error: e),
       );
     }
   }
   ```

3. **Add routes:**
   ```dart
   // lib/router/admin_routes.dart
   GoRoute(
     path: '/admin/inventory',
     builder: (context, state) => const InventoryScreen(),
   ),
   ```

4. **Add navigation:**
   ```dart
   // lib/features/admin/widgets/admin_scaffold.dart
   ListTile(
     title: const Text('Inventory'),
     onTap: () => GoRouter.of(context).go('/admin/inventory'),
   ),
   ```

### Parent Feature Example

1. **Create directory:**
   ```
   lib/features/parent/favorites/
   ├── favorites_screen.dart
   └── widgets/
       └── favorite_item_card.dart
   ```

2. **Create screen and routes similarly**

## 📦 Import Conventions

```dart
// From core (models, services, providers)
import '../../../core/models/order.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/order_service.dart';

// From shared UI
import '../../../shared/components/loading_indicator.dart';
import '../../../shared/layout/app_scaffold.dart';

// Within feature (going up to widgets in same feature)
import 'widgets/my_widget.dart';
import '../parents/widgets/parent_card.dart';  // Sibling feature (avoid)

// From router
import '../../../router/router.dart';
```

## 🔐 Authentication & Authorization

### Authentication Flow

1. User launches app
2. Router checks `authStateProvider`
3. If unauthenticated → Login screen
4. User signs in via email or Google
5. Supabase creates user with JWT token
6. User document created in `users` table with roles
7. App reads JWT claims for `is_admin` role
8. Router directs to admin or parent based on role
9. On app restart, Supabase restores session

### Authorization

Frontend:
```dart
// Router redirect based on role
redirect: (context, state) {
  final user = ref.watch(currentUserProvider);
  return user?.isAdmin == true ? null : '/login';
}
```

Backend (RLS policies):
```sql
-- Only admins can update menu_items
CREATE POLICY "admin_update_items"
  ON menu_items FOR UPDATE
  USING (auth.jwt() ->> 'is_admin' = 'true');
```

## 🛠️ Common Services

### OrderService

```dart
// Stream all orders (admin)
final ordersProvider = StreamProvider<List<Order>>((ref) {
  return ref.watch(orderServiceProvider).getOrders();
});

// Get single order
final orderByIdProvider = StreamProvider.family<Order?, String>((ref, id) {
  return ref.watch(orderServiceProvider).getOrderById(id);
});

// Update status
await ref.read(orderServiceProvider).updateOrderStatus(
  orderId: '123',
  status: 'ready',
);
```

### StudentService

```dart
// Stream all students
final studentsProvider = StreamProvider<List<Student>>((ref) {
  return ref.watch(studentServiceProvider).getStudents();
});

// Create new student
await ref.read(studentServiceProvider).addStudent(
  Student(
    firstName: 'John',
    lastName: 'Doe',
    grade: '5',
    parentId: parentId,
  ),
);
```

### StorageService

```dart
// Upload file
await ref.read(storageServiceProvider).uploadFile(
  bucket: 'menu_items',
  path: 'item_${uuid.v4()}.jpg',
  file: imageFile,
);
```

## ✅ Testing Approach

### Unit Tests

```dart
void main() {
  group('OrderService', () {
    test('creates order with correct data', () async {
      final mockSupabase = MockSupabaseClient();
      final service = OrderService(supabase: mockSupabase);
      
      final result = await service.createOrder(
        parentId: 'parent123',
        studentId: 'student456',
        items: [mockOrderItem],
      );
      
      expect(result, isNotNull);
      verify(mockSupabase.from('orders').insert(any)).called(1);
    });
  });
}
```

### Widget Tests

```dart
testWidgets('OrdersScreen displays orders', (tester) async {
  await tester.pumpWidget(
    ProviderContainer(
      overrides: [
        ordersProvider.overrideWithValue(
          AsyncValue.data([mockOrder1, mockOrder2]),
        ),
      ],
      child: const MaterialApp(home: OrdersScreen()),
    ),
  );
  
  expect(find.byType(DataTable), findsOneWidget);
  expect(find.text('Order #001'), findsOneWidget);
});
```

## ⚖️ Important: Billing Model

**Orders are charged to the PARENT's wallet, not individual students.**

- `parents.balance` is decremented when order is created
- `students.balance` is for admin reference only
- Parents must top-up their wallet before placing orders

If you need per-student billing, modify OrderService to deduct from `students.balance` instead:

```dart
// Current: Deduct from parent
await _supabase
    .from('parents')
    .update({'balance': parentBalance - totalAmount})
    .eq('id', parentId);

// Alternative: Deduct from student
await _supabase
    .from('students')
    .update({'balance': studentBalance - totalAmount})
    .eq('id', studentId);
```

## 🔗 External Resources

- [Flutter Riverpod](https://riverpod.dev)
- [Supabase Flutter](https://supabase.com/docs/reference/dart/)
- [Go Router](https://pub.dev/packages/go_router)
- [Flutter Testing](https://flutter.dev/docs/testing)

## 🎯 Architecture Decision Records

### ADR-001: Supabase over Firebase

**Decision**: Use Supabase PostgreSQL

**Rationale**:
- SQL for complex queries
- Row-Level Security at database
- Cost-effective for scale
- Better transaction support
- Realtime with PostgreSQL trigger

### ADR-002: Riverpod for State

**Decision**: Use flutter_riverpod throughout

**Rationale**:
- No BuildContext required
- Automatic dependency management
- Easy provider overrides
- Better performance
- Decouples UI from logic

### ADR-003: Feature-Based Organization

**Decision**: Organize by feature, not by layer

**Rationale**:
- Easier to scale (add features)
- Feature-specific widgets stay together
- Clear feature boundaries
- Simpler navigation
- Faster parallel development
