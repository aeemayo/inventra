import 'package:flutter_riverpod/legacy.dart';

enum ScannerProtectedRoute {
  addProduct,
  newSale,
}

final scannerRouteAccessProvider = StateNotifierProvider<
    ScannerRouteAccessController, Map<ScannerProtectedRoute, DateTime>>(
  (ref) => ScannerRouteAccessController(),
);

class ScannerRouteAccessController
    extends StateNotifier<Map<ScannerProtectedRoute, DateTime>> {
  ScannerRouteAccessController() : super({});

  static const _accessTtl = Duration(minutes: 1);

  void grant(ScannerProtectedRoute route) {
    state = {
      ...state,
      route: DateTime.now(),
    };
  }

  bool consumeIfValid(ScannerProtectedRoute route) {
    final grantedAt = state[route];
    if (grantedAt == null) return false;

    final remaining = DateTime.now().difference(grantedAt) <= _accessTtl;

    final updated = {...state};
    updated.remove(route);
    state = updated;

    return remaining;
  }
}
