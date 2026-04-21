import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents a top-selling product in an analytics snapshot
class TopProduct extends Equatable {
  final String productId;
  final String name;
  final int qty;
  final double revenue;

  const TopProduct({
    required this.productId,
    required this.name,
    required this.qty,
    required this.revenue,
  });

  factory TopProduct.fromMap(Map<String, dynamic> map) {
    return TopProduct(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'qty': qty,
      'revenue': revenue,
    };
  }

  @override
  List<Object?> get props => [productId, qty, revenue];
}

/// Domain entity for daily analytics snapshot
class AnalyticsSnapshot extends Equatable {
  final String id;
  final DateTime date;
  final int totalSales;
  final double totalRevenue;
  final int totalTransactions;
  final List<TopProduct> topProducts;
  final double inventoryValue;
  final int lowStockCount;
  final DateTime updatedAt;

  const AnalyticsSnapshot({
    required this.id,
    required this.date,
    required this.totalSales,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.topProducts,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.updatedAt,
  });

  AnalyticsSnapshot copyWith({
    String? id,
    DateTime? date,
    int? totalSales,
    double? totalRevenue,
    int? totalTransactions,
    List<TopProduct>? topProducts,
    double? inventoryValue,
    int? lowStockCount,
    DateTime? updatedAt,
  }) {
    return AnalyticsSnapshot(
      id: id ?? this.id,
      date: date ?? this.date,
      totalSales: totalSales ?? this.totalSales,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      topProducts: topProducts ?? this.topProducts,
      inventoryValue: inventoryValue ?? this.inventoryValue,
      lowStockCount: lowStockCount ?? this.lowStockCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props =>
      [id, date, totalSales, totalRevenue, totalTransactions];
}

/// Firestore data model for AnalyticsSnapshot
class AnalyticsSnapshotModel {
  final String id;
  final DateTime date;
  final int totalSales;
  final double totalRevenue;
  final int totalTransactions;
  final List<TopProduct> topProducts;
  final double inventoryValue;
  final int lowStockCount;
  final DateTime updatedAt;

  const AnalyticsSnapshotModel({
    required this.id,
    required this.date,
    required this.totalSales,
    required this.totalRevenue,
    required this.totalTransactions,
    required this.topProducts,
    required this.inventoryValue,
    required this.lowStockCount,
    required this.updatedAt,
  });

  factory AnalyticsSnapshotModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    final rawTopProducts = d['topProducts'] as List<dynamic>? ?? [];

    return AnalyticsSnapshotModel(
      id: doc.id,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalSales: (d['totalSales'] as num?)?.toInt() ?? 0,
      totalRevenue: (d['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalTransactions: (d['totalTransactions'] as num?)?.toInt() ?? 0,
      topProducts: rawTopProducts
          .map((e) => TopProduct.fromMap(e as Map<String, dynamic>))
          .toList(),
      inventoryValue: (d['inventoryValue'] as num?)?.toDouble() ?? 0.0,
      lowStockCount: (d['lowStockCount'] as num?)?.toInt() ?? 0,
      updatedAt:
          (d['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'totalSales': totalSales,
      'totalRevenue': totalRevenue,
      'totalTransactions': totalTransactions,
      'topProducts': topProducts.map((e) => e.toMap()).toList(),
      'inventoryValue': inventoryValue,
      'lowStockCount': lowStockCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AnalyticsSnapshot toEntity() {
    return AnalyticsSnapshot(
      id: id,
      date: date,
      totalSales: totalSales,
      totalRevenue: totalRevenue,
      totalTransactions: totalTransactions,
      topProducts: topProducts,
      inventoryValue: inventoryValue,
      lowStockCount: lowStockCount,
      updatedAt: updatedAt,
    );
  }
}
