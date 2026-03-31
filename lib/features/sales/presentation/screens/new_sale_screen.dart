import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../inventory/domain/entities/product.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';

// ── Cart State ──
final cartItemsProvider =
    StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

final cartSubtotalProvider = Provider<double>((ref) {
  final items = ref.watch(cartItemsProvider);
  return items.fold(0, (sum, item) => sum + item.totalPrice);
});

final cartDiscountProvider = StateProvider<double>((ref) => 0);
final cartTaxRateProvider = StateProvider<double>((ref) => 0);

final cartTotalProvider = Provider<double>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountProvider);
  final taxRate = ref.watch(cartTaxRateProvider);
  final taxAmount = (subtotal - discount) * (taxRate / 100);
  return subtotal - discount + taxAmount;
});

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double get totalPrice => product.sellingPrice * quantity;
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Product product, {int qty = 1}) {
    final idx = state.indexWhere((item) => item.product.id == product.id);
    if (idx >= 0) {
      final updated = List<CartItem>.from(state);
      updated[idx].quantity += qty;
      state = updated;
    } else {
      state = [...state, CartItem(product: product, quantity: qty)];
    }
  }

  void updateQuantity(String productId, int newQty) {
    if (newQty <= 0) {
      removeItem(productId);
      return;
    }
    state = state.map((item) {
      if (item.product.id == productId) {
        return CartItem(product: item.product, quantity: newQty);
      }
      return item;
    }).toList();
  }

  void removeItem(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void clear() {
    state = [];
  }
}

/// New Sale screen matching Figma:
/// - Product items with thumbnails
/// - Quantity controls per item
/// - Discount section
/// - "Calculate Sale" green button
class NewSaleScreen extends ConsumerStatefulWidget {
  final Product? initialProduct;

  const NewSaleScreen({super.key, this.initialProduct});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _discountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(cartItemsProvider.notifier).addItem(widget.initialProduct!);
      });
    }
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartItemsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final discount = ref.watch(cartDiscountProvider);
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('New Sale'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(cartItemsProvider.notifier).clear(),
            ),
        ],
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined,
                        color: AppColors.primary, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Cart is empty', style: AppTypography.h4),
                  const SizedBox(height: 8),
                  Text('Add products by scanning or browsing',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => context.go('/scanner'),
                        icon:
                            const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: const Text('Scan'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showProductPicker(),
                        icon: const Icon(Icons.list_rounded, size: 18),
                        label: const Text('Browse'),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // ── Cart Items ──
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.screenPaddingH),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSizes.sm),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return _CartItemTile(
                        item: item,
                        onQuantityChanged: (qty) {
                          ref
                              .read(cartItemsProvider.notifier)
                              .updateQuantity(item.product.id, qty);
                        },
                        onRemove: () {
                          ref
                              .read(cartItemsProvider.notifier)
                              .removeItem(item.product.id);
                        },
                      );
                    },
                  ),
                ),

                // ── Bottom Summary ──
                Container(
                  padding: EdgeInsets.fromLTRB(
                      AppSizes.xxl,
                      AppSizes.lg,
                      AppSizes.xxl,
                      MediaQuery.of(context).padding.bottom + AppSizes.lg),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    border: Border(
                      top: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Discount
                      Row(
                        children: [
                          const Icon(Icons.discount_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          const Text('Apply discount'),
                          const Spacer(),
                          SizedBox(
                            width: 80,
                            height: 36,
                            child: TextField(
                              controller: _discountController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                hintText: '0.00',
                                prefixText: '\$',
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              onChanged: (v) {
                                final val = double.tryParse(v) ?? 0;
                                ref.read(cartDiscountProvider.notifier).state =
                                    val;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.md),

                      // Summary rows
                      _SummaryRow('Subtotal', Formatters.currency(subtotal)),
                      if (discount > 0)
                        _SummaryRow(
                            'Discount', '-${Formatters.currency(discount)}',
                            color: AppColors.success),
                      const Divider(height: 16),
                      _SummaryRow('Total', Formatters.currency(total),
                          isBold: true, fontSize: 18),
                      const SizedBox(height: AppSizes.lg),

                      AppButton(
                        label: 'Calculate Sale',
                        onPressed: () => context.push('/checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: cartItems.isNotEmpty
          ? FloatingActionButton.small(
              onPressed: _showProductPicker,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }

  void _showProductPicker() {
    final products = ref.read(filteredProductsProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            children: [
              Text('Select Product', style: AppTypography.h4),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: products.length,
                  itemBuilder: (ctx, idx) {
                    final p = products[idx];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 20, color: AppColors.textTertiary),
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                          '${Formatters.currency(p.sellingPrice)} · ${p.quantity} in stock'),
                      trailing: const Icon(Icons.add_circle_outline_rounded),
                      onTap: () {
                        ref.read(cartItemsProvider.notifier).addItem(p);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const _CartItemTile({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Product image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                color: AppColors.textTertiary, size: 22),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name,
                    style: AppTypography.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  Formatters.currency(item.product.sellingPrice),
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),

          // Quantity controls
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QtyButton(
                  icon: Icons.remove,
                  onTap: () => onQuantityChanged(item.quantity - 1),
                ),
                Container(
                  width: 36,
                  alignment: Alignment.center,
                  child:
                      Text('${item.quantity}', style: AppTypography.labelLarge),
                ),
                _QtyButton(
                  icon: Icons.add,
                  onTap: () {
                    if (item.quantity < item.product.quantity) {
                      onQuantityChanged(item.quantity + 1);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Total
          SizedBox(
            width: 60,
            child: Text(
              Formatters.currency(item.totalPrice),
              style: AppTypography.labelLarge,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final double? fontSize;
  final Color? color;

  const _SummaryRow(this.label, this.value,
      {this.isBold = false, this.fontSize, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: fontSize ?? 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
                color: color ?? AppColors.textSecondary,
              )),
          Text(value,
              style: TextStyle(
                fontSize: fontSize ?? 14,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }
}
