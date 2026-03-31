import 'package:equatable/equatable.dart';

/// Represents the user's role within a shop
enum UserRole {
  admin,
  sales,
  warehouse,
  manager;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.sales:
        return 'Sales';
      case UserRole.warehouse:
        return 'Warehouse';
      case UserRole.manager:
        return 'Manager';
    }
  }

  bool get canManageProducts => this == admin || this == manager || this == warehouse;
  bool get canDeleteProducts => this == admin || this == manager;
  bool get canManageStaff => this == admin;
  bool get canViewReports => this == admin || this == manager;
  bool get canSell => true; // All roles can sell
  bool get canManageSettings => this == admin;
}

/// Domain entity for authenticated user
class AppUser extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? shopId;
  final UserRole role;
  final String? fcmToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.shopId,
    required this.role,
    this.fcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasShop => shopId != null && shopId!.isNotEmpty;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? shopId,
    UserRole? role,
    String? fcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      shopId: shopId ?? this.shopId,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, shopId, role, fcmToken];
}
