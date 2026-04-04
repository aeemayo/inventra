import 'package:equatable/equatable.dart';

/// Domain entity for a Product
class Product extends Equatable {
  final String id;
  final String name;
  final String sku;
  final String? barcode;
  final String? categoryId;
  final String? categoryName;
  final double costPrice;
  final double sellingPrice;
  final int quantity;
  final int reorderLevel;
  final String unit;
  final String? supplier;
  final String? imageUrl;
  final String? description;
  final DateTime? expiryDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const Product({
    required this.id,
    required this.name,
    required this.sku,
    this.barcode,
    this.categoryId,
    this.categoryName,
    required this.costPrice,
    required this.sellingPrice,
    required this.quantity,
    required this.reorderLevel,
    this.unit = 'pcs',
    this.supplier,
    this.imageUrl,
    this.description,
    this.expiryDate,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  bool get isLowStock => quantity <= reorderLevel && quantity > 0;
  bool get isOutOfStock => quantity <= 0;
  double get inventoryValue => costPrice * quantity;
  double get potentialRevenue => sellingPrice * quantity;
  double get profit => sellingPrice - costPrice;
  double get profitMargin =>
      sellingPrice > 0 ? ((sellingPrice - costPrice) / sellingPrice * 100) : 0;

  Product copyWith({
    String? id,
    String? name,
    String? sku,
    String? barcode,
    String? categoryId,
    String? categoryName,
    double? costPrice,
    double? sellingPrice,
    int? quantity,
    int? reorderLevel,
    String? unit,
    String? supplier,
    String? imageUrl,
    String? description,
    DateTime? expiryDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      quantity: quantity ?? this.quantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      unit: unit ?? this.unit,
      supplier: supplier ?? this.supplier,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, sku, barcode, quantity, sellingPrice, expiryDate];
}
