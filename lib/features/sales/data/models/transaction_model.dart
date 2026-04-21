import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../shared/models/stock_movement.dart';

/// Firestore data model for SaleItem (embedded in transaction)
class SaleItemModel {
  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const SaleItemModel({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  SaleItem toEntity() {
    return SaleItem(
      productId: productId,
      productName: productName,
      sku: sku,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
    );
  }

  static SaleItemModel fromEntity(SaleItem item) {
    return SaleItemModel(
      productId: item.productId,
      productName: item.productName,
      sku: item.sku,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
      totalPrice: item.totalPrice,
    );
  }
}

/// Firestore data model for SaleTransaction
class TransactionModel {
  final String id;
  final String type;
  final List<SaleItemModel> items;
  final double subtotal;
  final double discount;
  final double taxAmount;
  final double total;
  final String paymentMethod;
  final String status;
  final String? note;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.taxAmount,
    required this.total,
    required this.paymentMethod,
    required this.status,
    this.note,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  factory TransactionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawItems = d['items'] as List<dynamic>? ?? [];

    return TransactionModel(
      id: doc.id,
      type: d['type'] as String? ?? 'sale',
      items: rawItems
          .map((e) => SaleItemModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (d['discount'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (d['taxAmount'] as num?)?.toDouble() ?? 0.0,
      total: (d['total'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: d['paymentMethod'] as String? ?? 'cash',
      status: d['status'] as String? ?? 'completed',
      note: d['note'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdByName: d['createdByName'] as String? ?? '',
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'items': items.map((e) => e.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'taxAmount': taxAmount,
      'total': total,
      'paymentMethod': paymentMethod,
      'status': status,
      'note': note,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  SaleTransaction toEntity() {
    return SaleTransaction(
      id: id,
      type: type,
      items: items.map((e) => e.toEntity()).toList(),
      subtotal: subtotal,
      discount: discount,
      taxAmount: taxAmount,
      total: total,
      paymentMethod: paymentMethod,
      status: status,
      note: note,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: createdAt,
    );
  }

  static TransactionModel fromEntity(SaleTransaction transaction) {
    return TransactionModel(
      id: transaction.id,
      type: transaction.type,
      items: transaction.items
          .map((e) => SaleItemModel.fromEntity(e))
          .toList(),
      subtotal: transaction.subtotal,
      discount: transaction.discount,
      taxAmount: transaction.taxAmount,
      total: transaction.total,
      paymentMethod: transaction.paymentMethod,
      status: transaction.status,
      note: transaction.note,
      createdBy: transaction.createdBy,
      createdByName: transaction.createdByName,
      createdAt: transaction.createdAt,
    );
  }
}
