import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _shopNameController;
  bool _initialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  void _initControllers() {
    if (_initialized) return;
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phoneNumber ?? '');
    _shopNameController = TextEditingController(text: user?.shopName ?? '');
    _initialized = true;
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final success =
        await ref.read(authControllerProvider.notifier).updateUserProfile(
              displayName: _nameController.text.trim(),
              phoneNumber: _phoneController.text.trim(),
              shopName: _shopNameController.text.trim(),
            );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _onDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        ),
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authControllerProvider.notifier).signOut();
              context.go('/login');
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();
    final user = ref.watch(currentUserProvider);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, state) {
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(authControllerProvider.notifier).clearError();
      }
    });

    final initials = (user?.displayName.isNotEmpty == true
            ? user!.displayName
            : 'U')[0]
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.store_rounded,
                color: AppColors.textPrimary, size: 24),
          ),
        ),
        title: Text('Edit Profile', style: AppTypography.h3),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authControllerProvider.notifier).signOut();
                context.go('/login');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: AppSizes.xxl),

              // ── Avatar Section ──
              Center(
                child: Column(
                  children: [
                    // Avatar with camera button
                    Stack(
                      children: [
                        // Outer ring
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primaryLight
                                  .withValues(alpha: 0.4),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: user?.photoUrl != null &&
                                    user!.photoUrl!.isNotEmpty
                                ? CircleAvatar(
                                    radius: 54,
                                    backgroundImage:
                                        NetworkImage(user.photoUrl!),
                                  )
                                : CircleAvatar(
                                    radius: 54,
                                    backgroundColor:
                                        AppColors.primarySurface,
                                    child: Text(
                                      initials,
                                      style: AppTypography.h1.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 40,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        // Camera button
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              // Photo picker — placeholder for now
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Photo upload coming soon'),
                                  backgroundColor: AppColors.info,
                                ),
                              );
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.lg),

                    // Name
                    Text(
                      user?.displayName.isNotEmpty == true
                          ? user!.displayName
                          : 'User',
                      style: AppTypography.h2,
                    ),
                    const SizedBox(height: AppSizes.sm),

                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius:
                            BorderRadius.circular(AppSizes.radiusFull),
                      ),
                      child: Text(
                        user?.role.displayName.toUpperCase() ?? 'USER',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xxxl),

              // ── Form Fields ──
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenPaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full Name
                    _ProfileFieldLabel(label: 'FULL NAME'),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(
                      controller: _nameController,
                      hint: 'Enter your full name',
                      validator: (v) => Validators.required(v, 'Name'),
                      textInputAction: TextInputAction.next,
                      suffixIcon: const Icon(Icons.person_rounded,
                          size: 20, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: AppSizes.xxl),

                    // Email (read-only)
                    _ProfileFieldLabel(label: 'EMAIL ADDRESS'),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(
                      controller: _emailController,
                      hint: 'Email',
                      readOnly: true,
                      enabled: false,
                      suffixIcon: const Icon(Icons.alternate_email,
                          size: 20, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: AppSizes.xxl),

                    // Phone Number
                    _ProfileFieldLabel(label: 'PHONE NUMBER'),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(
                      controller: _phoneController,
                      hint: '+2348136129622',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        // Phone is optional — only validate if non-empty
                        if (v == null || v.trim().isEmpty) return null;
                        return Validators.phone(v);
                      },
                      suffixIcon: const Icon(Icons.phone_rounded,
                          size: 20, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: AppSizes.xxl),

                    // Shop Name
                    _ProfileFieldLabel(label: 'SHOP NAME'),
                    const SizedBox(height: AppSizes.sm),
                    AppTextField(
                      controller: _shopNameController,
                      hint: 'Your shop name',
                      textInputAction: TextInputAction.done,
                      validator: (v) =>
                          Validators.required(v, 'Shop Name'),
                      suffixIcon: const Icon(Icons.store_rounded,
                          size: 20, color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: AppSizes.xxxl),

                    // ── Save Changes Button ──
                    AppButton(
                      label: 'Save Changes',
                      isLoading: authState.isLoading,
                      onPressed: _onSave,
                      icon: Icons.check_circle,
                      backgroundColor: AppColors.primaryDark,
                    ),
                    const SizedBox(height: AppSizes.xxxl),

                    // ── Delete Account ──
                    Center(
                      child: GestureDetector(
                        onTap: _onDeleteAccount,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(Icons.close,
                                  size: 14, color: AppColors.white),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Account',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.huge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section label styled like the Figma design (uppercase, muted)
class _ProfileFieldLabel extends StatelessWidget {
  final String label;

  const _ProfileFieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}
