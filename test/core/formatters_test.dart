import 'package:flutter_test/flutter_test.dart';
import 'package:inventra/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    group('currency', () {
      test('formats basic amounts', () {
        expect(Formatters.currency(19.99), '₦19.99');
        expect(Formatters.currency(0), '₦0.00');
        expect(Formatters.currency(1234.5), '₦1,234.50');
      });

      test('formats compact currency', () {
        expect(Formatters.compactCurrency(42590), '₦42.6K');
        expect(Formatters.compactCurrency(1500000), '₦1.5M');
        expect(Formatters.compactCurrency(500), '₦500.00');
      });
    });

    group('number', () {
      test('formats with commas', () {
        expect(Formatters.number(842), '842');
        expect(Formatters.number(1245), '1,245');
        expect(Formatters.number(1000000), '1,000,000');
      });
    });

    group('relative date', () {
      test('shows just now for recent', () {
        expect(Formatters.relative(DateTime.now()), 'Just now');
      });

      test('shows minutes ago', () {
        final tenMinAgo = DateTime.now().subtract(const Duration(minutes: 10));
        expect(Formatters.relative(tenMinAgo), '10m ago');
      });

      test('shows hours ago', () {
        final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
        expect(Formatters.relative(twoHoursAgo), '2h ago');
      });
    });
  });
}
