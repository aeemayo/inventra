import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../transactions/presentation/controllers/transaction_logs_controller.dart';

// ── Revenue: sum of (sellingPrice * quantitySold) from stock_movements ──
// We compute "revenue" from sale movements: each sale movement has a negative
// quantityChange, so revenue = sum( |qtyChange| * product sellingPrice ).
// Since stock_movements don't store price, we cross-reference with products.

/// Total revenue computed from sale-type stock movements matched against products.
final reportRevenueProvider = Provider<double>((ref) {
  final movements = ref.watch(stockMovementsProvider).value ?? [];
  final products = ref.watch(productsProvider).value ?? [];

  // Build a lookup from productName -> sellingPrice
  final priceMap = <String, double>{};
  for (final p in products) {
    priceMap[p.name] = p.sellingPrice;
  }

  double totalRevenue = 0;
  for (final m in movements) {
    if (!m.isIntake) {
      // Sale movement
      final price = priceMap[m.productName] ?? 0;
      totalRevenue += price * m.quantityChange.abs();
    }
  }
  return totalRevenue;
});

/// Total units sold from stock movements
final reportUnitsSoldProvider = Provider<int>((ref) {
  final movements = ref.watch(stockMovementsProvider).value ?? [];
  return movements
      .where((m) => !m.isIntake)
      .fold<int>(0, (sum, m) => sum + m.quantityChange.abs());
});

/// Top movers: products sorted by total units sold (from stock_movements)
class TopMover {
  final String name;
  final int sold;
  final double revenue;

  const TopMover({
    required this.name,
    required this.sold,
    required this.revenue,
  });
}

final topMoversProvider = Provider<List<TopMover>>((ref) {
  final movements = ref.watch(stockMovementsProvider).value ?? [];
  final products = ref.watch(productsProvider).value ?? [];

  // Build price lookup
  final priceMap = <String, double>{};
  for (final p in products) {
    priceMap[p.name] = p.sellingPrice;
  }

  // Aggregate sales by product name
  final salesMap = <String, int>{};
  for (final m in movements) {
    if (!m.isIntake) {
      salesMap[m.productName] =
          (salesMap[m.productName] ?? 0) + m.quantityChange.abs();
    }
  }

  // Convert to TopMover list, sorted by units sold descending
  final movers = salesMap.entries.map((entry) {
    final price = priceMap[entry.key] ?? 0;
    return TopMover(
      name: entry.key,
      sold: entry.value,
      revenue: price * entry.value,
    );
  }).toList();

  movers.sort((a, b) => b.sold.compareTo(a.sold));
  return movers.take(10).toList();
});

/// Recent activity entries from stock movements (latest 10)
class RecentActivity {
  final String productName;
  final bool isIntake;
  final int quantity;
  final DateTime timestamp;

  const RecentActivity({
    required this.productName,
    required this.isIntake,
    required this.quantity,
    required this.timestamp,
  });
}

final recentActivityProvider = Provider<List<RecentActivity>>((ref) {
  final movements = ref.watch(stockMovementsProvider).value ?? [];
  return movements.take(10).map((m) {
    return RecentActivity(
      productName: m.productName,
      isIntake: m.isIntake,
      quantity: m.quantityChange.abs(),
      timestamp: m.createdAt,
    );
  }).toList();
});

/// Stock levels by category (for bar chart) — reusing existing products data
class CategoryStock {
  final String category;
  final int totalQuantity;

  const CategoryStock({required this.category, required this.totalQuantity});
}

final categoryStockProvider = Provider<List<CategoryStock>>((ref) {
  final products = ref.watch(productsProvider).value ?? [];

  final map = <String, int>{};
  for (final p in products) {
    if (!p.isActive) continue;
    final cat = p.categoryName ?? 'Uncategorized';
    map[cat] = (map[cat] ?? 0) + p.quantity;
  }

  final result = map.entries
      .map((e) => CategoryStock(category: e.key, totalQuantity: e.value))
      .toList();
  result.sort((a, b) => b.totalQuantity.compareTo(a.totalQuantity));
  return result.take(7).toList();
});

/// Daily sales for the last 7 days (for bar chart)
class DailySales {
  final DateTime date;
  final int unitsSold;
  final double revenue;

  const DailySales({
    required this.date,
    required this.unitsSold,
    required this.revenue,
  });
}

final dailySalesProvider = Provider<List<DailySales>>((ref) {
  final movements = ref.watch(stockMovementsProvider).value ?? [];
  final products = ref.watch(productsProvider).value ?? [];

  // Build price lookup
  final priceMap = <String, double>{};
  for (final p in products) {
    priceMap[p.name] = p.sellingPrice;
  }

  final now = DateTime.now();
  final days = <DailySales>[];

  for (int i = 6; i >= 0; i--) {
    final day = DateTime(now.year, now.month, now.day - i);
    final nextDay = day.add(const Duration(days: 1));

    final daySales = movements.where((m) =>
        !m.isIntake &&
        m.createdAt.isAfter(day) &&
        m.createdAt.isBefore(nextDay));

    int units = 0;
    double rev = 0;
    for (final m in daySales) {
      final qty = m.quantityChange.abs();
      units += qty;
      rev += (priceMap[m.productName] ?? 0) * qty;
    }

    days.add(DailySales(date: day, unitsSold: units, revenue: rev));
  }

  return days;
});
