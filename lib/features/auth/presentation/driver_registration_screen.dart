import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../driver/home/presentation/driver_main_screen.dart';
import '../data/auth_service.dart';

class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _DriverRegistrationScreenState();
}

class _DriverRegistrationScreenState extends State<DriverRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _plateController = TextEditingController();
  final _cccdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedVehicleType = 'Xe Bán tải';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = true;
  bool _isLoading = false;

  static const List<Map<String, String>> _vehicleOptions = [
    {'name': 'Xe Bán tải', 'desc': 'Tải trọng 500kg • Lọt lòng 1.5x1.2x0.9m'},
    {'name': 'Xe van', 'desc': 'Tải trọng 1000kg • Lọt lòng 2.1x1.3x1.3m'},
    {'name': 'Xe tải', 'desc': 'Tải trọng 2500kg • Lọt lòng 3.5x1.8x1.8m'},
    {'name': 'Container', 'desc': 'Tải trọng 10 tấn • Vận tải công nghiệp'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _plateController.dispose();
    _cccdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đồng ý với Quy tắc ứng xử & Điều khoản đối tác Tài xế GoShip.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final cleanPhone = _phoneController.text.trim();
    final newDriver = UserModel(
      id: 'drv_$cleanPhone',
      name: _nameController.text.trim(),
      phone: cleanPhone,
      email: _emailController.text.trim(),
      role: UserRole.driver,
      plateNumber: _plateController.text.trim().toUpperCase(),
      vehicleType: _selectedVehicleType,
      cccd: _cccdController.text.trim(),
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      rating: 5.0,
      totalOrders: 0,
      accountStatus: 'pending_approval',
    );

    final result = await AuthService.registerUser(
      user: newDriver,
      password: _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Đăng ký không thành công.'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final registeredDriver = result.data ?? newDriver;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đăng ký Đối tác thành công! Đã kích hoạt Ví Ký quỹ cho ${registeredDriver.name}.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => DriverMainScreen(user: registeredDriver)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Đăng ký Đối tác Tài xế',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gia nhập Đội ngũ Tài xế GoShip',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Nhận đơn tự động 85% chiết khấu cước, đồng bộ tài khoản & ví thu nhập trên mọi thiết bị',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),

                // Họ và tên
                const Text('Họ và tên Tài xế', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
                  decoration: const InputDecoration(
                    hintText: 'Nhập họ và tên trên GPLX / CCCD',
                    prefixIcon: Icon(Icons.badge_outlined, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),

                // Số điện thoại & CCCD
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Số điện thoại', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            validator: (val) => val == null || val.trim().length < 9 ? 'SĐT không hợp lệ' : null,
                            decoration: const InputDecoration(
                              hintText: '090xxxxxxx',
                              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Số CCCD (12 số)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _cccdController,
                            keyboardType: TextInputType.number,
                            validator: (val) => val == null || val.trim().length < 9 ? 'Nhập số CCCD' : null,
                            decoration: const InputDecoration(
                              hintText: '0792xxxxxxxx',
                              prefixIcon: Icon(Icons.credit_card_outlined, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Email
                const Text('Địa chỉ Email', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (val) => val == null || !val.contains('@') ? 'Email không hợp lệ' : null,
                  decoration: const InputDecoration(
                    hintText: 'Nhập địa chỉ Email liên hệ',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),

                // Loại phương tiện & Biển kiểm soát
                const Text('Loại phương tiện đăng ký chạy đơn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedVehicleType,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.local_shipping_outlined, color: AppColors.accent),
                  ),
                  items: _vehicleOptions
                      .map(
                        (v) => DropdownMenuItem<String>(
                          value: v['name'],
                          child: Text('${v['name']} (${v['desc']})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedVehicleType = val);
                  },
                ),
                const SizedBox(height: 14),

                const Text('Biển kiểm soát xe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  validator: (val) => val == null || val.trim().length < 5 ? 'Vui lòng nhập biển kiểm soát xe' : null,
                  decoration: const InputDecoration(
                    hintText: 'VD: 51D-892.14 hoặc 59C-123.45',
                    prefixIcon: Icon(Icons.pin_outlined, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 14),

                // Mật khẩu
                const Text('Mật khẩu đăng nhập', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (val) => val == null || val.length < 6 ? 'Mật khẩu phải từ 6 ký tự' : null,
                  decoration: InputDecoration(
                    hintText: 'Nhập mật khẩu',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Xác nhận mật khẩu
                const Text('Xác nhận mật khẩu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  validator: (val) => val != _passwordController.text ? 'Mật khẩu xác nhận không khớp' : null,
                  decoration: InputDecoration(
                    hintText: 'Nhập lại mật khẩu',
                    prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Checkbox(
                      value: _agreeTerms,
                      activeColor: AppColors.accent,
                      onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Tôi cam kết thông tin phương tiện chính xác và đồng ý với Quy chế Đối tác Tài xế GoShip',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'Đăng ký & Kích hoạt Ví Tài xế',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
