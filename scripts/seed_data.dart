// ignore_for_file: avoid_print

// Seed data script for Inventra
// Run with: dart run scripts/seed_data.dart
//
// Note: This script requires firebase_admin package configured.
// Alternatively, use the Firebase console or import .json directly.

/// Demo Categories
const categories = [
  {
    'id': 'cat_electronics',
    'name': 'Electronics',
    'description': 'Electronic devices and accessories'
  },
  {
    'id': 'cat_food',
    'name': 'Food & Beverages',
    'description': 'Consumable food items'
  },
  {
    'id': 'cat_office',
    'name': 'Office Supplies',
    'description': 'Stationery and office materials'
  },
  {
    'id': 'cat_accessories',
    'name': 'Accessories',
    'description': 'Phone cases, cables, adapters'
  },
];

/// Demo Products
const products = [
  {
    'name': 'Wireless Mouse Kit',
    'sku': 'WMK-001',
    'barcode': '8901234567890',
    'categoryId': 'cat_electronics',
    'categoryName': 'Electronics',
    'costPrice': 15.00,
    'sellingPrice': 24.99,
    'quantity': 45,
    'reorderLevel': 10,
    'unit': 'pcs',
    'supplier': 'TechWorld Distributors',
  },
  {
    'name': 'USB-C Cable 2m',
    'sku': 'USB-C2M',
    'barcode': '8901234567891',
    'categoryId': 'cat_accessories',
    'categoryName': 'Accessories',
    'costPrice': 3.50,
    'sellingPrice': 7.99,
    'quantity': 128,
    'reorderLevel': 20,
    'unit': 'pcs',
    'supplier': 'CableMax',
  },
  {
    'name': 'Milo Sachet 22g',
    'sku': 'MLO-22G',
    'barcode': '8901234567892',
    'categoryId': 'cat_food',
    'categoryName': 'Food & Beverages',
    'costPrice': 0.80,
    'sellingPrice': 1.50,
    'quantity': 350,
    'reorderLevel': 50,
    'unit': 'pcs',
    'supplier': 'Nestle Distributors',
  },
  {
    'name': 'Phone Charger 20W',
    'sku': 'CHG-20W',
    'barcode': '8901234567893',
    'categoryId': 'cat_electronics',
    'categoryName': 'Electronics',
    'costPrice': 8.00,
    'sellingPrice': 14.99,
    'quantity': 62,
    'reorderLevel': 15,
    'unit': 'pcs',
    'supplier': 'TechWorld Distributors',
  },
  {
    'name': 'USB Hub 4-Port',
    'sku': 'HUB-4P',
    'barcode': '8901234567894',
    'categoryId': 'cat_electronics',
    'categoryName': 'Electronics',
    'costPrice': 12.00,
    'sellingPrice': 19.99,
    'quantity': 8,
    'reorderLevel': 10,
    'unit': 'pcs',
    'supplier': 'TechWorld Distributors',
  },
  {
    'name': 'A4 Paper Ream',
    'sku': 'A4-500',
    'barcode': '8901234567895',
    'categoryId': 'cat_office',
    'categoryName': 'Office Supplies',
    'costPrice': 4.50,
    'sellingPrice': 8.99,
    'quantity': 200,
    'reorderLevel': 30,
    'unit': 'pcs',
    'supplier': 'Office Pro',
  },
  {
    'name': 'Sticky Notes Pack',
    'sku': 'STN-100',
    'barcode': '8901234567896',
    'categoryId': 'cat_office',
    'categoryName': 'Office Supplies',
    'costPrice': 1.20,
    'sellingPrice': 2.99,
    'quantity': 3,
    'reorderLevel': 15,
    'unit': 'pcs',
    'supplier': 'Office Pro',
  },
  {
    'name': 'Bluetooth Speaker Mini',
    'sku': 'BTS-MN1',
    'barcode': '8901234567897',
    'categoryId': 'cat_electronics',
    'categoryName': 'Electronics',
    'costPrice': 18.00,
    'sellingPrice': 29.99,
    'quantity': 0,
    'reorderLevel': 5,
    'unit': 'pcs',
    'supplier': 'AudioGear',
  },
  {
    'name': 'Earbuds Pro',
    'sku': 'EBP-001',
    'barcode': '8901234567898',
    'categoryId': 'cat_electronics',
    'categoryName': 'Electronics',
    'costPrice': 25.00,
    'sellingPrice': 49.99,
    'quantity': 22,
    'reorderLevel': 8,
    'unit': 'pcs',
    'supplier': 'AudioGear',
  },
  {
    'name': 'Screen Protector iPhone 15',
    'sku': 'SP-IP15',
    'barcode': '8901234567899',
    'categoryId': 'cat_accessories',
    'categoryName': 'Accessories',
    'costPrice': 2.00,
    'sellingPrice': 5.99,
    'quantity': 75,
    'reorderLevel': 20,
    'unit': 'pcs',
    'supplier': 'CableMax',
  },
];

void main() {
  print('===== Inventra Seed Data =====');
  print('');
  print('To seed your Firestore database:');
  print('1. Go to Firebase Console > Firestore');
  print('2. Create collection "shops" with a doc (your shop ID)');
  print('3. Add sub-collections: products, categories');
  print('4. Import the data above');
  print('');
  print('Categories: ${categories.length}');
  print('Products: ${products.length}');
  print('');
  print('Demo user credentials:');
  print('  Email: admin@inventra.app');
  print('  Password: inventra123');
  print('  Role: admin');
  print('');
  print('Or register a new account through the app.');
}
