import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_service.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';
import '../../customer/home/presentation/customer_main_screen.dart';
import '../../driver/home/presentation/driver_main_screen.dart';
import 'customer_registration_screen.dart';
import 'driver_registration_screen.dart';

class UnifiedLoginScreen extends StatefulWidget {
  final UserRole initialRole;
  const UnifiedLoginScreen({super.key, this.initialRole = UserRole.customer});

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  late UserRole _selectedRole;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập Email, Tên đăng nhập hoặc Số điện thoại');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập mật khẩu');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AuthService.login(
        emailOrUsername: email,
        password: password,
        selectedRole: _selectedRole,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => ApiResponse(
          isSuccess: false,
          errorMessage: 'Hết thời gian phản hồi máy chủ. Vui lòng kiểm tra lại kết nối mạng hoặc thử lại.',
        ),
      );

      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        final user = result.data!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đăng nhập thành công! Xin chào ${user.name}'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );

        final UserRole finalRole;
        if (user.role == UserRole.admin) {
          finalRole = UserRole.admin;
        } else if (_selectedRole == UserRole.driver || user.role == UserRole.driver) {
          finalRole = UserRole.driver;
        } else {
          finalRole = UserRole.customer;
        }
        final finalUser = user.copyWith(role: finalRole);
        await AuthService.saveSession(finalUser, syncCloud: false);

        if (!mounted) return;

        if (finalRole == UserRole.admin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => AdminDashboardScreen(adminUser: finalUser)),
          );
        } else if (finalRole == UserRole.driver) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DriverMainScreen(user: finalUser)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => CustomerMainScreen(user: finalUser)),
          );
        }
      } else {
        setState(() {
          _errorMessage = result.errorMessage ?? 'Đăng nhập không thành công. Vui lòng kiểm tra lại.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối ($e). Vui lòng kiểm tra lại mạng.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDriver = _selectedRole == UserRole.driver;
    final isAdmin = _selectedRole == UserRole.admin;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Role Switcher Segment
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRole = UserRole.customer;
                          _errorMessage = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !isDriver ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: !isDriver
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 18,
                                color: !isDriver ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Khách hàng',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: !isDriver ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRole = UserRole.driver;
                          _errorMessage = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isDriver ? AppColors.accent : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isDriver
                                ? [
                                    BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.motorcycle_rounded,
                                size: 18,
                                color: isDriver ? Colors.white : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Đối tác Tài xế',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isDriver ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Brand Icon & Badge
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (isDriver ? AppColors.accent : AppColors.primary).withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: (isDriver ? AppColors.accent : AppColors.primary).withValues(alpha: 0.12),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/goship_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDriver ? 'GoShip Driver' : 'GoShip',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDriver ? AppColors.accent : AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (isDriver)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DÀNH CHO TÀI XẾ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Welcome Headers
              Text(
                isDriver ? 'Xin chào Đối tác!' : 'Xin chào!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDriver
                    ? 'Đăng nhập bằng Email hoặc Số điện thoại để bắt đầu nhận đơn.'
                    : 'Đăng nhập bằng Email hoặc Số điện thoại để trải nghiệm giao hàng thông minh.',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 32),

              // Gmail / Email / Phone Input
              const Text(
                'Email hoặc Số điện thoại',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Nhập Email hoặc Số điện thoại',
                  prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 20),

              // Password Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mật khẩu',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng liên hệ quản trị viên hoặc sử dụng tính năng quên mật khẩu.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Text(
                      'Quên mật khẩu?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDriver ? AppColors.accent : AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Nhập mật khẩu của bạn',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Submit Login Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAdmin
                        ? const Color(0xFF0F172A)
                        : (isDriver ? AppColors.accent : AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          isAdmin
                              ? 'Truy cập Cổng Quản trị (Admin)'
                              : (isDriver ? 'Đăng nhập Đối tác Tài xế' : 'Đăng nhập Khách hàng'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              if (!isAdmin)
                Center(
                  child: TextButton(
                    onPressed: () {
                      if (isDriver) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DriverRegistrationScreen()),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CustomerRegistrationScreen()),
                        );
                      }
                    },
                    child: RichText(
                      text: TextSpan(
                        text: isDriver ? 'Chưa có tài khoản đối tác? ' : 'Chưa có tài khoản GoShip? ',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Đăng ký ngay',
                            style: TextStyle(
                              color: isDriver ? AppColors.accent : AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 12),

              // Discrete & Professional Admin Portal Entry on Mobile
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isAdmin ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isAdmin ? const Color(0xFF2563EB) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            size: 18,
                            color: isAdmin ? Colors.white : const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cổng Quản trị Vận hành (Admin)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isAdmin ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                isAdmin
                                    ? 'Chế độ Admin đang bật • Tài khoản: admin / admin123'
                                    : 'Dành cho Ban quản trị điều phối đội xe & bảng giá',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isAdmin ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: isAdmin ? const Color(0xFF2563EB) : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isAdmin ? Colors.transparent : const Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedRole = UserRole.admin;
                              _emailController.text = 'admin';
                              _passwordController.text = 'admin123';
                              _errorMessage = null;
                            });
                            _handleLogin();
                          },
                          child: Text(
                            'Vào Admin',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isAdmin ? Colors.white : const Color(0xFF2563EB),
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
        ),
      ),
    );
  }
}
