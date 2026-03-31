import 'package:flutter_test/flutter_test.dart';
import 'package:inventra/features/inventory/domain/entities/product.dart';

void main() {
  group('Product Entity', () {
    final product = Product(
      id: 'test-1',
      name: 'Test Product',
      sku: 'TST-001',
      barcode: '1234567890',
      costPrice: 10.0,
      sellingPrice: 25.0,
      quantity: 50,
      reorderLevel: 10,
      unit: 'pcs',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'user-1',
      updatedBy: 'user-1',
    );

    test('calculates inventory value correctly', () {
      expect(product.inventoryValue, 500.0);
    });

    test('calculates potential revenue correctly', () {
      expect(product.potentialRevenue, 1250.0);
    });

    test('calculates profit correctly', () {
      expect(product.profit, 15.0);
    });

    test('reports correct stock status for normal stock', () {
      expect(product.isLowStock, false);
      expect(product.isOutOfStock, false);
    });

    test('reports low stock correctly', () {
      final lowStock = product.copyWith(quantity: 8);
      expect(lowStock.isLowStock, true);
      expect(lowStock.isOutOfStock, false);
    });

    test('reports out of stock correctly', () {
      final outOfStock = product.copyWith(quantity: 0);
      expect(outOfStock.isOutOfStock, true);
    });

    test('copyWith preserves unchanged fields', () {
      final updated = product.copyWith(name: 'Updated Name');
      expect(updated.name, 'Updated Name');
      expect(updated.sku, 'TST-001');
      expect(updated.quantity, 50);
    });

    test('profit margin calculated correctly', () {
      expect(product.profitMargin, 60.0);
    });
  });
}
