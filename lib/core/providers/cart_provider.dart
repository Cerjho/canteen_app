import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import 'auth_providers.dart';
import 'supabase_providers.dart';
import '../services/cart_persistence_service.dart';

/// Cart State Notifier - Manages shopping cart state
/// 
/// Features:
/// - Add items to cart
/// - Update item quantities
/// - Remove items
/// - Clear entire cart
/// - Calculate totals
class CartNotifier extends StateNotifier<List<CartItem>> {
  final Ref ref;
  CartNotifier(this.ref) : super([]) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final uid = ref.read(currentUserProvider).value?.uid;
      if (uid == null) return;
      final service = CartPersistenceService(supabase: ref.read(supabaseProvider));
      // Prefer normalized carts; fallback to saved_carts JSON
      var items = await service.fetchDailyCartFromTables(uid);
      if (items.isEmpty) {
        items = await service.fetchDailyCart(uid);
      }
      if (items.isNotEmpty) state = items;
    } catch (_) {
      // Ignore load errors to avoid blocking UI
    }
  }

  Future<void> _persist() async {
    try {
      final uid = ref.read(currentUserProvider).value?.uid;
      if (uid == null) return;
      final service = CartPersistenceService(supabase: ref.read(supabaseProvider));
      await service.saveDailyCart(uid, state);
      await service.saveDailyCartToTables(uid, state);
    } catch (_) {}
  }

  /// Add an item to the cart or increase quantity if it already exists
  void addItem(
    MenuItem menuItem, {
    int quantity = 1,
    String? studentId,
    String? studentName,
    String? deliveryTime, // '09:00', '12:00', '14:00'
    String? specialInstructions,
  }) {
    final existingIndex = state.indexWhere((item) =>
        item.menuItemId == menuItem.id &&
        item.studentId == studentId &&
        item.deliveryTime == deliveryTime &&
        (item.specialInstructions ?? '') == (specialInstructions ?? ''));
    
    if (existingIndex >= 0) {
      // Item already in cart for this student - increase quantity
      final existingItem = state[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      
      final newState = [...state];
      newState[existingIndex] = updatedItem;
  state = newState;
  _persist();
    } else {
      // New item - add to cart
      final cartItem = CartItem(
        id: const Uuid().v4(),
        menuItemId: menuItem.id,
        name: menuItem.name,
        imageUrl: menuItem.imageUrl,
        price: menuItem.price,
        quantity: quantity,
        category: menuItem.category,
        addedAt: DateTime.now(),
        studentId: studentId,
        studentName: studentName,
        deliveryTime: deliveryTime,
        specialInstructions: specialInstructions,
      );
      
      state = [...state, cartItem];
      _persist();
    }
  }

  /// Update quantity of a specific item
  void updateQuantity(String cartItemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(cartItemId);
      return;
    }

    final index = state.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      final updatedItem = state[index].copyWith(quantity: newQuantity);
      final newState = [...state];
      newState[index] = updatedItem;
      state = newState;
      _persist();
    }
  }

  /// Increment quantity by 1
  void incrementQuantity(String cartItemId) {
    final index = state.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      updateQuantity(cartItemId, state[index].quantity + 1);
    }
  }

  /// Decrement quantity by 1
  void decrementQuantity(String cartItemId) {
    final index = state.indexWhere((item) => item.id == cartItemId);
    if (index >= 0) {
      updateQuantity(cartItemId, state[index].quantity - 1);
    }
  }

  /// Remove a specific item from the cart
  void removeItem(String cartItemId) {
    state = state.where((item) => item.id != cartItemId).toList();
    _persist();
  }

  /// Remove all items for a given student
  void removeItemsForStudent(String studentId) {
    state = state.where((item) => item.studentId != studentId).toList();
    _persist();
  }

  /// Clear all items from the cart
  void clear() {
    state = [];
    _persist();
  }

  /// Get total price of all items
  double get total => state.fold(0, (sum, item) => sum + item.total);

  /// Get total number of items (sum of quantities)
  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);

  /// Get number of unique items
  int get uniqueItemCount => state.length;

  /// Check if cart is empty
  bool get isEmpty => state.isEmpty;

  /// Check if cart has items
  bool get isNotEmpty => state.isNotEmpty;
}

/// Main cart provider
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier(ref);
});

/// Derived provider for cart total
final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.total);
});

/// Derived provider for total item count
final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

/// Derived provider for unique item count
final cartUniqueItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.length;
});

/// Derived provider for cart empty state
final cartIsEmptyProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.isEmpty;
});
