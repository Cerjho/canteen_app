import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';

/// Cart State Notifier - Manages shopping cart state
/// 
/// Features:
/// - Add items to cart
/// - Update item quantities
/// - Remove items
/// - Clear entire cart
/// - Calculate totals
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  /// Add an item to the cart or increase quantity if it already exists
  void addItem(MenuItem menuItem, {int quantity = 1, String? studentId, String? studentName}) {
    final existingIndex = state.indexWhere((item) => item.menuItemId == menuItem.id && item.studentId == studentId);
    
    if (existingIndex >= 0) {
      // Item already in cart for this student - increase quantity
      final existingItem = state[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      
      final newState = [...state];
      newState[existingIndex] = updatedItem;
      state = newState;
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
      );
      
      state = [...state, cartItem];
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
  }

  /// Clear all items from the cart
  void clear() {
    state = [];
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
  return CartNotifier();
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
