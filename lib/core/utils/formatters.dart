import 'package:intl/intl.dart';

/// Formatting utilities for currency, dates, and numbers
class Formatters {
  Formatters._();

  // ── Currency ──
  static String currency(double amount, {String symbol = '₦'}) {
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  static String compactCurrency(double amount, {String symbol = '₦'}) {
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return currency(amount, symbol: symbol);
  }

  // ── Numbers ──
  static String number(int value) {
    return NumberFormat('#,##0').format(value);
  }

  static String compactNumber(int value) {
    return NumberFormat.compact().format(value);
  }

  static String decimal(double value, {int places = 2}) {
    return value.toStringAsFixed(places);
  }

  // ── Dates ──
  static String date(DateTime dt) {
    return DateFormat('MMM d, yyyy').format(dt);
  }

  static String dateShort(DateTime dt) {
    return DateFormat('MMM d').format(dt);
  }

  static String dateTime(DateTime dt) {
    return DateFormat('MMM d, yyyy · h:mm a').format(dt);
  }

  static String time(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  static String relative(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(dt);
  }

  // ── Quantity ──
  static String quantity(int qty, String unit) {
    return '$qty $unit${qty != 1 ? 's' : ''}';
  }
}
