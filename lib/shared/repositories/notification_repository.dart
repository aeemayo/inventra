import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/notification_model.dart';

/// Repository for app notifications (low stock alerts, expiry warnings, etc.)
class NotificationRepository {
  final FirebaseFirestore _firestore;

  NotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Watch all notifications for a shop, newest first
  Stream<List<AppNotification>> watchNotifications(String shopId) {
    return _firestore
        .collection(FirestorePaths.notifications(shopId))
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc).toEntity())
            .toList());
  }

  /// Watch unread notifications only
  Stream<List<AppNotification>> watchUnreadNotifications(String shopId) {
    return _firestore
        .collection(FirestorePaths.notifications(shopId))
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromFirestore(doc).toEntity())
            .toList());
  }

  /// Get unread notification count
  Stream<int> watchUnreadCount(String shopId) {
    return watchUnreadNotifications(shopId)
        .map((notifications) => notifications.length);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String shopId, String notificationId) async {
    await _firestore
        .collection(FirestorePaths.notifications(shopId))
        .doc(notificationId)
        .update({'read': true});
  }

  /// Mark all notifications as read for a shop
  Future<void> markAllAsRead(String shopId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.notifications(shopId))
        .where('read', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// Delete a notification (admin only, enforced by rules)
  Future<void> deleteNotification(String shopId, String notificationId) async {
    await _firestore
        .collection(FirestorePaths.notifications(shopId))
        .doc(notificationId)
        .delete();
  }

  /// Create a notification (for client-side creation, e.g. manual alerts)
  Future<void> createNotification(
      String shopId, AppNotification notification) async {
    final model = NotificationModel.fromEntity(notification);
    await _firestore
        .collection(FirestorePaths.notifications(shopId))
        .add(model.toFirestore());
  }
}
