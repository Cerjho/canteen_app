import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'date_refresh_provider.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/menu_item.dart';
import 'auth_providers.dart';
import 'supabase_providers.dart';
import '../services/cart_persistence_service.dart';

/// WeeklyCartItem - represents an item ordered for a specific day
class WeeklyCartItem {
  final String id;
  final MenuItem menuItem;
  final DateTime date; // Normalized to midnight (year, month, day)
  final int quantity;
  final DateTime addedAt;
  final String? studentId;
  final String? studentName;
  final String? mealType; // e.g., "Snack", "Lunch"
  final String? time; // e.g., "Morning", "Afternoon" for snacks

  WeeklyCartItem({
  required this.id,
  required this.menuItem,
  required this.date,
  required this.quantity,
  required this.addedAt,
  this.studentId,
  this.studentName,
  this.mealType,
  this.time,
  });

  /// Get total price for this item (price * quantity)
  double get total => menuItem.price * quantity;

  /// Create a copy with modified fields
  WeeklyCartItem copyWith({
  String? id,
  MenuItem? menuItem,
  DateTime? date,
  int? quantity,
  DateTime? addedAt,
  String? studentId,
  String? studentName,
  String? mealType,
  String? time,
  }) {
    return WeeklyCartItem(
      id: id ?? this.id,
      menuItem: menuItem ?? this.menuItem,
      date: date ?? this.date,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      mealType: mealType ?? this.mealType,
      time: time ?? this.time,
    );
  }
}

/// WeeklySummary - computed summary of weekly cart
class WeeklySummary {
  final double totalCost;
  final int totalItems;
  final Map<String, int> categoryBreakdown; // Category -> item count
  final Map<DateTime, double> dailyCosts; // Date -> cost
  final int daysWithOrders;
  final double averageCostPerDay;

  WeeklySummary({
    required this.totalCost,
    required this.totalItems,
    required this.categoryBreakdown,
    required this.dailyCosts,
    required this.daysWithOrders,
    required this.averageCostPerDay,
  });
}

/// WeeklyCartNotifier - manages weekly cart state (Mon-Fri orders)
/// 
/// State structure: Map<DateTime, List<WeeklyCartItem>>
/// - Key: Normalized date (midnight) representing the day
/// - Value: List of items ordered for that day
class WeeklyCartNotifier extends StateNotifier<Map<DateTime, List<WeeklyCartItem>>> {
  final Ref ref;
  WeeklyCartNotifier(this.ref) : super({}) {
    _loadFromDb();
  }

  Future<void> _loadFromDb() async {
    try {
      final uid = ref.read(currentUserProvider).value?.uid;
      if (uid == null) return;
      final service = CartPersistenceService(supabase: ref.read(supabaseProvider));
      final data = await service.fetchWeeklyCart(uid);
      if (data.isNotEmpty) state = data;
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final uid = ref.read(currentUserProvider).value?.uid;
      if (uid == null) return;
      final service = CartPersistenceService(supabase: ref.read(supabaseProvider));
      await service.saveWeeklyCart(uid, state);
    } catch (_) {}
  }

  final _uuid = const Uuid();

