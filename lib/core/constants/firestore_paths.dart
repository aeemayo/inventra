/// Firestore collection and document path constants
class FirestorePaths {
  FirestorePaths._();

  // ── Top-level Collections ──
  static const String users = 'users';
  static const String shops = 'shops';

  // ── Shop Sub-collections ──
  static String products(String shopId) => 'shops/$shopId/products';
  static String categories(String shopId) => 'shops/$shopId/categories';
  static String transactions(String shopId) => 'shops/$shopId/transactions';
  static String stockMovements(String shopId) => 'shops/$shopId/stock_movements';
  static String scanHistory(String shopId) => 'shops/$shopId/scan_history';
  static String notifications(String shopId) => 'shops/$shopId/notifications';
  static String analyticsSnapshots(String shopId) => 'shops/$shopId/analytics_snapshots';

  // ── Shop Documents ──
  static String shopSettings(String shopId) => 'shops/$shopId/settings/config';
  static String shop(String shopId) => 'shops/$shopId';
  static String user(String uid) => 'users/$uid';

  // ── Product Documents ──
  static String product(String shopId, String productId) =>
      'shops/$shopId/products/$productId';

  // ── Transaction Documents ──
  static String transaction(String shopId, String transactionId) =>
      'shops/$shopId/transactions/$transactionId';
}
