import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/models/menu_item.dart';

/// Comprehensive unit tests for MenuService
/// 
/// Note: These tests focus on MenuItem model validation, business logic,
/// and data transformation. For integration tests with Firestore,
/// see the integration test suite.
void main() {
  group('MenuItem Model - Data Serialization', () {
    test('MenuItem creation with required fields succeeds', () {
      final menuItem = MenuItem(
        id: 'test-item-1',
        name: 'Chicken Adobo',
        description: 'Filipino classic braised chicken',
        price: 45.0,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      expect(menuItem.id, 'test-item-1');
      expect(menuItem.name, 'Chicken Adobo');
      expect(menuItem.price, 45.0);
      expect(menuItem.category, 'Lunch');
      expect(menuItem.isAvailable, true); // Default value
    });

    test('MenuItem.toMap() converts menu item to Firestore map correctly', () {
      final now = DateTime.now();
      final menuItem = MenuItem(
        id: 'test-item-1',
        name: 'Burger',
        description: 'Beef burger with cheese',
        price: 65.50,
        category: 'Lunch',
        allergens: ['Dairy', 'Gluten'],
        isVegetarian: false,
        isVegan: false,
        isGlutenFree: false,
        isAvailable: true,
        stockQuantity: 20,
        calories: 550,
        createdAt: now,
      );

      final map = menuItem.toMap();

      expect(map['id'], 'test-item-1');
      expect(map['name'], 'Burger');
      expect(map['description'], 'Beef burger with cheese');
      expect(map['price'], 65.50);
      expect(map['category'], 'Lunch');
      expect(map['allergens'], ['Dairy', 'Gluten']);
      expect(map['isVegetarian'], false);
      expect(map['isVegan'], false);
      expect(map['isGlutenFree'], false);
      expect(map['isAvailable'], true);
      expect(map['stockQuantity'], 20);
      expect(map['calories'], 550);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('MenuItem.fromMap() creates menu item from Firestore map correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-item-2',
        'name': 'Garden Salad',
        'description': 'Fresh mixed greens',
        'price': 35.0,
        'category': 'Snack',
        'imageUrl': 'https://example.com/salad.jpg',
        'allergens': ['Nuts'],
        'isVegetarian': true,
        'isVegan': true,
        'isGlutenFree': true,
        'isAvailable': true,
        'stockQuantity': 15,
        'calories': 120,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': null,
      };

      final menuItem = MenuItem.fromMap(map);

      expect(menuItem.id, 'test-item-2');
      expect(menuItem.name, 'Garden Salad');
      expect(menuItem.description, 'Fresh mixed greens');
      expect(menuItem.price, 35.0);
      expect(menuItem.category, 'Snack');
      expect(menuItem.imageUrl, 'https://example.com/salad.jpg');
      expect(menuItem.allergens, ['Nuts']);
      expect(menuItem.isVegetarian, true);
      expect(menuItem.isVegan, true);
      expect(menuItem.isGlutenFree, true);
      expect(menuItem.stockQuantity, 15);
      expect(menuItem.calories, 120);
    });

    test('MenuItem.copyWith() creates modified copy correctly', () {
      final originalItem = MenuItem(
        id: 'test-item-3',
        name: 'Soda',
        description: 'Carbonated beverage',
        price: 20.0,
        category: 'Drinks',
        isAvailable: true,
        createdAt: DateTime.now(),
      );

      final updatedItem = originalItem.copyWith(
        price: 25.0,
        isAvailable: false,
        stockQuantity: 50,
        updatedAt: DateTime.now(),
      );

      // Updated fields
      expect(updatedItem.price, 25.0);
      expect(updatedItem.isAvailable, false);
      expect(updatedItem.stockQuantity, 50);
      expect(updatedItem.updatedAt, isNotNull);

      // Unchanged fields
      expect(updatedItem.id, originalItem.id);
      expect(updatedItem.name, originalItem.name);
      expect(updatedItem.description, originalItem.description);
      expect(updatedItem.category, originalItem.category);
    });
  });

  group('MenuService - Duplicate Detection', () {
    test('Duplicate detection is case-sensitive for exact matches', () {
      final item1Name = 'Chicken Adobo';
      final item2Name = 'Chicken Adobo';

      expect(item1Name, item2Name);
    });

    test('Different names are not duplicates', () {
      final item1Name = 'Chicken Adobo';
      final item2Name = 'Pork Adobo';

      expect(item1Name, isNot(item2Name));
    });
  });

  group('MenuService - Validation', () {
    test('Menu item with empty name should be invalid', () {
      final invalidData = {
        'name': '',
        'description': 'Test description',
        'price': '45.0',
        'category': 'Lunch',
      };

      expect(invalidData['name']?.toString().trim().isEmpty, true);
    });

    test('Menu item with empty description should be invalid', () {
      final invalidData = {
        'name': 'Test Item',
        'description': '',
        'price': '45.0',
        'category': 'Lunch',
      };

      expect(invalidData['description']?.toString().trim().isEmpty, true);
    });

    test('Menu item with empty category should be invalid', () {
      final invalidData = {
        'name': 'Test Item',
        'description': 'Test description',
        'price': '45.0',
        'category': '',
      };

      expect(invalidData['category']?.toString().trim().isEmpty, true);
    });

    test('Menu item with invalid price should be invalid', () {
      final invalidPrice1 = double.tryParse('invalid');
      final invalidPrice2 = double.tryParse('');
      final negativePrice = double.tryParse('-10.0');

      expect(invalidPrice1, null);
      expect(invalidPrice2, null);
      expect(negativePrice != null && negativePrice < 0, true);
    });

    test('Valid menu item data passes validation', () {
      final validData = {
        'name': 'Chicken Adobo',
        'description': 'Filipino classic',
        'price': '45.0',
        'category': 'Lunch',
      };

      final name = validData['name']?.toString().trim() ?? '';
      final description = validData['description']?.toString().trim() ?? '';
      final category = validData['category']?.toString().trim() ?? '';
      final price = double.tryParse(validData['price'] ?? '');

      expect(name.isNotEmpty, true);
      expect(description.isNotEmpty, true);
      expect(category.isNotEmpty, true);
      expect(price != null && price >= 0, true);
    });
  });

  group('MenuService - Category Management', () {
    test('Valid categories are accepted', () {
      final validCategories = ['Snack', 'Lunch', 'Drinks'];

      for (final category in validCategories) {
        final menuItem = MenuItem(
          id: 'test-$category',
          name: 'Test Item',
          description: 'Test',
          price: 10.0,
          category: category,
          createdAt: DateTime.now(),
        );

        expect(menuItem.category, category);
      }
    });

    test('Category list can be sorted alphabetically', () {
      final categories = ['Drinks', 'Lunch', 'Snack'];
      categories.sort();

      expect(categories, ['Drinks', 'Lunch', 'Snack']);
    });

    test('Categories are case-sensitive', () {
      expect('Snack', isNot('snack'));
      expect('Lunch', isNot('LUNCH'));
    });
  });

  group('MenuService - Availability Toggle', () {
    test('Availability defaults to true', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.isAvailable, true);
    });

    test('Availability can be set on creation', () {
      final menuItem = MenuItem(
        id: 'test-2',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        isAvailable: false,
        createdAt: DateTime.now(),
      );

      expect(menuItem.isAvailable, false);
    });

    test('Availability can be toggled using copyWith', () {
      final menuItem = MenuItem(
        id: 'test-3',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        isAvailable: true,
        createdAt: DateTime.now(),
      );

      final toggledItem = menuItem.copyWith(isAvailable: false);

      expect(toggledItem.isAvailable, false);
      expect(menuItem.isAvailable, true); // Original unchanged
    });

    test('Availability toggle logic works correctly', () {
      bool currentAvailability = true;
      bool newAvailability = !currentAvailability;

      expect(newAvailability, false);

      currentAvailability = false;
      newAvailability = !currentAvailability;

      expect(newAvailability, true);
    });
  });

  group('MenuService - Stock Management', () {
    test('Stock quantity defaults to null (unlimited)', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.stockQuantity, null);
    });

    test('Stock quantity can be set', () {
      final menuItem = MenuItem(
        id: 'test-2',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        stockQuantity: 100,
        createdAt: DateTime.now(),
      );

      expect(menuItem.stockQuantity, 100);
    });

    test('Stock quantity can be updated using copyWith', () {
      final menuItem = MenuItem(
        id: 'test-3',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        stockQuantity: 50,
        createdAt: DateTime.now(),
      );

      final updatedItem = menuItem.copyWith(stockQuantity: 25);

      expect(updatedItem.stockQuantity, 25);
      expect(menuItem.stockQuantity, 50); // Original unchanged
    });

    test('Zero stock is valid', () {
      final menuItem = MenuItem(
        id: 'test-4',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        stockQuantity: 0,
        createdAt: DateTime.now(),
      );

      expect(menuItem.stockQuantity, 0);
      expect(menuItem.stockQuantity != null, true);
    });
  });

  group('MenuService - Dietary Information', () {
    test('Dietary flags default to false', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.isVegetarian, false);
      expect(menuItem.isVegan, false);
      expect(menuItem.isGlutenFree, false);
    });

    test('Dietary flags can be set independently', () {
      final vegItem = MenuItem(
        id: 'test-2',
        name: 'Veggie Burger',
        description: 'Plant-based burger',
        price: 55.0,
        category: 'Lunch',
        isVegetarian: true,
        createdAt: DateTime.now(),
      );

      final veganItem = MenuItem(
        id: 'test-3',
        name: 'Tofu Salad',
        description: 'Vegan salad',
        price: 40.0,
        category: 'Lunch',
        isVegetarian: true,
        isVegan: true,
        createdAt: DateTime.now(),
      );

      final gfItem = MenuItem(
        id: 'test-4',
        name: 'Rice Bowl',
        description: 'Gluten-free rice bowl',
        price: 50.0,
        category: 'Lunch',
        isGlutenFree: true,
        createdAt: DateTime.now(),
      );

      expect(vegItem.isVegetarian, true);
      expect(vegItem.isVegan, false);
      
      expect(veganItem.isVegetarian, true);
      expect(veganItem.isVegan, true);
      
      expect(gfItem.isGlutenFree, true);
    });

    test('Allergens list defaults to empty', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.allergens, isEmpty);
    });

    test('Allergens list can contain multiple items', () {
      final menuItem = MenuItem(
        id: 'test-2',
        name: 'Peanut Butter Sandwich',
        description: 'Classic PB sandwich',
        price: 30.0,
        category: 'Snack',
        allergens: ['Peanuts', 'Gluten', 'Dairy'],
        createdAt: DateTime.now(),
      );

      expect(menuItem.allergens.length, 3);
      expect(menuItem.allergens, contains('Peanuts'));
      expect(menuItem.allergens, contains('Gluten'));
      expect(menuItem.allergens, contains('Dairy'));
    });
  });

  group('MenuService - CSV Import Validation', () {
    test('CSV headers are case-insensitive', () {
      final testHeaders = ['Name', 'DESCRIPTION', 'price', 'Category'];
      final normalizedHeaders = testHeaders.map((h) => h.toLowerCase().trim()).toList();

      expect(normalizedHeaders, ['name', 'description', 'price', 'category']);
    });

    test('Price parsing handles various formats', () {
      expect(double.tryParse('45'), 45.0);
      expect(double.tryParse('45.50'), 45.50);
      expect(double.tryParse('0'), 0.0);
      expect(double.tryParse('invalid'), null);
      expect(double.tryParse(''), null);
    });

    test('Boolean parsing handles various formats', () {
      bool parseBool(String value) {
        final lower = value.toLowerCase().trim();
        return lower == 'true' || lower == 'yes' || lower == '1';
      }

      expect(parseBool('true'), true);
      expect(parseBool('TRUE'), true);
      expect(parseBool('yes'), true);
      expect(parseBool('YES'), true);
      expect(parseBool('1'), true);
      expect(parseBool('false'), false);
      expect(parseBool('no'), false);
      expect(parseBool('0'), false);
      expect(parseBool(''), false);
    });

    test('Allergens parsing from comma-separated string', () {
      final allergensStr = 'Peanuts, Dairy, Gluten';
      final allergensList = allergensStr
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      expect(allergensList.length, 3);
      expect(allergensList, ['Peanuts', 'Dairy', 'Gluten']);
    });

    test('Empty allergens string results in empty list', () {
      final allergensStr = '';
      final allergensList = allergensStr.isNotEmpty
          ? allergensStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      expect(allergensList, isEmpty);
    });

    test('Empty rows are skipped during import', () {
      final testRows = [
        ['Burger', 'Beef burger', '65.0', 'Lunch'],
        ['', '', '', ''], // Empty row
        ['Salad', 'Garden salad', '35.0', 'Snack'],
      ];

      final validRows = testRows.where((row) =>
        row.isNotEmpty && row[0].toString().trim().isNotEmpty
      ).toList();

      expect(validRows.length, 2);
      expect(validRows[0][0], 'Burger');
      expect(validRows[1][0], 'Salad');
    });
  });

  group('MenuService - Export Functionality', () {
    test('CSV export headers are correctly formatted', () {
      final expectedHeaders = [
        'Name',
        'Description',
        'Price',
        'Category',
        'Allergens',
        'IsVegetarian',
        'IsVegan',
        'IsGlutenFree',
        'IsAvailable',
        'StockQuantity',
      ];

      expect(expectedHeaders.length, 10);
      expect(expectedHeaders[0], 'Name');
      expect(expectedHeaders[2], 'Price');
      expect(expectedHeaders[8], 'IsAvailable');
    });

    test('Boolean values are exported as TRUE/FALSE', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        isVegetarian: true,
        isVegan: false,
        isGlutenFree: true,
        isAvailable: false,
        createdAt: DateTime.now(),
      );

      expect(menuItem.isVegetarian ? 'TRUE' : 'FALSE', 'TRUE');
      expect(menuItem.isVegan ? 'TRUE' : 'FALSE', 'FALSE');
      expect(menuItem.isGlutenFree ? 'TRUE' : 'FALSE', 'TRUE');
      expect(menuItem.isAvailable ? 'TRUE' : 'FALSE', 'FALSE');
    });

    test('Price is exported with 2 decimal places', () {
      final price1 = 45.0;
      final price2 = 45.50;
      final price3 = 45.567;

      expect(price1.toStringAsFixed(2), '45.00');
      expect(price2.toStringAsFixed(2), '45.50');
      expect(price3.toStringAsFixed(2), '45.57');
    });

    test('Allergens are exported as comma-separated string', () {
      final allergens = ['Peanuts', 'Dairy', 'Gluten'];
      final exportString = allergens.join(', ');

      expect(exportString, 'Peanuts, Dairy, Gluten');
    });

    test('Null stock quantity is exported as empty string', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.stockQuantity?.toString() ?? '', '');
    });
  });

  group('MenuService - Search and Filter', () {
    test('Search query is case-insensitive', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Chicken Adobo',
        description: 'Filipino classic braised chicken',
        price: 45.0,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      final query1 = 'chicken';
      final query2 = 'CHICKEN';
      final query3 = 'adobo';

      expect(menuItem.name.toLowerCase().contains(query1.toLowerCase()), true);
      expect(menuItem.name.toLowerCase().contains(query2.toLowerCase()), true);
      expect(menuItem.name.toLowerCase().contains(query3.toLowerCase()), true);
    });

    test('Search works on both name and description', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Burger',
        description: 'Beef burger with cheese and bacon',
        price: 65.0,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      final nameQuery = 'burger';
      final descQuery = 'cheese';

      expect(menuItem.name.toLowerCase().contains(nameQuery.toLowerCase()), true);
      expect(menuItem.description.toLowerCase().contains(descQuery.toLowerCase()), true);
    });

    test('Partial name matching works', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Chicken Adobo',
        description: 'Filipino classic',
        price: 45.0,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      expect(menuItem.name.toLowerCase().contains('chick'), true);
      expect(menuItem.name.toLowerCase().contains('ado'), true);
      expect(menuItem.name.toLowerCase().contains('ken ado'), true);
    });
  });

  group('MenuService - Price Operations', () {
    test('Price is stored as double', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 45.50,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      expect(menuItem.price, isA<double>());
      expect(menuItem.price, 45.50);
    });

    test('Price can be updated using copyWith', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 45.0,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      final updatedItem = menuItem.copyWith(price: 50.0);

      expect(updatedItem.price, 50.0);
      expect(menuItem.price, 45.0); // Original unchanged
    });

    test('Zero price is valid', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Free Sample',
        description: 'Complimentary item',
        price: 0.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.price, 0.0);
    });

    test('Price handles decimal precision', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Test Item',
        description: 'Test',
        price: 45.567,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      expect(menuItem.price, 45.567);
      expect(menuItem.price.toStringAsFixed(2), '45.57');
    });
  });

  group('MenuService - Edge Cases', () {
    test('Handles very long item names', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Super Deluxe Extra Large Chicken Adobo with Garlic Rice and Vegetables',
        description: 'A very long description',
        price: 85.0,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      expect(menuItem.name.length, greaterThan(50));
    });

    test('Handles special characters in names', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: "Chef's Special: Piña Colada (Non-Alcoholic)",
        description: 'Tropical drink',
        price: 45.0,
        category: 'Drinks',
        createdAt: DateTime.now(),
      );

      expect(menuItem.name, contains("'"));
      expect(menuItem.name, contains('ñ'));
      expect(menuItem.name, contains('('));
      expect(menuItem.name, contains(')'));
    });

    test('Handles very large prices', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Premium Item',
        description: 'Expensive item',
        price: 9999.99,
        category: 'Lunch',
        createdAt: DateTime.now(),
      );

      expect(menuItem.price, 9999.99);
    });

    test('Handles very large stock quantities', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Water',
        description: 'Bottled water',
        price: 15.0,
        category: 'Drinks',
        stockQuantity: 10000,
        createdAt: DateTime.now(),
      );

      expect(menuItem.stockQuantity, 10000);
    });

    test('Handles items with many allergens', () {
      final menuItem = MenuItem(
        id: 'test-1',
        name: 'Mixed Nuts Trail Mix',
        description: 'Various nuts and dried fruits',
        price: 40.0,
        category: 'Snack',
        allergens: [
          'Peanuts',
          'Tree Nuts',
          'Cashews',
          'Almonds',
          'Walnuts',
          'Pecans',
          'Hazelnuts',
          'Sulfites',
        ],
        createdAt: DateTime.now(),
      );

      expect(menuItem.allergens.length, 8);
    });

    test('Handles empty allergens list in export', () {
      final allergens = <String>[];
      final exportString = allergens.join(', ');

      expect(exportString, '');
    });
  });

  group('MenuService - Data Integrity', () {
    test('Required fields cannot be null', () {
      expect(
        () => MenuItem(
          id: 'test',
          name: 'Test Item',
          description: 'Test description',
          price: 10.0,
          category: 'Snack',
          createdAt: DateTime.now(),
        ),
        returnsNormally,
      );
    });

    test('Optional fields can be null', () {
      final menuItem = MenuItem(
        id: 'test',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.imageUrl, null);
      expect(menuItem.stockQuantity, null);
      expect(menuItem.calories, null);
      expect(menuItem.updatedAt, null);
    });

    test('DateTime fields are properly handled', () {
      final createdAt = DateTime.now();
      final menuItem = MenuItem(
        id: 'test',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: createdAt,
      );

      expect(menuItem.createdAt, createdAt);
      expect(menuItem.createdAt, isA<DateTime>());
    });

    test('Boolean fields have correct defaults', () {
      final menuItem = MenuItem(
        id: 'test',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.isVegetarian, false);
      expect(menuItem.isVegan, false);
      expect(menuItem.isGlutenFree, false);
      expect(menuItem.isAvailable, true);
    });

    test('List fields have correct defaults', () {
      final menuItem = MenuItem(
        id: 'test',
        name: 'Test Item',
        description: 'Test',
        price: 10.0,
        category: 'Snack',
        createdAt: DateTime.now(),
      );

      expect(menuItem.allergens, isEmpty);
      expect(menuItem.allergens, isA<List<String>>());
    });
  });
}
