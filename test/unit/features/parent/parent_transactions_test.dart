import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:canteen_app/core/services/parent_service.dart';
import 'package:canteen_app/core/services/user_service.dart';
import 'package:canteen_app/core/constants/firestore_constants.dart';

void main() {
  group('Parent transaction + balance deduction', () {
    test('Single order: parent balance is decremented and transaction recorded', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final parentId = 'parent-1';

      // Create parent doc with initial balance
      await fakeFirestore.collection(FirestoreConstants.parentsCollection).doc(parentId).set({
        'id': parentId,
        FirestoreConstants.balance: 1000.0,
        FirestoreConstants.createdAt: DateTime.now(),
        FirestoreConstants.updatedAt: DateTime.now(),
      });

      final parentService = ParentService(
        firestore: fakeFirestore,
        userService: UserService(firestore: fakeFirestore),
      );

      final orderId = 'order-1';
      final amount = 120.0;

      // Run a transaction similar to the app's flow
      await fakeFirestore.runTransaction((tx) async {
        // read parent first (Firestore requires reads before writes in a transaction)
        final parentRef = fakeFirestore.collection(FirestoreConstants.parentsCollection).doc(parentId);
        final parentSnap = await tx.get(parentRef);
        final currentBalance = (parentSnap.get(FirestoreConstants.balance) as num).toDouble();
        expect(currentBalance, 1000.0);

        // create order doc
        final orderRef = fakeFirestore.collection(FirestoreConstants.ordersCollection).doc(orderId);

        // compute new balance and then perform writes
        final newBalance = currentBalance - amount;

        tx.set(orderRef, {
          'id': orderId,
          'totalAmount': amount,
        });

        tx.update(parentRef, {
          FirestoreConstants.balance: newBalance,
          FirestoreConstants.updatedAt: DateTime.now(),
        });

        // record transaction via ParentService helper
        await parentService.recordTransactionInTx(
          tx: tx,
          parentId: parentId,
          amount: amount,
          balanceBefore: currentBalance,
          balanceAfter: newBalance,
          orderIds: [orderId],
          reason: 'single_order',
        );
      });

      // Verify parent doc updated
      final parentDoc = await fakeFirestore.collection(FirestoreConstants.parentsCollection).doc(parentId).get();
      expect(parentDoc.exists, true);
      expect((parentDoc.data()![FirestoreConstants.balance] as num).toDouble(), 1000.0 - amount);

      // Verify transaction doc exists
      final txSnapshot = await fakeFirestore.collection('parent_transactions').get();
      expect(txSnapshot.docs.length, 1);
      final txDoc = txSnapshot.docs.first.data();
      expect(txDoc['parentId'], parentId);
      expect((txDoc['amount'] as num).toDouble(), amount);
      expect(txDoc['orderIds'], [orderId]);
      expect(txDoc['reason'], 'single_order');
    });

    test('Weekly orders: combined deduction and transaction recorded; student docs untouched', () async {
      final fakeFirestore = FakeFirebaseFirestore();
      final parentId = 'parent-2';

      // Parent doc
      await fakeFirestore.collection(FirestoreConstants.parentsCollection).doc(parentId).set({
        'id': parentId,
        FirestoreConstants.balance: 2000.0,
        FirestoreConstants.createdAt: DateTime.now(),
        FirestoreConstants.updatedAt: DateTime.now(),
      });

      // Create two student docs (should remain unchanged)
      final student1 = 'student-a';
      final student2 = 'student-b';
      await fakeFirestore.collection(FirestoreConstants.studentsCollection).doc(student1).set({
        'id': student1,
        'balance': 50.0,
      });
      await fakeFirestore.collection(FirestoreConstants.studentsCollection).doc(student2).set({
        'id': student2,
        'balance': 75.0,
      });

      final parentService = ParentService(
        firestore: fakeFirestore,
        userService: UserService(firestore: fakeFirestore),
      );

      final orderId1 = 'order-a';
      final orderId2 = 'order-b';
      final total1 = 150.0;
      final total2 = 200.0;
      final combined = total1 + total2;

      // Run transaction: read parent first, then create two orders, deduct combined total, record_tx
      await fakeFirestore.runTransaction((tx) async {
        final parentRef = fakeFirestore.collection(FirestoreConstants.parentsCollection).doc(parentId);
        final parentSnap = await tx.get(parentRef);
        final currentBalance = (parentSnap.get(FirestoreConstants.balance) as num).toDouble();
        expect(currentBalance, 2000.0);

        final orderRef1 = fakeFirestore.collection(FirestoreConstants.ordersCollection).doc(orderId1);
        final orderRef2 = fakeFirestore.collection(FirestoreConstants.ordersCollection).doc(orderId2);

        final newBalance = currentBalance - combined;

        tx.set(orderRef1, {'id': orderId1, 'studentId': student1, 'totalAmount': total1});
        tx.set(orderRef2, {'id': orderId2, 'studentId': student2, 'totalAmount': total2});

        tx.update(parentRef, {
          FirestoreConstants.balance: newBalance,
          FirestoreConstants.updatedAt: DateTime.now(),
        });

        await parentService.recordTransactionInTx(
          tx: tx,
          parentId: parentId,
          amount: combined,
          balanceBefore: currentBalance,
          balanceAfter: newBalance,
          orderIds: [orderId1, orderId2],
          reason: 'weekly_order',
        );
      });

      // Verify parent new balance
      final parentDoc = await fakeFirestore.collection(FirestoreConstants.parentsCollection).doc(parentId).get();
      expect((parentDoc.data()![FirestoreConstants.balance] as num).toDouble(), 2000.0 - combined);

      // Verify transaction recorded
      final txSnapshot = await fakeFirestore.collection('parent_transactions').get();
      expect(txSnapshot.docs.length, 1);
      final txData = txSnapshot.docs.first.data();
      expect(txData['parentId'], parentId);
      expect((txData['amount'] as num).toDouble(), combined);
      expect(txData['orderIds'], [orderId1, orderId2]);

      // Verify student docs unchanged
      final s1 = await fakeFirestore.collection(FirestoreConstants.studentsCollection).doc(student1).get();
      final s2 = await fakeFirestore.collection(FirestoreConstants.studentsCollection).doc(student2).get();
      expect((s1.data()!['balance'] as num).toDouble(), 50.0);
      expect((s2.data()!['balance'] as num).toDouble(), 75.0);
    });
  });
}
