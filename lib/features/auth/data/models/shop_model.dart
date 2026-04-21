import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/shop.dart';

/// Firestore data model for Shop
class ShopModel {
  final String id;
  final String name;
  final String ownerId;
  final String? description;
  final String? address;
  final String? phoneNumber;
  final String? email;
  final String? logoUrl;
  final String currency;
  final String currencySymbol;
  final double taxRate;
  final int memberCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShopModel({
    required this.id,
    required this.name,
    required this.ownerId,
    this.description,
    this.address,
    this.phoneNumber,
    this.email,
    this.logoUrl,
    this.currency = 'NGN',
    this.currencySymbol = '₦',
    this.taxRate = 0.0,
    this.memberCount = 1,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShopModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ShopModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      description: data['description'] as String?,
      address: data['address'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      email: data['email'] as String?,
      logoUrl: data['logoUrl'] as String?,
      currency: data['currency'] as String? ?? 'NGN',
      currencySymbol: data['currencySymbol'] as String? ?? '₦',
      taxRate: (data['taxRate'] as num?)?.toDouble() ?? 0.0,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 1,
      isActive: data['isActive'] as bool? ?? true,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'ownerId': ownerId,
      'description': description,
      'address': address,
      'phoneNumber': phoneNumber,
      'email': email,
      'logoUrl': logoUrl,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'taxRate': taxRate,
      'memberCount': memberCount,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Shop toEntity() {
    return Shop(
      id: id,
      name: name,
      ownerId: ownerId,
      description: description,
      address: address,
      phoneNumber: phoneNumber,
      email: email,
      logoUrl: logoUrl,
      currency: currency,
      currencySymbol: currencySymbol,
      taxRate: taxRate,
      memberCount: memberCount,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ShopModel fromEntity(Shop shop) {
    return ShopModel(
      id: shop.id,
      name: shop.name,
      ownerId: shop.ownerId,
      description: shop.description,
      address: shop.address,
      phoneNumber: shop.phoneNumber,
      email: shop.email,
      logoUrl: shop.logoUrl,
      currency: shop.currency,
      currencySymbol: shop.currencySymbol,
      taxRate: shop.taxRate,
      memberCount: shop.memberCount,
      isActive: shop.isActive,
      createdAt: shop.createdAt,
      updatedAt: shop.updatedAt,
    );
  }
}
