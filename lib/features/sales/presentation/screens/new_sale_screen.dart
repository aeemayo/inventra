import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/formatters.dart';
import '../../../inventory/domain/entities/product.dart';

class NewSaleScreen extends ConsumerStatefulWidget {
  final Product? initialProduct;

  const NewSaleScreen({super.key, this.initialProduct});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _customerIdController = TextEditingController();
  int _quantity = 1;

  @override
  void dispose() {
    _customerIdController.dispose();
    super.dispose();
  }

  void _incrementQty() {
    if (widget.initialProduct != null && _quantity < widget.initialProduct!.quantity) {
      setState(() => _quantity++);
    } else if (widget.initialProduct == null) {
      setState(() => _quantity++);
    }
  }

  void _decrementQty() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  void _completeSale() {
    // Show success and go back to dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sale completed successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.initialProduct;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Light background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text('New Sale', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Colors.black87)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Row(
              children: [
                _buildStepperStep('Scan', isActive: true, isComplete: true),
                const SizedBox(width: 8),
                _buildStepperStep('Details', isActive: true, isComplete: true),
                const SizedBox(width: 8),
                _buildStepperStep('Confirm', isActive: false, isComplete: false),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSizes.screenPaddingH, AppSizes.md, AppSizes.screenPaddingH, 160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IDENTIFIED PRODUCT CARD
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withAlpha(38),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('IDENTIFIED', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                            Icon(Icons.qr_code_scanner_rounded, color: Colors.grey.shade400, size: 20),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Graphic
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: product?.imageUrl != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(product!.imageUrl!, fit: BoxFit.cover))
                                  : const Icon(Icons.inventory_2_outlined, color: AppColors.coral, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product?.name ?? 'Unknown Product',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.2),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'SKU: ${product?.sku ?? 'N/A'}',
                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    product != null ? Formatters.currency(product.sellingPrice) : '\$0.00',
                                    style: const TextStyle(color: AppColors.coral, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),

                  // CURRENT STOCK CARD
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5FF), // Light blue tint
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD6E4FF)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.inventory_2_rounded, color: Colors.blue, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CURRENT STOCK', style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('${product?.quantity ?? 0} units available', style: const TextStyle(color: Colors.black87, fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Icon(Icons.show_chart_rounded, color: Colors.blue, size: 24),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxl),

                  // SPECIFY QUANTITY
                  const Text('Specify Quantity', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: AppSizes.md),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _decrementQty,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.remove_rounded, color: Colors.black54),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$_quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            const Text('Unit', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _incrementQty,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxl),

                  // CUSTOMER ID
                  const Text('Customer ID (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 16, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      const Text('Scan or enter ID', style: TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _customerIdController,
                    decoration: InputDecoration(
                      hintText: 'e.g. CUST-8201',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.coral),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // BOTTOM CONFIRMATION SHEET
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Deduction', style: TextStyle(color: Colors.black54, fontSize: 14)),
                      Text('$_quantity Unit${_quantity > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _completeSale,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.coral, // Orange from preset matching the wireframe
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: const Text('Complete Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.sync_rounded, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Updates central database automatically', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Expanded _buildStepperStep(String label, {required bool isActive, required bool isComplete}) {
    final color = isActive ? AppColors.coral : Colors.grey.shade300;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isActive ? Colors.black87 : Colors.grey, fontWeight: isActive ? FontWeight.w600 : FontWeight.w500)),
          const SizedBox(height: 4),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          )
        ],
      ),
    );
  }
}
