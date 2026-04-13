import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/scanner_route_access.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../inventory/presentation/controllers/inventory_controller.dart';
import '../../../inventory/domain/entities/product.dart';
import '../controllers/scanner_controller.dart';

/// Scanner screen with live camera barcode scanning:
/// - Camera permission handling
/// - Flashlight toggle
/// - Manual barcode entry
/// - Debounced scan detection
/// - Product lookup (cache-first via Firestore offline)
/// - Inline quick-sell and restock flows with atomic transactions
/// - Scan history persistence
class ScannerScreen extends ConsumerStatefulWidget {
  final String? reason;

  const ScannerScreen({super.key, this.reason});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController? _cameraController;
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 800));
  bool _isProcessing = false;
  bool _torchEnabled = false;
  String? _lastScannedCode;
  ScanIntent? _selectedIntent;

  // Camera permission state
  _CameraPermState _permState = _CameraPermState.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkCameraPermission();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.reason == 'restricted') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Use scanner flow to open Add Product or New Sale pages.'),
            backgroundColor: AppColors.warning,
          ),
        );
        context.replace('/scanner');
      }

      if (mounted && _selectedIntent == null) {
        _selectScanIntent();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permission when returning from settings
    if (state == AppLifecycleState.resumed &&
        _permState == _CameraPermState.permanentlyDenied) {
      _checkCameraPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debouncer.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _checkCameraPermission() async {
    setState(() => _permState = _CameraPermState.checking);

    var status = await Permission.camera.status;

    if (status.isGranted) {
      _initCamera();
      return;
    }

    if (status.isPermanentlyDenied) {
      setState(() => _permState = _CameraPermState.permanentlyDenied);
      return;
    }

    // Request permission
    status = await Permission.camera.request();

    if (status.isGranted) {
      _initCamera();
    } else if (status.isPermanentlyDenied) {
      setState(() => _permState = _CameraPermState.permanentlyDenied);
    } else {
      setState(() => _permState = _CameraPermState.denied);
    }
  }

  void _initCamera() {
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    setState(() => _permState = _CameraPermState.granted);
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isProcessing || _selectedIntent == null) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Debounce repeated scans of the same code
    if (code == _lastScannedCode) return;

    _debouncer.run(() => _processBarcode(code));
  }

  Future<void> _processBarcode(String barcode) async {
    if (_isProcessing) return;

    final selectedIntent = _selectedIntent;
    if (selectedIntent == null) {
      _showIntentRequiredSnackBar();
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScannedCode = barcode;
    });

    if (selectedIntent == ScanIntent.addProduct) {
      // Save scan history (unmatched — we're creating a new product)
      ref.read(scannerControllerProvider.notifier).saveScanEntry(
            barcodeValue: barcode,
            scanIntent: 'addProduct',
          );

      if (!mounted) return;
      ref
          .read(scannerRouteAccessProvider.notifier)
          .grant(ScannerProtectedRoute.addProduct);
      context.push('/inventory/add?barcode=$barcode');
      setState(() => _isProcessing = false);
      return;
    }

    // Sale intent: look up product
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

      // Save scan history
      ref.read(scannerControllerProvider.notifier).saveScanEntry(
            barcodeValue: barcode,
            scanIntent: 'sale',
            matchedProductId: product?.id,
            matchedProductName: product?.name,
          );

      if (product != null) {
        _showProductFoundSheet(product, barcode);
      } else {
        _showProductNotFoundSheet(barcode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Lookup error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ── Product Found Sheet ──

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
          _showQuickSellSheet(product);
        },
        onRestock: () {
          Navigator.pop(ctx);
          _showRestockSheet(product);
        },
        onAdjust: () {
          Navigator.pop(ctx);
          _showStockAdjustDialog(product);
        },
        onViewHistory: () {
          Navigator.pop(ctx);
          context.push('/transaction-logs');
        },
      ),
    );
  }

  // ── Product Not Found Sheet ──

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
                ref
                    .read(scannerRouteAccessProvider.notifier)
                    .grant(ScannerProtectedRoute.addProduct);
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

  // ── Quick Sell Sheet ──

  void _showQuickSellSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickSellSheet(
        product: product,
        onConfirm: (quantity) async {
          Navigator.pop(ctx);
          final success =
              await ref.read(scannerControllerProvider.notifier).sellProduct(
                    productId: product.id,
                    productName: product.name,
                    productSku: product.sku,
                    unitPrice: product.sellingPrice,
                    quantity: quantity,
                  );
          if (mounted) {
            final state = ref.read(scannerControllerProvider);
            _showResultSnackBar(state.message ?? '', success);
            ref.read(scannerControllerProvider.notifier).reset();
            setState(() => _lastScannedCode = null);
          }
        },
      ),
    );
  }

  // ── Restock Sheet ──

  void _showRestockSheet(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RestockSheet(
        product: product,
        onConfirm: (quantity, note, supplier) async {
          Navigator.pop(ctx);
          final success = await ref
              .read(scannerControllerProvider.notifier)
              .restockProduct(
                productId: product.id,
                productName: product.name,
                quantity: quantity,
                note: note,
                supplier: supplier,
              );
          if (mounted) {
            final state = ref.read(scannerControllerProvider);
            _showResultSnackBar(state.message ?? '', success);
            ref.read(scannerControllerProvider.notifier).reset();
            setState(() => _lastScannedCode = null);
          }
        },
      ),
    );
  }

  // ── Stock Adjust Dialog ──

  void _showStockAdjustDialog(Product product) {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
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
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. damaged, miscounted',
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
                final success = await ref
                    .read(scannerControllerProvider.notifier)
                    .adjustStock(
                      productId: product.id,
                      productName: product.name,
                      quantityChange: qty,
                      reason: reasonController.text.trim().isEmpty
                          ? null
                          : reasonController.text.trim(),
                    );
                if (mounted) {
                  final state = ref.read(scannerControllerProvider);
                  _showResultSnackBar(state.message ?? '', success);
                  ref.read(scannerControllerProvider.notifier).reset();
                  setState(() => _lastScannedCode = null);
                }
              }
            },
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  // ── Manual Entry Dialog ──

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

  // ── Intent Selection ──

  Future<void> _selectScanIntent() async {
    final selected = await showModalBottomSheet<ScanIntent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ScanIntentSheet(initialIntent: _selectedIntent),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedIntent = selected;
        _lastScannedCode = null;
      });
    }
  }

  void _showIntentRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select scan purpose first: Add Product or New Sale.'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  void _showResultSnackBar(String message, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Permission states
    if (_permState == _CameraPermState.checking) {
      return const Scaffold(
        backgroundColor: AppColors.scannerDark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      );
    }

    if (_permState == _CameraPermState.denied ||
        _permState == _CameraPermState.permanentlyDenied) {
      return _CameraPermissionView(
        isPermanent: _permState == _CameraPermState.permanentlyDenied,
        onRequestPermission: _checkCameraPermission,
        onOpenSettings: () => openAppSettings(),
        onBack: () => context.go('/dashboard'),
      );
    }

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
                    Text(
                        _selectedIntent == ScanIntent.addProduct
                            ? 'Scan for New Product'
                            : _selectedIntent == ScanIntent.newSale
                                ? 'Scan for New Sale'
                                : 'Select Scan Purpose',
                        style:
                            AppTypography.h4.copyWith(color: AppColors.white)),
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

          // ── Processing indicator ──
          if (_isProcessing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLight,
                    strokeWidth: 3,
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
                    _selectedIntent == ScanIntent.addProduct
                        ? 'Scanned code will open New Product form'
                        : _selectedIntent == ScanIntent.newSale
                            ? 'Identify Product for a New Sale'
                            : 'Choose what this scan is for',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.md),

                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: _selectedIntent == null
                          ? 'Select Scan Purpose'
                          : 'Change Scan Purpose',
                      icon: Icons.swap_horiz_rounded,
                      isOutlined: true,
                      onPressed: _selectScanIntent,
                    ),
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
                          icon: Icons.add_box_rounded,
                          label: 'Add Product',
                          isActive: _selectedIntent == ScanIntent.addProduct,
                          onTap: () {
                            setState(() {
                              _selectedIntent = ScanIntent.addProduct;
                              _lastScannedCode = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: _BottomActionButton(
                          icon: Icons.point_of_sale_rounded,
                          label: 'New Sale',
                          isActive: _selectedIntent == ScanIntent.newSale,
                          onTap: () {
                            setState(() {
                              _selectedIntent = ScanIntent.newSale;
                              _lastScannedCode = null;
                            });
                          },
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

// ═══════════════════════════════════════════════════════════════
// Camera Permission State
// ═══════════════════════════════════════════════════════════════

enum _CameraPermState { checking, granted, denied, permanentlyDenied }

class _CameraPermissionView extends StatelessWidget {
  final bool isPermanent;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onBack;

  const _CameraPermissionView({
    required this.isPermanent,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scannerDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.warning, size: 40),
              ),
              const SizedBox(height: AppSizes.xxl),
              Text(
                'Camera Permission Required',
                style: AppTypography.h3.copyWith(color: AppColors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                isPermanent
                    ? 'Camera access has been permanently denied. Please enable it in your device settings to use the scanner.'
                    : 'Inventra needs camera access to scan barcodes and QR codes for product identification.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xxxl),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: isPermanent ? 'Open Settings' : 'Grant Permission',
                  icon: isPermanent
                      ? Icons.settings_rounded
                      : Icons.check_circle_outline_rounded,
                  onPressed:
                      isPermanent ? onOpenSettings : onRequestPermission,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: 'Go Back',
                  isOutlined: true,
                  foregroundColor: AppColors.white,
                  onPressed: onBack,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Scan Intent
// ═══════════════════════════════════════════════════════════════

enum ScanIntent { addProduct, newSale }

class _ScanIntentSheet extends StatelessWidget {
  final ScanIntent? initialIntent;

  const _ScanIntentSheet({this.initialIntent});

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xl),
          Text('What is this scan for?', style: AppTypography.h4),
          const SizedBox(height: AppSizes.sm),
          Text(
            'Choose one option before scanning.',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSizes.xl),
          _IntentOptionTile(
            icon: Icons.add_box_rounded,
            title: 'Add New Product',
            subtitle: 'Open product form with scanned barcode pre-filled.',
            isActive: initialIntent == ScanIntent.addProduct,
            onTap: () => Navigator.pop(context, ScanIntent.addProduct),
          ),
          const SizedBox(height: AppSizes.md),
          _IntentOptionTile(
            icon: Icons.point_of_sale_rounded,
            title: 'Create New Sale',
            subtitle: 'Lookup product and continue to sale flow.',
            isActive: initialIntent == ScanIntent.newSale,
            onTap: () => Navigator.pop(context, ScanIntent.newSale),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
        ],
      ),
    );
  }
}

class _IntentOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  const _IntentOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.divider,
              width: isActive ? 1.8 : 1,
            ),
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.08)
                : AppColors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.16)
                      : AppColors.inputFill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTypography.labelLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Scan Overlay
