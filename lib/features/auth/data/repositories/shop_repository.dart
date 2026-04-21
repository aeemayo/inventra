import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/shop.dart';
import '../models/shop_model.dart';
import '../../../../shared/models/shop_settings_model.dart';

/// Repository for shop-level operations
class ShopRepository {
  final FirebaseFirestore _firestore;

  ShopRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Create a new shop and initialize its settings sub-document.
  /// Returns the created Shop with its generated ID.
  Future<Shop> createShop({
    required String name,
    required String ownerId,
    String? email,
  }) async {
    final now = DateTime.now();
    final shopRef = _firestore.collection(FirestorePaths.shops).doc();

    final shop = Shop(
      id: shopRef.id,
      name: name,
      ownerId: ownerId,
      email: email,
      createdAt: now,
      updatedAt: now,
    );

    final model = ShopModel.fromEntity(shop);
    final settingsModel = ShopSettingsModel(
      updatedAt: now,
      updatedBy: ownerId,
    );

    // Batch write: shop document + settings sub-document
    final batch = _firestore.batch();
    batch.set(shopRef, model.toFirestore());
    batch.set(
      _firestore.doc(FirestorePaths.shopSettings(shopRef.id)),
      settingsModel.toFirestore(),
    );
    await batch.commit();

    return shop;
  }

  /// Get a shop by ID
  Future<Shop?> getShop(String shopId) async {
    final doc = await _firestore
        .collection(FirestorePaths.shops)
        .doc(shopId)
        .get();
    if (!doc.exists) return null;
    return ShopModel.fromFirestore(doc).toEntity();
  }

  /// Watch a shop document for real-time updates
  Stream<Shop?> watchShop(String shopId) {
    return _firestore
        .collection(FirestorePaths.shops)
        .doc(shopId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ShopModel.fromFirestore(doc).toEntity();
    });
  }

  /// Update shop profile fields
  Future<void> updateShop(String shopId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection(FirestorePaths.shops)
        .doc(shopId)
        .update(updates);
  }

  /// Get shop settings
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

  /// Update shop settings
  Future<void> updateSettings(String shopId, ShopSettings settings) async {
    final model = ShopSettingsModel.fromEntity(settings);
    await _firestore
        .doc(FirestorePaths.shopSettings(shopId))
        .set(model.toFirestore(), SetOptions(merge: true));
  }
}