  /// Normalize date to midnight (strip time component)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Add item for a specific date
  void addItemForDate(MenuItem menuItem, DateTime date, {int quantity = 1, String? studentId, String? studentName, String? mealType, String? time}) {
    final sw = Stopwatch()..start();
    final normalizedDate = _normalizeDate(date);
    final currentItems = state[normalizedDate] ?? [];
    
    // Check if item already exists for this date
    final existingIndex = currentItems.indexWhere(
      (item) => item.menuItem.id == menuItem.id && item.studentId == studentId && item.mealType == mealType && item.time == time,
    );

    if (existingIndex >= 0) {
      // Item exists for this student/mealType/time - increase quantity
      final existingItem = currentItems[existingIndex];
      final updatedItem = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      
      final updatedList = [...currentItems];
      updatedList[existingIndex] = updatedItem;
      
  state = {...state, normalizedDate: updatedList};
  _persist();
      sw.stop();
      if (kDebugMode) developer.log('addItemForDate (update) took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
    } else {
      // New item - add to list
      final newItem = WeeklyCartItem(
        id: _uuid.v4(),
        menuItem: menuItem,
        date: normalizedDate,
        quantity: quantity,
        addedAt: DateTime.now(),
        studentId: studentId,
        studentName: studentName,
        mealType: mealType,
        time: time,
      );
      
      state = {
        ...state,
        normalizedDate: [...currentItems, newItem],
      };
      _persist();
      sw.stop();
      if (kDebugMode) developer.log('addItemForDate (add) took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
    }
  }

  /// Remove item for a specific date
  void removeItemForDate(String itemId, DateTime date) {
    final sw = Stopwatch()..start();
    final normalizedDate = _normalizeDate(date);
    final currentItems = state[normalizedDate];
    
    if (currentItems == null) return;
    
    final updatedItems = currentItems.where((item) => item.id != itemId).toList();
    
    if (updatedItems.isEmpty) {
      // Remove the date key if no items left
      final newState = Map<DateTime, List<WeeklyCartItem>>.from(state);
      newState.remove(normalizedDate);
  state = newState;
  _persist();
      sw.stop();
      if (kDebugMode) developer.log('removeItemForDate (remove key) took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
    } else {
  state = {...state, normalizedDate: updatedItems};
  _persist();
      sw.stop();
      if (kDebugMode) developer.log('removeItemForDate (update list) took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
    }
  }

  /// Update quantity for a specific item on a specific date
  void updateQuantityForDate(String itemId, DateTime date, int newQuantity) {
    final sw = Stopwatch()..start();
    if (newQuantity <= 0) {
      removeItemForDate(itemId, date);
      sw.stop();
      if (kDebugMode) developer.log('updateQuantityForDate (removed) took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
      return;
    }

    final normalizedDate = _normalizeDate(date);
    final currentItems = state[normalizedDate];
    
    if (currentItems == null) return;
    
    final itemIndex = currentItems.indexWhere((item) => item.id == itemId);
    if (itemIndex < 0) return;
    
    final updatedItem = currentItems[itemIndex].copyWith(quantity: newQuantity);
    final updatedItems = [...currentItems];
    updatedItems[itemIndex] = updatedItem;
    
    state = {...state, normalizedDate: updatedItems};
    sw.stop();
    if (kDebugMode) developer.log('updateQuantityForDate took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
  }

  /// Copy all items from source day to target days
  void copyDayToOtherDays(DateTime sourceDay, List<DateTime> targetDays) {
    final sw = Stopwatch()..start();
    final normalizedSourceDay = _normalizeDate(sourceDay);
    final sourceItems = state[normalizedSourceDay];
    
    if (sourceItems == null || sourceItems.isEmpty) return;
    
    final newState = Map<DateTime, List<WeeklyCartItem>>.from(state);
    
    for (final targetDay in targetDays) {
      final normalizedTargetDay = _normalizeDate(targetDay);
      
      // Create new items with new IDs and target date
      final copiedItems = sourceItems.map((item) {
        return WeeklyCartItem(
          id: _uuid.v4(), // New ID for copied item
          menuItem: item.menuItem,
          date: normalizedTargetDay,
          quantity: item.quantity,
          addedAt: DateTime.now(),
        );
      }).toList();
      
      // Merge with existing items for target day
      final existingItems = newState[normalizedTargetDay] ?? [];
      final mergedItems = [...existingItems];
      
      // Add copied items, merging quantities if same menu item exists
      for (final copiedItem in copiedItems) {
        final existingIndex = mergedItems.indexWhere(
          (item) => item.menuItem.id == copiedItem.menuItem.id,
        );
        
        if (existingIndex >= 0) {
          // Merge quantities
          mergedItems[existingIndex] = mergedItems[existingIndex].copyWith(
            quantity: mergedItems[existingIndex].quantity + copiedItem.quantity,
          );
        } else {
          // Add new item
          mergedItems.add(copiedItem);
        }
      }
      
      newState[normalizedTargetDay] = mergedItems;
    }
    
  state = newState;
  _persist();
    sw.stop();
    if (kDebugMode) developer.log('copyDayToOtherDays copied to ${targetDays.length} days took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
  }

  /// Clear all items for a specific day
  void clearDay(DateTime date) {
    final sw = Stopwatch()..start();
    final normalizedDate = _normalizeDate(date);
    final newState = Map<DateTime, List<WeeklyCartItem>>.from(state);
    newState.remove(normalizedDate);
    state = newState;
    sw.stop();
    if (kDebugMode) developer.log('clearDay took: ${sw.elapsedMilliseconds}ms', name: 'WeeklyCart');
  }

  /// Clear entire week (all days)
  void clearWeek() {
  state = {};
  _persist();
  }

  /// Get all items for a specific date
  List<WeeklyCartItem> getItemsForDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    return state[normalizedDate] ?? [];
  }

  /// Check if there are any items for a specific date
  bool hasOrderForDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    return state.containsKey(normalizedDate) && state[normalizedDate]!.isNotEmpty;
  }

  /// Get list of dates that have orders
  List<DateTime> getDaysWithOrders() {
    return state.keys.toList()..sort();
  }

  /// Get total cost for a specific date
  double getTotalForDate(DateTime date) {
    final items = getItemsForDate(date);
    return items.fold(0.0, (sum, item) => sum + item.total);
  }

  /// Get total item count for a specific date
  int getItemCountForDate(DateTime date) {
    final items = getItemsForDate(date);
    return items.fold(0, (sum, item) => sum + item.quantity);
  }

  /// Get weekly total cost (all days)
  double getWeeklyTotal() {
    double total = 0.0;
    for (final items in state.values) {
      total += items.fold(0.0, (sum, item) => sum + item.total);
    }
    return total;
  }

  /// Get weekly total item count (all days)
  int getWeeklyItemCount() {
    int count = 0;
    for (final items in state.values) {
      count += items.fold(0, (sum, item) => sum + item.quantity);
    }
    return count;
  }

  /// Get category breakdown across all days
  /// Returns map of category -> total item count
  Map<String, int> getWeeklyCategoryBreakdown() {
    final breakdown = <String, int>{};
    
    for (final items in state.values) {
      for (final item in items) {
        final category = item.menuItem.category;
        breakdown[category] = (breakdown[category] ?? 0) + item.quantity;
      }
    }
    
    return breakdown;
  }

  /// Get comprehensive weekly summary
  WeeklySummary getWeeklySummary() {
    final dailyCosts = <DateTime, double>{};
    for (final date in state.keys) {
      dailyCosts[date] = getTotalForDate(date);
    }
    
    final daysWithOrders = state.keys.length;
    final totalCost = getWeeklyTotal();
    final averageCost = daysWithOrders > 0 ? totalCost / daysWithOrders : 0.0;
    
    return WeeklySummary(
      totalCost: totalCost,
      totalItems: getWeeklyItemCount(),
      categoryBreakdown: getWeeklyCategoryBreakdown(),
      dailyCosts: dailyCosts,
      daysWithOrders: daysWithOrders,
      averageCostPerDay: averageCost,
    );
  }
}

/// Main weekly cart provider
final weeklyCartProvider = StateNotifierProvider<WeeklyCartNotifier, Map<DateTime, List<WeeklyCartItem>>>(
  (ref) => WeeklyCartNotifier(ref),
);

/// Derived provider for weekly total
final weeklyCartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(weeklyCartProvider.notifier);
  return cart.getWeeklyTotal();
});

/// Derived provider for weekly item count
final weeklyCartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(weeklyCartProvider.notifier);
  return cart.getWeeklyItemCount();
});

/// Derived provider for weekly summary
final weeklyCartSummaryProvider = Provider<WeeklySummary>((ref) {
  final cart = ref.watch(weeklyCartProvider.notifier);
  // Watch the cart state to trigger updates, and also watch the global date provider
  // so UI that displays "today" related summaries will refresh after day changes.
  ref.watch(weeklyCartProvider);
  ref.watch(
    // import would be required; use a string to avoid static import ordering issues
    // but we can directly import date_refresh_provider in this file if needed. For clarity, import it.
    dateRefreshProvider,
  );
  return cart.getWeeklySummary();
});

/// Provider for items on a specific date
final weeklyCartItemsForDateProvider = Provider.family<List<WeeklyCartItem>, DateTime>((ref, date) {
  final cart = ref.watch(weeklyCartProvider.notifier);
  ref.watch(weeklyCartProvider); // Watch state to trigger updates
  return cart.getItemsForDate(date);
});

/// Provider to check if date has orders
final weeklyCartHasOrderForDateProvider = Provider.family<bool, DateTime>((ref, date) {
  final cart = ref.watch(weeklyCartProvider.notifier);
  ref.watch(weeklyCartProvider); // Watch state to trigger updates
  return cart.hasOrderForDate(date);
});
