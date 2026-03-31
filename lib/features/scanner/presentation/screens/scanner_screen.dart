import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';
import '../../../inventory/domain/entities/product.dart';

/// Scanner screen matching Figma:
/// - Dark camera view
/// - Blue rectangular scan frame overlay
/// - "Identify Product" label
/// - Bottom panel with action buttons
class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  MobileScannerController? _cameraController;
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 500));
  bool _isProcessing = false;
  bool _torchEnabled = false;
  String? _lastScannedCode;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Debounce repeated scans
    if (code == _lastScannedCode) return;

    _debouncer.run(() => _processBarcode(code));
  }

  Future<void> _processBarcode(String barcode) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _lastScannedCode = barcode;
    });

    final shopId = ref.read(currentShopIdProvider);
    if (shopId == null) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final product = await ref
          .read(productRepositoryProvider)
          .findByBarcode(shopId, barcode);

      if (!mounted) return;

      if (product != null) {
        _showProductFoundSheet(product, barcode);
      } else {
        _showProductNotFoundSheet(barcode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showProductFoundSheet(Product product, String barcode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductFoundSheet(
        product: product,
        barcode: barcode,
        onSell: () {
          Navigator.pop(ctx);
          context.push('/new-sale', extra: product);
        },
        onRestock: () {
          Navigator.pop(ctx);
          _showRestockDialog(product);
        },
        onAdjust: () {
          Navigator.pop(ctx);
          _showStockAdjustDialog(product);
        },
        onViewDetail: () {
          Navigator.pop(ctx);
          context.push('/inventory/${product.id}');
        },
      ),
    );
  }

  void _showProductNotFoundSheet(String barcode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSizes.xxl),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSizes.xxl),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.search_off_rounded,
                  color: AppColors.warning, size: 32),
            ),
            const SizedBox(height: AppSizes.lg),
            Text('Product Not Found', style: AppTypography.h4),
            const SizedBox(height: AppSizes.sm),
            Text(
              'No product matches barcode:\n$barcode',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xxl),
            AppButton(
              label: 'Create New Product',
              icon: Icons.add_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                context.push('/inventory/add?barcode=$barcode');
              },
            ),
            const SizedBox(height: AppSizes.md),
            AppButton(
              label: 'Scan Again',
              isOutlined: true,
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _lastScannedCode = null);
              },
            ),
            SizedBox(height: MediaQuery.of(ctx).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showRestockDialog(Product product) {
    final qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Restock ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${product.quantity} ${product.unit}',
                style: AppTypography.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Add Quantity',
                hintText: 'Enter quantity to add',
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
              final qty = int.tryParse(qtyController.text);
              if (qty != null && qty > 0) {
                Navigator.pop(ctx);
                await ref
                    .read(inventoryControllerProvider.notifier)
                    .adjustStock(product.id, qty);
              }
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  void _showStockAdjustDialog(Product product) {
    final qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Adjust ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current stock: ${product.quantity} ${product.unit}',
                style: AppTypography.bodyMedium),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(
                labelText: 'Adjustment',
                hintText: '+5 or -3',
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
              final qty = int.tryParse(qtyController.text);
              if (qty != null && qty != 0) {
                Navigator.pop(ctx);
                await ref
                    .read(inventoryControllerProvider.notifier)
                    .adjustStock(product.id, qty);
              }
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  void _showManualEntry() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Entry'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Barcode / SKU',
            hintText: 'Enter barcode or SKU',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _processBarcode(code);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scannerDark,
      body: Stack(
        children: [
          // ── Camera View ──
          if (_cameraController != null)
            MobileScanner(
              controller: _cameraController!,
              onDetect: _onBarcodeDetected,
            ),

          // ── Scan Overlay ──
          _ScanOverlay(isProcessing: _isProcessing),

          // ── Top Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg, vertical: AppSizes.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.white, size: 28),
                      onPressed: () => context.go('/dashboard'),
                    ),
                    Text('Scan Product',
                        style: AppTypography.h4.copyWith(color: AppColors.white)),
                    IconButton(
                      icon: Icon(
                        _torchEnabled
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: AppColors.white,
                        size: 28,
                      ),
                      onPressed: () {
                        _cameraController?.toggleTorch();
                        setState(() => _torchEnabled = !_torchEnabled);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Panel ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.xxl,
                  AppSizes.xxl,
                  AppSizes.xxl,
                  MediaQuery.of(context).padding.bottom + AppSizes.xl),
              decoration: BoxDecoration(
                color: AppColors.scannerDark.withValues(alpha: 0.95),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Identify Product',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.white),
                  ),
                  const SizedBox(height: AppSizes.lg),

                  // ── Action Buttons ──
                  Row(
                    children: [
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.keyboard_rounded,
                          label: 'Manual Entry',
                          onTap: _showManualEntry,
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.history_rounded,
                          label: 'Scan History',
                          onTap: () => context.push('/scan-history'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.md),

                  Row(
                    children: [
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.qr_code_2_rounded,
                          label: 'QR Mode',
                          isActive: false,
                          onTap: () {},
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.auto_fix_high_rounded,
                          label: 'Auto-detect',
                          isActive: true,
                          onTap: () {},
                        ),
                      ),
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
}

class _ScanOverlay extends StatelessWidget {
  final bool isProcessing;

  const _ScanOverlay({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanOverlayPainter(isProcessing: isProcessing),
      child: const SizedBox.expand(),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final bool isProcessing;

  _ScanOverlayPainter({required this.isProcessing});

  @override
  void paint(Canvas canvas, Size size) {
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2 - 40;
    final scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);

    // Dim overlay
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, top), overlayPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, top, left, scanAreaSize), overlayPaint);
    canvas.drawRect(
        Rect.fromLTWH(left + scanAreaSize, top, left, scanAreaSize),
        overlayPaint);
    canvas.drawRect(
        Rect.fromLTWH(
            0, top + scanAreaSize, size.width, size.height - top - scanAreaSize),
        overlayPaint);

    // Scan frame corners
    final cornerLength = 30.0;
    final cornerWidth = 3.0;
    final paint = Paint()
      ..color = isProcessing ? AppColors.primaryLight : AppColors.scannerBlue
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
        scanRect.topLeft, scanRect.topLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(
        scanRect.topLeft, scanRect.topLeft + Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(
        scanRect.topRight, scanRect.topRight + Offset(-cornerLength, 0), paint);
    canvas.drawLine(
        scanRect.topRight, scanRect.topRight + Offset(0, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(scanRect.bottomLeft,
        scanRect.bottomLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(scanRect.bottomLeft,
        scanRect.bottomLeft + Offset(0, -cornerLength), paint);

    // Bottom-right
    canvas.drawLine(scanRect.bottomRight,
        scanRect.bottomRight + Offset(-cornerLength, 0), paint);
    canvas.drawLine(scanRect.bottomRight,
        scanRect.bottomRight + Offset(0, -cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.isProcessing != isProcessing;
}

class _ProductFoundSheet extends StatelessWidget {
  final Product product;
  final String barcode;
  final VoidCallback onSell;
  final VoidCallback onRestock;
  final VoidCallback onAdjust;
  final VoidCallback onViewDetail;

  const _ProductFoundSheet({
    required this.product,
    required this.barcode,
    required this.onSell,
    required this.onRestock,
    required this.onAdjust,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xxl),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // Product info
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  image: product.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(product.imageUrl!),
                          fit: BoxFit.cover)
                      : null,
                ),
                child: product.imageUrl == null
                    ? const Icon(Icons.inventory_2_outlined,
                        color: AppColors.textTertiary)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: AppTypography.h4),
                    Text('SKU: ${product.sku}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    Row(
                      children: [
                        Text('\$${product.sellingPrice.toStringAsFixed(2)}',
                            style: AppTypography.labelLarge),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: product.isOutOfStock
                                ? AppColors.error.withValues(alpha: 0.12)
                                : product.isLowStock
                                    ? AppColors.warning.withValues(alpha: 0.12)
                                    : AppColors.success.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusFull),
                          ),
                          child: Text(
                            '${product.quantity} in stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: product.isOutOfStock
                                  ? AppColors.error
                                  : product.isLowStock
                                      ? AppColors.warning
                                      : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xxl),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Sell Now',
                  icon: Icons.point_of_sale_rounded,
                  onPressed: product.isOutOfStock ? null : onSell,
                  height: 44,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'Restock',
                  icon: Icons.add_box_outlined,
                  isOutlined: true,
                  onPressed: onRestock,
                  height: 44,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Adjust',
                  icon: Icons.tune_rounded,
                  isOutlined: true,
                  onPressed: onAdjust,
                  height: 44,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: 'View Detail',
                  icon: Icons.info_outline_rounded,
                  isOutlined: true,
                  onPressed: onViewDetail,
                  height: 44,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: isActive
              ? Border.all(color: AppColors.primary, width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? AppColors.primaryLight : AppColors.white,
                size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? AppColors.primaryLight : AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
