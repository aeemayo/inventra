import 'package:equatable/equatable.dart';

/// Domain entity for a Shop / Business
class Shop extends Equatable {
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

  const Shop({
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

  Shop copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? description,
    String? address,
    String? phoneNumber,
    String? email,
    String? logoUrl,
    String? currency,
    String? currencySymbol,
    double? taxRate,
    int? memberCount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      address: address ?? this.address,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      memberCount: memberCount ?? this.memberCount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, ownerId, isActive];
}
