import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/app_user.dart';

/// Firestore data model for User
class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? shopId;
  final String role;
  final String? phone;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.shopId,
    required this.role,
    this.phone,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      shopId: data['shopId'] as String?,
      role: data['role'] as String? ?? 'sales',
      phone: data['phone'] as String?,
      fcmToken: data['fcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'shopId': shopId,
      'role': role,
      'phone': phone,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  AppUser toEntity() {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      shopId: shopId,
      role: _parseRole(role),
      fcmToken: fcmToken,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static UserRole _parseRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'sales':
        return UserRole.sales;
      case 'warehouse':
        return UserRole.warehouse;
      case 'manager':
        return UserRole.manager;
      default:
        return UserRole.sales;
    }
  }

  static UserModel fromEntity(AppUser user, {String? phone}) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoUrl,
      shopId: user.shopId,
      role: user.role.name,
      phone: phone,
      fcmToken: user.fcmToken,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}
