import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';

class EditProductsScreen extends ConsumerStatefulWidget {
  const EditProductsScreen({super.key});

  @override
  ConsumerState<EditProductsScreen> createState() => _EditProductsScreenState();
}

class _EditProductsScreenState extends ConsumerState<EditProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Product> _filterProducts(List<Product> products) {
    final lowerQuery = _query.trim().toLowerCase();
    if (lowerQuery.isEmpty) return products;

    return products.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
          p.sku.toLowerCase().contains(lowerQuery) ||
          (p.barcode?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  Future<void> _showQuickEditDialog(Product product) async {
    final priceController = TextEditingController(
      text: product.sellingPrice.toStringAsFixed(2),
    );
    final expiryController = TextEditingController(
      text: _formatDate(product.expiryDate),
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Selling Price',
                  hintText: 'e.g. 12.99',
                  prefixText: '\$ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: expiryController,
                decoration: const InputDecoration(
                  labelText: 'Expiry Date',
                  hintText: 'mm/dd/yyyy (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPrice = double.tryParse(priceController.text.trim());
                if (newPrice == null || newPrice < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid price.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final parsedExpiry = _parseDate(expiryController.text);
                if (expiryController.text.trim().isNotEmpty &&
                    parsedExpiry == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Use date format mm/dd/yyyy.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                  return;
                }

                final userId = ref.read(currentUserProvider)?.uid ?? '';
                final updated = product.copyWith(
                  sellingPrice: newPrice,
                  expiryDate: parsedExpiry,
                  updatedAt: DateTime.now(),
                  updatedBy: userId,
                );

                final success = await ref
                    .read(inventoryControllerProvider.notifier)
                    .updateProduct(updated);

                if (!mounted) return;

                if (success) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product updated.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to update product.'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    priceController.dispose();
    expiryController.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$mm/$dd/${date.year}';
  }

  DateTime? _parseDate(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
    if (match == null) return null;

    final month = int.tryParse(match.group(1)!);
    final day = int.tryParse(match.group(2)!);
    final year = int.tryParse(match.group(3)!);

    if (month == null || day == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Edit Products',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.screenPaddingH,
          AppSizes.md,
          AppSizes.screenPaddingH,
          AppSizes.lg,
        ),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search by product name, SKU, or barcode',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Expanded(
              child: productsAsync.when(
                data: (products) {
                  final activeProducts = _filterProducts(
                      products.where((p) => p.isActive).toList());

                  if (activeProducts.isEmpty) {
                    return const Center(
                      child: Text(
                        'No products available for editing.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: activeProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = activeProducts[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Price: \$${product.sellingPrice.toStringAsFixed(2)}\n'
                              'Expiry: ${_formatDate(product.expiryDate).isEmpty ? 'Not set' : _formatDate(product.expiryDate)}',
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'quick') {
                                _showQuickEditDialog(product);
                              }
                              if (value == 'full') {
                                context.push('/inventory/${product.id}/edit');
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'quick',
                                child: Text('Quick Edit'),
                              ),
                              PopupMenuItem(
                                value: 'full',
                                child: Text('Open Full Editor'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (err, _) => Center(
                  child: Text(
                    'Failed to load products: $err',
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
