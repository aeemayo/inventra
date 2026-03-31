import 'package:equatable/equatable.dart';

/// Domain entity for product category
class Category extends Equatable {
  final String id;
  final String name;
  final String? description;
  final int productCount;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.name,
    this.description,
    this.productCount = 0,
    required this.createdAt,
  });

  Category copyWith({
    String? id,
    String? name,
    String? description,
    int? productCount,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      productCount: productCount ?? this.productCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
