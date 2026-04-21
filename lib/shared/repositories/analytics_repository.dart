import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/analytics_snapshot_model.dart';

/// Repository for reading daily analytics snapshots (written by Cloud Functions)
class AnalyticsRepository {
  final FirebaseFirestore _firestore;

  AnalyticsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get a single analytics snapshot for a specific date
  Future<AnalyticsSnapshot?> getSnapshot(String shopId, String dateKey) async {
    final doc = await _firestore
        .collection(FirestorePaths.analyticsSnapshots(shopId))
        .doc(dateKey)
        .get();
    if (!doc.exists) return null;
    return AnalyticsSnapshotModel.fromFirestore(doc).toEntity();
  }

  /// Get analytics snapshots for a date range (for charts)
  Future<List<AnalyticsSnapshot>> getSnapshotsByDateRange(
    String shopId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.analyticsSnapshots(shopId))
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => AnalyticsSnapshotModel.fromFirestore(doc).toEntity())
        .toList();
  }

  /// Watch today's analytics snapshot for real-time dashboard
  Stream<AnalyticsSnapshot?> watchTodaySnapshot(String shopId) {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return _firestore
        .collection(FirestorePaths.analyticsSnapshots(shopId))
        .doc(dateKey)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return AnalyticsSnapshotModel.fromFirestore(doc).toEntity();
    });
  }

  /// Get the most recent N snapshots (for trend charts)
  Future<List<AnalyticsSnapshot>> getRecentSnapshots(
      String shopId, {int limit = 30}) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.analyticsSnapshots(shopId))
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AnalyticsSnapshotModel.fromFirestore(doc).toEntity())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date)); // Return in chronological order
  }
}