// ═══════════════════════════════════════════════════════════════

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
    canvas.drawRect(Rect.fromLTWH(0, top, left, scanAreaSize), overlayPaint);
    canvas.drawRect(Rect.fromLTWH(left + scanAreaSize, top, left, scanAreaSize),
        overlayPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, top + scanAreaSize, size.width,
            size.height - top - scanAreaSize),
        overlayPaint);

    // Scan frame corners
    const cornerLength = 30.0;
    final paint = Paint()
      ..color = isProcessing ? AppColors.primaryLight : AppColors.scannerBlue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
        scanRect.topLeft, scanRect.topLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(
        scanRect.topLeft, scanRect.topLeft + const Offset(0, cornerLength), paint);

    // Top-right
    canvas.drawLine(
        scanRect.topRight, scanRect.topRight + const Offset(-cornerLength, 0), paint);
    canvas.drawLine(
        scanRect.topRight, scanRect.topRight + const Offset(0, cornerLength), paint);

    // Bottom-left
    canvas.drawLine(scanRect.bottomLeft,
        scanRect.bottomLeft + const Offset(cornerLength, 0), paint);
    canvas.drawLine(scanRect.bottomLeft,
        scanRect.bottomLeft + const Offset(0, -cornerLength), paint);

    // Bottom-right
    canvas.drawLine(scanRect.bottomRight,
        scanRect.bottomRight + const Offset(-cornerLength, 0), paint);
    canvas.drawLine(scanRect.bottomRight,
        scanRect.bottomRight + const Offset(0, -cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) =>
      oldDelegate.isProcessing != isProcessing;
}

