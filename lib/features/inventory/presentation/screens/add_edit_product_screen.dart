import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/product.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../controllers/inventory_controller.dart';

/// Add/Edit product screen matching Figma "Edit Product":
/// - Product image preview
/// - Editable fields (Name, Category, SKU, pricing)
/// - "Save Changes" green button
class AddEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;

  const AddEditProductScreen({super.key, this.productId});

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');
  final _supplierController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  Product? _existingProduct;

  bool get isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
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
        _skuController.text = product.sku;
        _barcodeController.text = product.barcode ?? '';
        _costPriceController.text = product.costPrice.toString();
        _sellingPriceController.text = product.sellingPrice.toString();
        _quantityController.text = product.quantity.toString();
        _reorderLevelController.text = product.reorderLevel.toString();
        _unitController.text = product.unit;
        _supplierController.text = product.supplier ?? '';
        _descriptionController.text = product.description ?? '';
        _selectedCategory = product.categoryId;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _quantityController.dispose();
    _reorderLevelController.dispose();
    _unitController.dispose();
    _supplierController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final userId = ref.read(currentUserProvider)?.uid ?? '';

    final product = Product(
      id: _existingProduct?.id ?? '',
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      categoryId: _selectedCategory,
      costPrice: double.tryParse(_costPriceController.text) ?? 0,
      sellingPrice: double.tryParse(_sellingPriceController.text) ?? 0,
      quantity: int.tryParse(_quantityController.text) ?? 0,
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
          content: Text(
              isEditing ? 'Product updated!' : 'Product added!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(inventoryControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.screenPaddingH),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Product Image ──
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppColors.inputFill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                        image: _existingProduct?.imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(
                                    _existingProduct!.imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _existingProduct?.imageUrl == null
                          ? const Icon(Icons.add_a_photo_outlined,
                              color: AppColors.textTertiary, size: 32)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: AppColors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              // ── Name ──
              AppTextField(
                label: 'Product Name',
                hint: 'e.g. Milo Sachet 22g',
                controller: _nameController,
                validator: (v) => Validators.required(v, 'Product name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSizes.lg),

              // ── SKU + Barcode ──
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'SKU',
                      hint: 'e.g. MLO-22G',
                      controller: _skuController,
                      validator: (v) => Validators.required(v, 'SKU'),
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Barcode',
                      hint: 'Scan or enter',
                      controller: _barcodeController,
                      textInputAction: TextInputAction.next,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner_rounded,
                            size: 20),
                        onPressed: () {
                          // TODO: Open scanner
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Cost Price + Selling Price ──
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Cost Price',
                      hint: '0.00',
                      controller: _costPriceController,
                      keyboardType: TextInputType.number,
                      validator: Validators.price,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text('\$',
                            style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Selling Price',
                      hint: '0.00',
                      controller: _sellingPriceController,
                      keyboardType: TextInputType.number,
                      validator: Validators.price,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Text('\$',
                            style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Quantity + Reorder Level ──
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Quantity',
                      hint: '0',
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      validator: Validators.quantity,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: AppTextField(
                      label: 'Reorder Level',
                      hint: '5',
                      controller: _reorderLevelController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Unit ──
              AppTextField(
                label: 'Unit',
                hint: 'pcs, kg, ltr, etc.',
                controller: _unitController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Supplier ──
              AppTextField(
                label: 'Supplier',
                hint: 'Supplier name (optional)',
                controller: _supplierController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSizes.lg),

              // ── Description ──
              AppTextField(
                label: 'Description',
                hint: 'Product description (optional)',
                controller: _descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: AppSizes.xxxl),

              // ── Save Button ──
              AppButton(
                label: isEditing ? 'Save Changes' : 'Add Product',
                isLoading: controllerState.isLoading,
                onPressed: _onSave,
              ),
              const SizedBox(height: AppSizes.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content:
            const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(inventoryControllerProvider.notifier)
                  .deleteProduct(widget.productId!);
              if (success && mounted) {
                context.pop();
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
