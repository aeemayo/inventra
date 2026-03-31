import 'package:flutter_test/flutter_test.dart';
import 'package:inventra/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('email', () {
      test('returns error for empty email', () {
        expect(Validators.email(''), isNotNull);
        expect(Validators.email(null), isNotNull);
      });

      test('returns error for invalid email', () {
        expect(Validators.email('notanemail'), isNotNull);
        expect(Validators.email('test@'), isNotNull);
        expect(Validators.email('@test.com'), isNotNull);
      });

      test('returns null for valid email', () {
        expect(Validators.email('test@example.com'), isNull);
        expect(Validators.email('user.name@domain.co'), isNull);
      });
    });

    group('password', () {
      test('returns error for empty password', () {
        expect(Validators.password(''), isNotNull);
        expect(Validators.password(null), isNotNull);
      });

      test('returns error for short password', () {
        expect(Validators.password('12345'), isNotNull);
      });

      test('returns null for valid password', () {
        expect(Validators.password('123456'), isNull);
        expect(Validators.password('strongpassword'), isNull);
      });
    });

    group('price', () {
      test('returns error for empty price', () {
        expect(Validators.price(''), isNotNull);
        expect(Validators.price(null), isNotNull);
      });

      test('returns error for negative price', () {
        expect(Validators.price('-1'), isNotNull);
      });

      test('returns null for valid price', () {
        expect(Validators.price('0'), isNull);
        expect(Validators.price('19.99'), isNull);
      });
    });

    group('quantity', () {
      test('returns error for invalid quantity', () {
        expect(Validators.quantity(''), isNotNull);
        expect(Validators.quantity('-5'), isNotNull);
        expect(Validators.quantity('abc'), isNotNull);
      });

      test('returns null for valid quantity', () {
        expect(Validators.quantity('0'), isNull);
        expect(Validators.quantity('100'), isNull);
      });
    });
  });
}