// ═══════════════════════════════════════════════════════════════
// Product Found Sheet
// ═══════════════════════════════════════════════════════════════

class _ProductFoundSheet extends StatelessWidget {
  final Product product;
  final String barcode;
  final VoidCallback onSell;
  final VoidCallback onRestock;
  final VoidCallback onAdjust;
  final VoidCallback onViewHistory;

  const _ProductFoundSheet({
    required this.product,
    required this.barcode,
    required this.onSell,
    required this.onRestock,
    required this.onAdjust,
    required this.onViewHistory,
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
                    if (product.barcode != null)
                      Text('Barcode: ${product.barcode}',
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.textSecondary)),
                    Row(
                      children: [
                        Text(Formatters.currency(product.sellingPrice),
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
                  label: 'History',
                  icon: Icons.history_rounded,
                  isOutlined: true,
                  onPressed: onViewHistory,
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

// ═══════════════════════════════════════════════════════════════
// Quick Sell Sheet
// ═══════════════════════════════════════════════════════════════

class _QuickSellSheet extends StatefulWidget {
  final Product product;
  final Future<void> Function(int quantity) onConfirm;

  const _QuickSellSheet({
    required this.product,
    required this.onConfirm,
  });

  @override
  State<_QuickSellSheet> createState() => _QuickSellSheetState();
}

class _QuickSellSheetState extends State<_QuickSellSheet> {
  int _quantity = 1;
  bool _isProcessing = false;

  bool get _canSell => _quantity <= widget.product.quantity && _quantity > 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.product.sellingPrice * _quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSizes.xxl,
          AppSizes.xxl,
          AppSizes.xxl,
          MediaQuery.of(context).padding.bottom + AppSizes.lg),
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
          const SizedBox(height: AppSizes.xl),

          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.point_of_sale_rounded,
                    color: AppColors.coral, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Sale', style: AppTypography.h4),
                    Text(widget.product.name,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xxl),

          // Stock info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Available Stock',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
                Text('${widget.product.quantity} ${widget.product.unit}',
                    style: AppTypography.labelLarge),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // Quantity picker
          Text('Quantity', style: AppTypography.labelLarge),
          const SizedBox(height: AppSizes.md),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _QtyButton(
                  icon: Icons.remove_rounded,
                  onTap: _quantity > 1
                      ? () => setState(() => _quantity--)
                      : null,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_quantity',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    Text(widget.product.unit,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textTertiary)),
                  ],
                ),
                _QtyButton(
                  icon: Icons.add_rounded,
                  onTap: _quantity < widget.product.quantity
                      ? () => setState(() => _quantity++)
                      : null,
                ),
              ],
            ),
          ),

