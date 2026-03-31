import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/app_user.dart';
import '../controllers/auth_controller.dart';

/// Registration screen matching Figma: "Join ShopManager",
/// 4 account type cards, name/email/phone/password, coral Create Account button
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _signupRoles = [UserRole.admin, UserRole.sales];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  UserRole _selectedRole = UserRole.admin;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authControllerProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
        );

    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSizes.screenPaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.xxl),

                // ── Back Button ──
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Icon(Icons.arrow_back_rounded, size: 24),
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Title ──
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Create Account',
                        style: AppTypography.h2,
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        'Join ShopManager',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Account Type Label ──
                Text(
                  'Account Type',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.md),

                // ── Account Type Selector ──
                Row(
                  children: _signupRoles.map((role) {
                    final isSelected = _selectedRole == role;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = role),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primarySurface
                                : AppColors.inputFill,
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusMd),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _roleIcon(role),
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textTertiary,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _signupRoleLabel(role),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Full Name ──
                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(v, 'Name'),
                  prefixIcon:
                      const Icon(Icons.person_outline_rounded, size: 20),
                ),
                const SizedBox(height: AppSizes.lg),

                // ── Email ──
                AppTextField(
                  label: 'Email Address',
                  hint: 'name@example.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                ),
                const SizedBox(height: AppSizes.lg),

                // ── Phone ──
                AppTextField(
                  label: 'Phone Number',
                  hint: '+2348036129622',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                ),
                const SizedBox(height: AppSizes.lg),

                // ── Password ──
                AppTextField(
                  label: 'Password',
                  hint: '••••••••',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  validator: Validators.password,
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                const SizedBox(height: AppSizes.xxxl),

                // ── Create Account Button (coral from Figma) ──
                AppButton(
                  label: 'Create Account',
                  isLoading: authState.isLoading,
                  onPressed: _onRegister,
                  backgroundColor: AppColors.coral,
                ),
                const SizedBox(height: AppSizes.xxl),

                // ── Already Have Account ──
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Text(
                          'Sign In',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_outlined;
      case UserRole.sales:
        return Icons.point_of_sale_rounded;
      case UserRole.warehouse:
        return Icons.warehouse_outlined;
      case UserRole.manager:
        return Icons.manage_accounts_outlined;
    }
  }

  String _signupRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.sales:
        return 'Operator';
      case UserRole.warehouse:
      case UserRole.manager:
        return role.displayName;
    }
  }
}
