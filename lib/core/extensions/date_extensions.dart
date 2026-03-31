import 'package:intl/intl.dart';

extension DateExtensions on DateTime {
  String get formatted => DateFormat('MMM d, yyyy').format(this);
  String get formattedShort => DateFormat('MMM d').format(this);
  String get formattedTime => DateFormat('h:mm a').format(this);
  String get formattedDateTime => DateFormat('MMM d, yyyy · h:mm a').format(this);
  String get iso => toIso8601String();
  String get dayKey => DateFormat('yyyy-MM-dd').format(this);

  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year && month == yesterday.month && day == yesterday.day;
  }

  String get relative {
    final now = DateTime.now();
    final diff = now.difference(this);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatted;
  }

  DateTime get startOfDay => DateTime(year, month, day);
  DateTime get endOfDay => DateTime(year, month, day, 23, 59, 59);
}
