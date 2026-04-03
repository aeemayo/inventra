import 'package:equatable/equatable.dart';

/// Base failure class for domain-level error handling
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});

  factory AuthFailure.fromCode(String code) {
    switch (code) {
      case 'user-not-found':
        return const AuthFailure(
            message: 'No user found with this email.', code: 'user-not-found');
      case 'wrong-password':
        return const AuthFailure(
            message: 'Incorrect password.', code: 'wrong-password');
      case 'email-already-in-use':
        return const AuthFailure(
            message: 'An account already exists with this email.',
            code: 'email-already-in-use');
      case 'weak-password':
        return const AuthFailure(
            message: 'Password is too weak.', code: 'weak-password');
      case 'invalid-email':
        return const AuthFailure(
            message: 'Invalid email address.', code: 'invalid-email');
      case 'too-many-requests':
        return const AuthFailure(
            message: 'Too many attempts. Please try again later.',
            code: 'too-many-requests');
      case 'invalid-credential':
        return const AuthFailure(
            message: 'Invalid email or password.', code: 'invalid-credential');
      case 'captcha-check-failed':
        return const AuthFailure(
            message: 'Security verification failed. Please try again.',
            code: 'captcha-check-failed');
      case 'app-not-authorized':
        return const AuthFailure(
          message:
              'This app is not authorized for Firebase Authentication in this project.',
          code: 'app-not-authorized',
        );
      case 'operation-not-allowed':
        return const AuthFailure(
          message:
              'Email/password sign-up is currently disabled. Please contact support.',
          code: 'operation-not-allowed',
        );
      default:
        return AuthFailure(message: 'Authentication error: $code', code: code);
    }
  }
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message, super.code});
}

class NetworkFailure extends Failure {
  const NetworkFailure(
      {super.message = 'No internet connection. Please check your network.',
      super.code});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

class StockFailure extends Failure {
  const StockFailure({required super.message, super.code});

  factory StockFailure.outOfStock(String productName) {
    return StockFailure(
      message: '$productName is out of stock.',
      code: 'out-of-stock',
    );
  }

  factory StockFailure.insufficientStock(String productName, int available) {
    return StockFailure(
      message: 'Only $available units of $productName available.',
      code: 'insufficient-stock',
    );
  }
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'You do not have permission to perform this action.',
    super.code,
  });
}
