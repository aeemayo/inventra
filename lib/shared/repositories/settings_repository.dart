import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firestore_paths.dart';
import '../models/shop_settings_model.dart';

/// Repository for shop settings (single document per shop)
class SettingsRepository {
  final FirebaseFirestore _firestore;

  SettingsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get current shop settings
  Future<ShopSettings> getSettings(String shopId) async {
    final doc = await _firestore
        .doc(FirestorePaths.shopSettings(shopId))
        .get();
    if (!doc.exists) {
      return ShopSettings.defaults(updatedBy: '');
    }
    return ShopSettingsModel.fromFirestore(doc).toEntity();
  }

  /// Watch shop settings for real-time updates
  Stream<ShopSettings> watchSettings(String shopId) {
    return _firestore
        .doc(FirestorePaths.shopSettings(shopId))
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        return ShopSettings.defaults(updatedBy: '');
      }
      return ShopSettingsModel.fromFirestore(doc).toEntity();
    });
  }

  /// Update shop settings (merge to avoid overwriting unrelated fields)
  Future<void> updateSettings(String shopId, ShopSettings settings) async {
    final model = ShopSettingsModel.fromEntity(settings);
    await _firestore
        .doc(FirestorePaths.shopSettings(shopId))
        .set(model.toFirestore(), SetOptions(merge: true));
  }

  /// Update a single setting field
  Future<void> updateField(
      String shopId, String field, dynamic value, String userId) async {
    await _firestore.doc(FirestorePaths.shopSettings(shopId)).update({
      field: value,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': userId,
    });
  }

  /// Initialize default settings for a new shop
  Future<void> initializeDefaults(String shopId, String userId) async {
    final doc = await _firestore
        .doc(FirestorePaths.shopSettings(shopId))
        .get();
    if (doc.exists) return; // Don't overwrite existing settings

    final defaults = ShopSettingsModel(
      updatedAt: DateTime.now(),
      updatedBy: userId,
    );
    await _firestore
        .doc(FirestorePaths.shopSettings(shopId))
        .set(defaults.toFirestore());
  }
}