          // Insufficient stock warning
          if (!_canSell && _quantity > 0) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_rounded,
                    color: AppColors.error, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Exceeds available stock',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.error),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSizes.xxl),

          // Price summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Unit Price', style: AppTypography.bodyMedium),
                    Text(Formatters.currency(widget.product.sellingPrice),
                        style: AppTypography.labelMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Quantity', style: AppTypography.bodyMedium),
                    Text('×$_quantity', style: AppTypography.labelMedium),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total',
                        style: AppTypography.h4
                            .copyWith(color: AppColors.primaryDark)),
                    Text(Formatters.currency(total),
                        style: AppTypography.h3
                            .copyWith(color: AppColors.primaryDark)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.xl),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _isProcessing
                  ? 'Processing...'
                  : 'Confirm Sale — ${Formatters.currency(total)}',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isProcessing,
              onPressed: _canSell && !_isProcessing
                  ? () async {
                      setState(() => _isProcessing = true);
                      await widget.onConfirm(_quantity);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Restock Sheet
// ═══════════════════════════════════════════════════════════════

class _RestockSheet extends StatefulWidget {
  final Product product;
  final Future<void> Function(int quantity, String? note, String? supplier)
      onConfirm;

  const _RestockSheet({
    required this.product,
    required this.onConfirm,
  });

  @override
  State<_RestockSheet> createState() => _RestockSheetState();
}

class _RestockSheetState extends State<_RestockSheet> {
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  final _supplierController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _noteController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.fromLTRB(
            AppSizes.xxl,
            AppSizes.xxl,
            AppSizes.xxl,
            MediaQuery.of(context).padding.bottom + AppSizes.lg),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.xl),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_box_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Restock', style: AppTypography.h4),
                        Text(widget.product.name,
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),

              // Current stock
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current Stock',
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.textSecondary)),
                    Text(
                        '${widget.product.quantity} ${widget.product.unit}',
                        style: AppTypography.labelLarge),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),

              // Quantity
              Text('Quantity to Add', style: AppTypography.labelLarge),
              const SizedBox(height: AppSizes.sm),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter quantity',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Supplier
              Text('Supplier (Optional)', style: AppTypography.labelLarge),
              const SizedBox(height: AppSizes.sm),
              TextField(
                controller: _supplierController,
                decoration: InputDecoration(
                  hintText: 'e.g. ABC Distributors',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: AppSizes.lg),

              // Note
              Text('Note (Optional)', style: AppTypography.labelLarge),
              const SizedBox(height: AppSizes.sm),
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'e.g. Weekly restock from supplier',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: AppSizes.xxl),

              // Confirm
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: _isProcessing ? 'Processing...' : 'Confirm Restock',
                  icon: Icons.check_circle_outline_rounded,
                  isLoading: _isProcessing,
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          final qty = int.tryParse(_qtyController.text);
                          if (qty == null || qty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Enter a valid quantity'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }
                          setState(() => _isProcessing = true);
                          final note = _noteController.text.trim().isEmpty
                              ? null
                              : _noteController.text.trim();
                          final supplier =
                              _supplierController.text.trim().isEmpty
                                  ? null
                                  : _supplierController.text.trim();
                          await widget.onConfirm(qty, note, supplier);
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

// ═══════════════════════════════════════════════════════════════
// Quantity Button
// ═══════════════════════════════════════════════════════════════

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: enabled ? AppColors.inputFill : AppColors.divider,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Bottom Action Button
// ═══════════════════════════════════════════════════════════════

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
