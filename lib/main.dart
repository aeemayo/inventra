import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bootstrap.dart';
import 'app.dart';

void main() async {
  await bootstrap();
  runApp(
    const ProviderScope(
      child: InventraApp(),
    ),
  );
}
