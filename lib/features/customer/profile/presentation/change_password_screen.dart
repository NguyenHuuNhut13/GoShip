import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  final UserModel user;
  const ChangePasswordScreen({super.key, required this.user});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _hasConfirmedCopiedAndRemembered = false;

  // Random Password Generator States
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecial = true;
  double _passwordLength = 16.0;
  String _generatedPassword = '';

  @override
  void initState() {
    super.initState();
    _generateRandomPassword();
  }

  @override
  void dispose() {
    _oldPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _generateRandomPassword() {
    const String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String lower = 'abcdefghijklmnopqrstuvwxyz';
    const String digits = '0123456789';
    const String special = '!@#\$%^&*()-_=+[]{}|;:,.<>?';

    String pool = '';
    if (_includeUppercase) pool += upper;
    if (_includeLowercase) pool += lower;
    if (_includeNumbers) pool += digits;
    if (_includeSpecial) pool += special;

    if (pool.isEmpty) {
      pool = lower + digits; // Fallback
    }

    final random = Random.secure();
    final length = _passwordLength.round();
    final chars = List.generate(length, (_) => pool[random.nextInt(pool.length)]);

    setState(() {
      _generatedPassword = chars.join();
      _hasConfirmedCopiedAndRemembered = false;
    });
  }

  void _applyGeneratedPassword() {
    Clipboard.setData(ClipboardData(text: _generatedPassword));
    setState(() {
      _newPassController.text = _generatedPassword;
      _confirmPassController.text = _generatedPassword;
      _obscureNew = false;
      _obscureConfirm = false;
      _hasConfirmedCopiedAndRemembered = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép và áp dụng mật khẩu vào form! Vui lòng tích xác nhận đã lưu mật khẩu bên dưới để mở khóa.'),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final oldPass = _oldPassController.text.trim();
    final newPass = _newPassController.text.trim();

    final res = await ApiClient.updatePassword(
      currentUser: widget.user,
      oldPassword: oldPass,
      newPassword: newPass,
    );

    if (res.isSuccess) {
      await AuthService.updateCloudPassword(widget.user, newPass);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật mật khẩu thành công!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.errorMessage ?? 'Cập nhật mật khẩu thất bại'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          'Đổi mật khẩu',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notice banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Mật khẩu nên có độ dài từ 8-32 ký tự, kết hợp chữ hoa, chữ thường, số và ký hiệu đặc biệt để bảo mật tối đa.',
                        style: TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 1. Unified Main Password Form Card (Mật khẩu hiện tại, Mật khẩu mới, Xác nhận mật khẩu mới, Xác nhận đã sao chép/ghi nhớ)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Old Password
                    const Text(
                      'Mật khẩu hiện tại',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _oldPassController,
                      obscureText: _obscureOld,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập mật khẩu hiện tại';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu đang dùng',
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscureOld = !_obscureOld),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // New Password
                    const Text(
                      'Mật khẩu mới',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _newPassController,
                      obscureText: _obscureNew,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng nhập mật khẩu mới';
                        if (val.trim().length < 8) return 'Mật khẩu phải có ít nhất 8 ký tự';
                        if (val.trim().length > 32) return 'Mật khẩu tối đa 32 ký tự';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhập mật khẩu mới (8-32 ký tự)',
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(Icons.lock_reset_rounded, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscureNew = !_obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Confirm New Password
                    const Text(
                      'Xác nhận mật khẩu mới',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _confirmPassController,
                      obscureText: _obscureConfirm,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Vui lòng xác nhận mật khẩu mới';
                        if (val.trim() != _newPassController.text.trim()) return 'Mật khẩu xác nhận không khớp';
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhập lại mật khẩu mới',
                        fillColor: Colors.white,
                        filled: true,
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.textSecondary),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.border),
                    const SizedBox(height: 12),

                    // 4. Confirmation Checkbox (ngay dưới xác nhận mật khẩu)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _hasConfirmedCopiedAndRemembered = !_hasConfirmedCopiedAndRemembered;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _hasConfirmedCopiedAndRemembered,
                              activeColor: AppColors.success,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) {
                                setState(() {
                                  _hasConfirmedCopiedAndRemembered = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tôi xác nhận đã sao chép (copy) và ghi nhớ mật khẩu mới',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (!_hasConfirmedCopiedAndRemembered) ...[
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Nút cập nhật đang tạm khóa để đảm bảo bạn không bị mất quyền truy cập tài khoản.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. GENERATE RANDOM PASSWORD SECTION (Tạo mật khẩu ngẫu nhiên)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tạo mật khẩu ngẫu nhiên',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Generated Password Display Box (Full width, không bị xuống dòng)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: SelectableText(
                          _generatedPassword,
                          maxLines: 1,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Nút copy và làm mới ở dưới ô mật khẩu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _generatedPassword));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Đã sao chép mật khẩu vào bộ nhớ tạm!'),
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 4),
                                Text('Sao chép', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _generateRandomPassword,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 15, color: AppColors.accent),
                                SizedBox(width: 4),
                                Text('Làm mới', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Password Length Slider (Min 8, Max 32)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Độ dài mật khẩu (Min 8 - Max 32):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_passwordLength.round()} ký tự',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _passwordLength,
                      min: 8,
                      max: 32,
                      divisions: 24,
                      activeColor: AppColors.accent,
                      inactiveColor: AppColors.border,
                      label: '${_passwordLength.round()} ký tự',
                      onChanged: (val) {
                        setState(() => _passwordLength = val);
                        _generateRandomPassword();
                      },
                    ),

                    // Options Checkboxes (Hàng 2 2 thay vì 3 1)
                    const Text(
                      'Tùy chọn ký tự bao gồm:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),

                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterCheckbox(
                                label: 'Chữ hoa (A-Z)',
                                value: _includeUppercase,
                                onChanged: (val) {
                                  setState(() => _includeUppercase = val ?? true);
                                  _generateRandomPassword();
                                },
                              ),
                            ),
                            Expanded(
                              child: _buildFilterCheckbox(
                                label: 'Chữ thường (a-z)',
                                value: _includeLowercase,
                                onChanged: (val) {
                                  setState(() => _includeLowercase = val ?? true);
                                  _generateRandomPassword();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterCheckbox(
                                label: 'Chữ số (0-9)',
                                value: _includeNumbers,
                                onChanged: (val) {
                                  setState(() => _includeNumbers = val ?? true);
                                  _generateRandomPassword();
                                },
                              ),
                            ),
                            Expanded(
                              child: _buildFilterCheckbox(
                                label: 'Ký tự đặc biệt (!@#)',
                                value: _includeSpecial,
                                onChanged: (val) {
                                  setState(() => _includeSpecial = val ?? true);
                                  _generateRandomPassword();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Button Sử dụng mật khẩu này (ngắn gọn, bỏ icon mũi tên)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _applyGeneratedPassword,
                        child: const Text(
                          'Sử dụng mật khẩu này',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button (Tạm khóa nếu chưa xác nhận copy/nhớ mật khẩu)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasConfirmedCopiedAndRemembered ? AppColors.primary : Colors.grey.shade300,
                    foregroundColor: _hasConfirmedCopiedAndRemembered ? Colors.white : Colors.grey.shade600,
                    elevation: _hasConfirmedCopiedAndRemembered ? 2 : 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: (_isSaving || !_hasConfirmedCopiedAndRemembered) ? null : _handleSubmit,
                  icon: _isSaving
                      ? const SizedBox.shrink()
                      : Icon(
                          _hasConfirmedCopiedAndRemembered
                              ? Icons.check_circle_outline_rounded
                              : Icons.lock_outline_rounded,
                          size: 20,
                        ),
                  label: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _hasConfirmedCopiedAndRemembered
                              ? 'Cập nhật mật khẩu'
                              : 'Cập nhật mật khẩu (Đang khóa)',
                          style: TextStyle(
                            color: _hasConfirmedCopiedAndRemembered ? Colors.white : Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCheckbox({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: value,
                activeColor: AppColors.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
