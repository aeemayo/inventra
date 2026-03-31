import * as admin from "firebase-admin";
import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import {onDocumentWritten, FirestoreEvent, Change, DocumentSnapshot} from "firebase-functions/v2/firestore";
import {onSchedule, ScheduledEvent} from "firebase-functions/v2/scheduler";

admin.initializeApp();
const db = admin.firestore();

/**
 * Validate and execute stock deduction atomically.
 * Prevents overselling via Firestore transaction.
 */
export const validateStockDeduction = onCall(async (request: CallableRequest<any>) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be authenticated");
  }

  const {shopId, items, paymentMethod, discount, note} = request.data;

  if (!shopId || !items || !Array.isArray(items) || items.length === 0) {
    throw new HttpsError("invalid-argument", "Missing required fields");
  }

  const uid = request.auth.uid;
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists || userDoc.data()?.shopId !== shopId) {
    throw new HttpsError("permission-denied", "Not authorized for this shop");
  }

  const userName = userDoc.data()?.displayName || "Unknown";

  try {
    const result = await db.runTransaction(async (transaction: admin.firestore.Transaction) => {
      let subtotal = 0;
      const productUpdates: {ref: admin.firestore.DocumentReference; newQty: number; product: any; qty: number}[] = [];

      // Phase 1: Read all products and validate stock
      for (const item of items) {
        const productRef = db.doc(`shops/${shopId}/products/${item.productId}`);
        const productDoc = await transaction.get(productRef);

        if (!productDoc.exists) {
          throw new HttpsError("not-found", `Product ${item.productId} not found`);
        }

        const product = productDoc.data()!;
        const currentQty = product.quantity as number;

        if (currentQty < item.quantity) {
          throw new HttpsError(
            "failed-precondition",
            `Insufficient stock for ${product.name}. Available: ${currentQty}, Requested: ${item.quantity}`
          );
        }

        const itemTotal = (product.sellingPrice as number) * item.quantity;
        subtotal += itemTotal;

        productUpdates.push({
          ref: productRef,
          newQty: currentQty - item.quantity,
          product,
          qty: item.quantity,
        });
      }

      // Calculate totals
      const discountAmount = discount || 0;
      const total = subtotal - discountAmount;

      // Phase 2: Write all updates
      const transactionRef = db.collection(`shops/${shopId}/transactions`).doc();

      // Create transaction record
      const transactionData = {
        type: "sale",
        items: productUpdates.map((u) => ({
          productId: u.ref.id,
          productName: u.product.name,
          sku: u.product.sku,
          quantity: u.qty,
          unitPrice: u.product.sellingPrice,
          totalPrice: u.product.sellingPrice * u.qty,
        })),
        subtotal,
        discount: discountAmount,
        taxAmount: 0,
        total,
        paymentMethod: paymentMethod || "cash",
        status: "completed",
        note: note || null,
        createdBy: uid,
        createdByName: userName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      transaction.set(transactionRef, transactionData);

      // Update each product and create stock movement
      for (const update of productUpdates) {
        transaction.update(update.ref, {
          quantity: update.newQty,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const movementRef = db.collection(`shops/${shopId}/stock_movements`).doc();
        transaction.set(movementRef, {
          productId: update.ref.id,
          productName: update.product.name,
          type: "sale",
          quantityChange: -update.qty,
          quantityBefore: update.product.quantity,
          quantityAfter: update.newQty,
          reference: transactionRef.id,
          userId: uid,
          userName: userName,
          source: "pos",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return {transactionId: transactionRef.id, total};
    });

    return result;
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Transaction failed");
  }
});

/**
 * Check low stock on product write and create notification.
 */
export const checkLowStock = onDocumentWritten(
  "shops/{shopId}/products/{productId}",
  async (event: FirestoreEvent<Change<DocumentSnapshot> | undefined, {shopId: string; productId: string}>) => {
    const after = event.data?.after?.data();
    if (!after) return;

    const shopId = event.params.shopId;
    const quantity = after.quantity as number;
    const reorderLevel = after.reorderLevel as number;
    const productName = after.name as string;

    if (quantity <= reorderLevel && quantity > 0) {
      await db.collection(`shops/${shopId}/notifications`).add({
        type: "low_stock",
        title: "Low Stock Alert",
        body: `${productName} is running low (${quantity} remaining)`,
        data: {productId: event.params.productId},
        read: false,
        userId: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (quantity <= 0) {
      await db.collection(`shops/${shopId}/notifications`).add({
        type: "low_stock",
        title: "Out of Stock!",
        body: `${productName} is completely out of stock`,
        data: {productId: event.params.productId},
        read: false,
        userId: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * Daily analytics aggregation (runs at midnight UTC).
 */
export const aggregateDailySales = onSchedule(
  {schedule: "every day 00:00", timeZone: "UTC"},
  async (_event: ScheduledEvent) => {
  const shopsSnapshot = await db.collection("shops").get();

  for (const shopDoc of shopsSnapshot.docs) {
    const shopId = shopDoc.id;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const transactionsSnapshot = await db
      .collection(`shops/${shopId}/transactions`)
      .where("createdAt", ">=", today)
      .where("createdAt", "<", tomorrow)
      .where("status", "==", "completed")
      .get();

    let totalSales = 0;
    let totalRevenue = 0;
    const productSales: Record<string, {name: string; qty: number; revenue: number}> = {};

    for (const txDoc of transactionsSnapshot.docs) {
      const tx = txDoc.data();
      totalSales++;
      totalRevenue += tx.total;

      for (const item of tx.items || []) {
        if (!productSales[item.productId]) {
          productSales[item.productId] = {name: item.productName, qty: 0, revenue: 0};
        }
        productSales[item.productId].qty += item.quantity;
        productSales[item.productId].revenue += item.totalPrice;
      }
    }

    const topProducts = Object.entries(productSales)
      .sort(([, a], [, b]) => b.revenue - a.revenue)
      .slice(0, 10)
      .map(([id, data]) => ({productId: id, ...data}));

    // Get low stock count
    const lowStockSnapshot = await db
      .collection(`shops/${shopId}/products`)
      .where("isActive", "==", true)
      .get();

    let lowStockCount = 0;
    let inventoryValue = 0;
    for (const pDoc of lowStockSnapshot.docs) {
      const p = pDoc.data();
      if (p.quantity <= p.reorderLevel) lowStockCount++;
      inventoryValue += (p.costPrice || 0) * (p.quantity || 0);
    }

    const dateKey = today.toISOString().split("T")[0];
    await db.doc(`shops/${shopId}/analytics_snapshots/${dateKey}`).set({
      date: today,
      totalSales,
      totalRevenue,
      totalTransactions: totalSales,
      topProducts,
      inventoryValue,
      lowStockCount,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
});
