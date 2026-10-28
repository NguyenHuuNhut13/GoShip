import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../../auth/data/auth_service.dart';

class DriverEditProfileScreen extends StatefulWidget {
  final UserModel user;

  const DriverEditProfileScreen({super.key, required this.user});

  @override
  State<DriverEditProfileScreen> createState() => _DriverEditProfileScreenState();
}

class _DriverEditProfileScreenState extends State<DriverEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _cccdController;
  late final TextEditingController _dobController;
  late final TextEditingController _plateController;
  late final TextEditingController _vehicleTypeController;

  String _gender = 'Nam';
  String? _selectedAvatar;
  bool _isSaving = false;

  static const List<String> commonVehicleTypes = [
    'Xe máy 2 bánh',
    'Xe Bán tải Ranger',
    'Xe tải 500kg',
    'Xe tải 1 tấn (Thùng bạt)',
    'Xe tải 1.5 tấn (Thùng kín)',
    'Xe tải 2 tấn',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email);
    _cccdController = TextEditingController(text: widget.user.cccd ?? '070204000284');
    _dobController = TextEditingController(text: widget.user.dob ?? '13/09/1996');
    _gender = widget.user.gender ?? 'Nam';
    _plateController = TextEditingController(text: widget.user.plateNumber ?? '51D 892.14');
    _vehicleTypeController = TextEditingController(text: widget.user.vehicleType ?? 'Xe Bán tải Ranger');
    _selectedAvatar = widget.user.avatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cccdController.dispose();
    _dobController.dispose();
    _plateController.dispose();
    _vehicleTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Chụp ảnh mới'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Chọn từ thư viện ảnh'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;
      final picked = await picker.pickImage(source: source, maxWidth: 600, maxHeight: 600, imageQuality: 80);
      if (picked != null) {
        setState(() {
          _selectedAvatar = picked.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _selectDate({required TextEditingController controller, required String title}) async {
    DateTime initial = DateTime.now();
    try {
      final parts = controller.text.split('/');
      if (parts.length == 3) {
        initial = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
      helpText: title,
      confirmText: 'CHỌN',
      cancelText: 'HỦY',
    );

    if (picked != null && mounted) {
      final day = picked.day.toString().padLeft(2, '0');
      final month = picked.month.toString().padLeft(2, '0');
      final year = picked.year.toString();
      setState(() {
        controller.text = '$day/$month/$year';
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final cccd = _cccdController.text.trim();
    final dob = _dobController.text.trim();
    final plate = _plateController.text.trim().toUpperCase();
    final vehicle = _vehicleTypeController.text.trim();

    try {
      String? finalAvatar = _selectedAvatar ?? widget.user.avatarUrl;

      // Cập nhật avatar nếu có API
      if (_selectedAvatar != null &&
          _selectedAvatar != widget.user.avatarUrl &&
          widget.user.token != null &&
          widget.user.token!.isNotEmpty) {
        try {
          final resAvatar = await ApiClient.updateAvatar(currentUser: widget.user, avatarUrlOrPath: _selectedAvatar!);
          if (resAvatar.isSuccess && resAvatar.data != null && resAvatar.data!.isNotEmpty) {
            finalAvatar = resAvatar.data!;
          }
        } catch (_) {}
      }

      // Cập nhật API info nếu có token
      if (widget.user.token != null && widget.user.token!.isNotEmpty) {
        try {
          await ApiClient.updateUserInfo(
            currentUser: widget.user,
            name: name,
            phone: phone,
            email: email,
            cccd: cccd,
          );
        } catch (_) {}
      }

      final updated = widget.user.copyWith(
        name: name,
        phone: phone,
        email: email,
        cccd: cccd,
        dob: dob,
        gender: _gender,
        plateNumber: plate,
        vehicleType: vehicle,
        avatarUrl: finalAvatar,
      );

      // Đồng bộ hồ sơ tài xế + biển số + ảnh đại diện lên Cloud Firestore (`users` & `driver_tracking`)
      final syncedDriver = await AuthService.syncUserProfileToCloud(updated);
      await AuthService.saveSession(syncedDriver, syncCloud: false);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật & đồng bộ hồ sơ tài xế lên Cloud thành công!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, syncedDriver);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu hồ sơ: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showVehicleTypePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chọn loại phương tiện hoạt động', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const Divider(height: 1),
            ...commonVehicleTypes.map((v) => ListTile(
                  leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                  title: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: _vehicleTypeController.text == v ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() => _vehicleTypeController.text = v);
                    Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ Tài xế', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar & Badge Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accent, width: 2.5),
                          ),
                          child: _selectedAvatar != null && !kIsWeb && File(_selectedAvatar!).existsSync()
                              ? CircleAvatar(
                                  radius: 46,
                                  backgroundImage: FileImage(File(_selectedAvatar!)),
                                )
                              : AppAvatarWidget(
                                  avatarUrl: _selectedAvatar ?? widget.user.avatarUrl,
                                  name: widget.user.name,
                                  size: 92,
                                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                                ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text('Đối tác Tài xế GoShip', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 14, color: Color(0xFFD97706)),
                              const SizedBox(width: 2),
                              Text('${widget.user.rating}', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w800, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // SECTION 1: THÔNG TIN CÁ NHÂN
              const Text('Thông tin cá nhân', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 14),

              _buildInputField(
                label: 'Họ và tên tài xế',
                controller: _nameController,
                icon: Icons.person_outline_rounded,
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập họ và tên' : null,
              ),

              const SizedBox(height: 14),

              _buildInputField(
                label: 'Số điện thoại liên hệ',
                controller: _phoneController,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().length < 9 ? 'Số điện thoại không hợp lệ' : null,
              ),

              const SizedBox(height: 14),

              _buildInputField(
                label: 'Địa chỉ Email / Gmail',
                controller: _emailController,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) => val == null || !val.contains('@') ? 'Email không hợp lệ' : null,
              ),

              const SizedBox(height: 14),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'Số CCCD / Định danh',
                      controller: _cccdController,
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      label: 'Ngày sinh',
                      hintText: 'DD/MM/YYYY',
                      controller: _dobController,
                      icon: Icons.cake_outlined,
                      readOnly: true,
                      onTap: () => _selectDate(controller: _dobController, title: 'Chọn ngày sinh'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Gender Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Giới tính', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _gender = 'Nam'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _gender == 'Nam' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _gender == 'Nam' ? AppColors.primary : const Color(0xFFCBD5E1),
                                width: _gender == 'Nam' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.male_rounded, size: 20, color: _gender == 'Nam' ? AppColors.primary : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Nam',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _gender == 'Nam' ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _gender = 'Nữ'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _gender == 'Nữ' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _gender == 'Nữ' ? AppColors.primary : const Color(0xFFCBD5E1),
                                width: _gender == 'Nữ' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.female_rounded, size: 20, color: _gender == 'Nữ' ? AppColors.primary : AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  'Nữ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: _gender == 'Nữ' ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // SECTION 2: THÔNG TIN PHƯƠNG TIỆN VẬN TẢI
              const Text('Thông tin phương tiện đăng ký', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 14),

              // Vehicle Type Selector
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Loại phương tiện đăng kiểm', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showVehicleTypePicker,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: AppColors.accent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _vehicleTypeController.text,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              _buildInputField(
                label: 'Biển số xe',
                hintText: 'Ví dụ: 51D-892.14',
                controller: _plateController,
                icon: Icons.pin_rounded,
                textCapitalization: TextCapitalization.characters,
                validator: (val) => val == null || val.trim().isEmpty ? 'Vui lòng nhập biển số xe' : null,
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Đang cập nhật...' : 'Lưu thông tin tài xế',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hintText ?? label,
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
