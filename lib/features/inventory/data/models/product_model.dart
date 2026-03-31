import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/product.dart';

/// Firestore data model for Product
class ProductModel {
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
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  const ProductModel({
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
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  factory ProductModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProductModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      sku: data['sku'] as String? ?? '',
      barcode: data['barcode'] as String?,
      categoryId: data['categoryId'] as String?,
      categoryName: data['categoryName'] as String?,
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0,
      sellingPrice: (data['sellingPrice'] as num?)?.toDouble() ?? 0,
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (data['reorderLevel'] as num?)?.toInt() ?? 5,
      unit: data['unit'] as String? ?? 'pcs',
      supplier: data['supplier'] as String?,
      imageUrl: data['imageUrl'] as String?,
      description: data['description'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String? ?? '',
      updatedBy: data['updatedBy'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'quantity': quantity,
      'reorderLevel': reorderLevel,
      'unit': unit,
      'supplier': supplier,
      'imageUrl': imageUrl,
      'description': description,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  Product toEntity() {
    return Product(
      id: id,
      name: name,
      sku: sku,
      barcode: barcode,
      categoryId: categoryId,
      categoryName: categoryName,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      quantity: quantity,
      reorderLevel: reorderLevel,
      unit: unit,
      supplier: supplier,
      imageUrl: imageUrl,
      description: description,
      isActive: isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }

  static ProductModel fromEntity(Product product) {
    return ProductModel(
      id: product.id,
      name: product.name,
      sku: product.sku,
      barcode: product.barcode,
      categoryId: product.categoryId,
      categoryName: product.categoryName,
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      quantity: product.quantity,
      reorderLevel: product.reorderLevel,
      unit: product.unit,
      supplier: product.supplier,
      imageUrl: product.imageUrl,
      description: product.description,
      isActive: product.isActive,
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      createdBy: product.createdBy,
      updatedBy: product.updatedBy,
    );
  }
}
