import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:canteen_app/core/models/user_role.dart';
import 'package:canteen_app/core/services/user_service.dart';

void main() {
  group('AppUser.fromMap parsing', () {
    test('parses new boolean flags correctly', () {
      final now = DateTime.now();
      final map = {
        'uid': 'u1',
        'firstName': 'Alice',
        'lastName': 'Admin',
        'email': 'alice@example.com',
        'isAdmin': true,
        'isParent': false,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
      };

      final user = AppUser.fromMap(map);

      expect(user.uid, 'u1');
      expect(user.firstName, 'Alice');
      expect(user.lastName, 'Admin');
      expect(user.email, 'alice@example.com');
      expect(user.isAdmin, isTrue);
      expect(user.isParent, isFalse);
      expect(user.createdAt.isAtSameMomentAs(now), isTrue);
    });

    test('parses legacy role string (admin)', () {
      final now = DateTime.now();
      final map = {
        'uid': 'u2',
        'firstName': 'Bob',
        'lastName': 'Legacy',
        'email': 'bob@example.com',
        'role': 'admin',
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
      };

      final user = AppUser.fromMap(map);

      expect(user.uid, 'u2');
      expect(user.isAdmin, isTrue);
      expect(user.isParent, isFalse);
    });

    test('defaults to parent when no role info present', () {
      final now = DateTime.now();
      final map = {
        'uid': 'u3',
        'firstName': 'Cara',
        'lastName': 'Default',
        'email': 'cara@example.com',
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
      };

      final user = AppUser.fromMap(map);

      expect(user.isAdmin, isFalse);
      expect(user.isParent, isTrue);
    });
  });

  group('UserService.getUserRole', () {
    test('returns admin when isAdmin is true', () async {
      final fake = FakeFirebaseFirestore();
      final userDoc = {
        'uid': 'ux1',
        'firstName': 'Admin',
        'lastName': 'One',
        'email': 'admin1@example.com',
        'isAdmin': true,
        'isParent': false,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };
      await fake.collection('users').doc('ux1').set(userDoc);

      final svc = UserService(firestore: fake);
      final role = await svc.getUserRole('ux1');
      expect(role, UserRole.admin);
    });

    test('returns parent when isParent is true', () async {
      final fake = FakeFirebaseFirestore();
      final userDoc = {
        'uid': 'ux2',
        'firstName': 'Parent',
        'lastName': 'One',
        'email': 'parent1@example.com',
        'isAdmin': false,
        'isParent': true,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };
      await fake.collection('users').doc('ux2').set(userDoc);

      final svc = UserService(firestore: fake);
      final role = await svc.getUserRole('ux2');
      expect(role, UserRole.parent);
    });
  });
}
