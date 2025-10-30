"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.placeWeeklyOrder = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
/**
 * Callable function to place weekly orders on behalf of the parent (server-side).
 * Payload:
 * {
 *  weeklyCart: WeeklyCartPayload,
 *  selectedStudents: [{ id, fullName }]
 * }
 */
exports.placeWeeklyOrder = functions.https.onCall(async (data, context) => {
    // Authentication check
    if (!context.auth || !context.auth.uid) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const parentId = context.auth.uid;
    // Basic payload validation
    const weeklyCart = data?.weeklyCart;
    const selectedStudents = data?.selectedStudents;
    if (!weeklyCart || !Array.isArray(weeklyCart.datesWithOrders) || !selectedStudents || !Array.isArray(selectedStudents) || selectedStudents.length === 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid payload. weeklyCart and selectedStudents required');
    }
    // compute combined total server-side
    const totalPerStudent = Number(weeklyCart.totalPerStudent || 0);
    if (totalPerStudent <= 0) {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid totalPerStudent');
    }
    const combinedTotal = totalPerStudent * selectedStudents.length;
    // Run admin transaction
    try {
        const createdOrderIds = [];
        await db.runTransaction(async (tx) => {
            const parentRef = db.collection('parents').doc(parentId);
            const parentSnap = await tx.get(parentRef);
            if (!parentSnap.exists) {
                throw new functions.https.HttpsError('failed-precondition', 'Parent profile not found');
            }
            const currentBalance = Number(parentSnap.data()?.balance ?? 0);
            if (currentBalance < combinedTotal) {
                throw new functions.https.HttpsError('failed-precondition', 'Insufficient parent wallet balance');
            }
            // Create orders for each selected student
            for (const student of selectedStudents) {
                const orderId = db.collection('orders').doc().id;
                const items = weeklyCart.itemsByDate; // map date -> items
                // flatten items into array
                const flatItems = [];
                for (const date of weeklyCart.datesWithOrders) {
                    const list = items[date] || [];
                    for (const it of list)
                        flatItems.push(it);
                }
                const orderPayload = {
                    id: orderId,
                    parentId: parentId,
                    studentId: student.id,
                    studentName: student.fullName,
                    items: flatItems.map((it) => ({
                        menuItemId: it.menuItemId,
                        menuItemName: it.menuItemName,
                        price: it.price,
                        quantity: it.quantity,
                    })),
                    totalAmount: totalPerStudent,
                    status: 'pending',
                    orderDate: admin.firestore.Timestamp.now(),
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                const orderRef = db.collection('orders').doc(orderId);
                tx.set(orderRef, orderPayload);
                createdOrderIds.push(orderId);
            }
            // Deduct parent balance and update updatedAt
            const newBalance = currentBalance - combinedTotal;
            tx.update(parentRef, {
                balance: newBalance,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            // Record parent transaction
            const txRef = db.collection('parent_transactions').doc();
            tx.set(txRef, {
                parentId: parentId,
                amount: combinedTotal,
                balanceBefore: currentBalance,
                balanceAfter: newBalance,
                orderIds: createdOrderIds,
                reason: 'weekly_order',
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        });
        return { success: true, createdOrderIds };
    }
    catch (err) {
        // If it's an HttpsError, rethrow; otherwise wrap
        if (err instanceof functions.https.HttpsError)
            throw err;
        console.error('placeWeeklyOrder error', err);
        throw new functions.https.HttpsError('internal', err?.message || 'Internal error');
    }
});
//# sourceMappingURL=index.js.map