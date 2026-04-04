import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../domain/entities/product.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/inventory_controller.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;
  final String? initialBarcode;

  const AddEditProductScreen({super.key, this.productId, this.initialBarcode});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _upcController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');
  final _supplierController = TextEditingController();
  final _descriptionController = TextEditingController();

  // New details fields matching wireframe
  final _categoryController = TextEditingController();
  final _expiryController = TextEditingController();

  int _quantity = 1;
  Product? _existingProduct;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (!isEditing && widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
      _upcController.text = widget.initialBarcode!;
    }
    if (isEditing) {
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final product = await ref
        .read(productRepositoryProvider)
        .getProduct(shopId, widget.productId!);

    if (product != null && mounted) {
      setState(() {
        _existingProduct = product;
        _nameController.text = product.name;
        _upcController.text = product.sku;
        _barcodeController.text = product.barcode ?? '';
        _costPriceController.text = product.costPrice.toString();
        _sellingPriceController.text = product.sellingPrice.toString();
        _quantity = product.quantity > 0 ? product.quantity : 1;
        _reorderLevelController.text = product.reorderLevel.toString();
        _unitController.text = product.unit;
        _supplierController.text = product.supplier ?? '';
        _descriptionController.text = product.description ?? '';
        _categoryController.text = product.categoryId ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upcController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _reorderLevelController.dispose();
    _unitController.dispose();
    _supplierController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final userId = ref.read(currentUserProvider)?.uid ?? '';

    final product = Product(
      id: _existingProduct?.id ?? '',
      name: _nameController.text.trim(),
      sku: _upcController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      categoryId: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      costPrice: double.tryParse(_costPriceController.text) ?? 0,
      sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
      quantity: _quantity,
      reorderLevel: int.tryParse(_reorderLevelController.text) ?? 5,
      unit: _unitController.text.trim(),
      supplier: _supplierController.text.trim().isEmpty
          ? null
          : _supplierController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      createdAt: _existingProduct?.createdAt ?? now,
      updatedAt: now,
      createdBy: _existingProduct?.createdBy ?? userId,
      updatedBy: userId,
    );

    bool success;
    if (isEditing) {
      success = await ref
          .read(inventoryControllerProvider.notifier)
          .updateProduct(product);
    } else {
      final result = await ref
          .read(inventoryControllerProvider.notifier)
          .addProduct(product);
      success = result != null;
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Product updated!' : 'Product added!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  void _incrementQty() => setState(() => _quantity++);
  void _decrementQty() {
    if (_quantity > 1) setState(() => _quantity--);
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(inventoryControllerProvider);

    return Scaffold(
      backgroundColor:
          const Color(0xFFF8F9FB), // Light background like wireframe
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEditing ? 'Edit Product' : 'New Product',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.black87)),
            if (isEditing || _upcController.text.isNotEmpty)
              Text(
                  'ID: #${_upcController.text.isEmpty ? 'UPC-NEW' : _upcController.text}',
                  style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSizes.screenPaddingH,
                  AppSizes.md, AppSizes.screenPaddingH, 140),
              child: Form(
                key: _formKey,
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
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Graphic placeholder
                          Container(
                            width: 48,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: _existingProduct?.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                        _existingProduct!.imageUrl!,
                                        fit: BoxFit.cover))
                                : const Icon(Icons.local_drink_rounded,
                                    color: Colors.orange, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _nameController.text.isEmpty
                                            ? 'Product Name'
                                            : _nameController.text,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            height: 1.2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success.withAlpha(38),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text('IN\nSTOCK',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: AppColors.success,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              height: 1.1)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Category: ${_categoryController.text.isEmpty ? 'Various' : _categoryController.text} | UPC: ${_upcController.text.isEmpty ? '...' : _upcController.text}',
                                  style: const TextStyle(
                                      color: Colors.black54, fontSize: 12),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: const [
                                    Icon(Icons.check_circle_outline_rounded,
                                        color: AppColors.success, size: 16),
                                    SizedBox(width: 4),
                                    Text('Product Verified',
                                        style: TextStyle(
                                            color: AppColors.success,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxl),

                    // QUANTITY TO ADD
                    const Text('Quantity to Add',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
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
                          // Minus button
                          GestureDetector(
                            onTap: _decrementQty,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F3F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.remove_rounded,
                                  color: Colors.black54, size: 28),
                            ),
                          ),
                          // Value text
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$_quantity',
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800)),
                              const Text('units',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          // Plus button
                          GestureDetector(
                            onTap: _incrementQty,
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxl),

                    // DETAILS
                    const Text('Details',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: AppSizes.md),

                    _buildWireframeInput(
                      label: 'Category',
                      hint: 'e.g. Beverages, Soda',
                      controller: _categoryController,
                      icon: Icons.category_rounded,
                    ),
                    const SizedBox(height: AppSizes.lg),

                    _buildWireframeInput(
                      label: 'Expiration Date (Optional)',
                      hint: 'mm/dd/yyyy',
                      controller: _expiryController,
                      icon: Icons.calendar_today_rounded, // calendar
                    ),

                    // Essential master fields below so we don't break functionality
                    const SizedBox(height: AppSizes.xl),
                    Theme(
                      data: Theme.of(context)
                          .copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Master Data (Edit Product Info)',
                            style: TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        children: [
                          _buildWireframeInput(
                              label: 'Name',
                              hint: 'Product Name',
                              controller: _nameController,
                              isRequired: true),
                          const SizedBox(height: AppSizes.md),
                          _buildWireframeInput(
                              label: 'UPC',
                              hint: 'UPC',
                              controller: _upcController,
                              isRequired: true),
                          const SizedBox(height: AppSizes.md),
                          Row(
                            children: [
                              Expanded(
                                  child: _buildWireframeInput(
                                      label: 'Selling Price (\$)',
                                      hint: '0.00',
                                      controller: _sellingPriceController)),
                              const SizedBox(width: AppSizes.md),
                              Expanded(
                                  child: _buildWireframeInput(
                                      label: 'Cost Price (\$)',
                                      hint: '0.00',
                                      controller: _costPriceController)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // BOTTOM CONFIRMATION SHEET
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 10,
                      offset: const Offset(0, -4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total items adding:',
                          style:
                              TextStyle(color: Colors.black54, fontSize: 14)),
                      Text('$_quantity Unit${_quantity > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: controllerState.isLoading ? null : _onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: controllerState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, size: 20),
                      label: const Text('Confirm Addition',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                      'This action will update the Central Database instantly.',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWireframeInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    IconData? icon,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.crop_free_rounded,
                size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: isRequired ? (v) => v!.isEmpty ? 'Required' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            suffixIcon: icon != null
                ? Icon(icon, color: Colors.grey.shade400, size: 20)
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}
