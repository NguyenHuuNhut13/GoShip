import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/cloud_media_service.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../../auth/data/auth_service.dart';
import 'avatar_crop_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;
  const EditProfileScreen({super.key, required this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _cccdController;
  late final TextEditingController _dobController;
  late final TextEditingController _hometownController;
  late final TextEditingController _permanentAddressController;
  late final TextEditingController _expiryDateController;

  String _gender = 'Nam';
  String? _selectedAvatar;
  String? _frontCccdPath;
  String? _backCccdPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email);

    final currentCccd = widget.user.cccd;
    _cccdController = TextEditingController(
      text: (currentCccd != null && currentCccd.isNotEmpty && currentCccd != '079201018269')
          ? currentCccd
          : '070204000284',
    );

    _dobController = TextEditingController(text: widget.user.dob ?? '13/09/2004');
    _gender = widget.user.gender ?? 'Nam';
    _hometownController = TextEditingController(text: widget.user.hometown ?? 'Phú Mỹ, Thủ Dầu Một, Bình Dương');
    _permanentAddressController = TextEditingController(
      text: widget.user.permanentAddress ?? 'Tổ 4, Ấp Sở Nhì, Thanh Bình, Hớn Quản, Bình Phước',
    );
    _expiryDateController = TextEditingController(text: widget.user.expiryDate ?? '13/09/2029');

    _selectedAvatar = widget.user.avatarUrl;
    _frontCccdPath = widget.user.cccdFrontUrl;
    _backCccdPath = widget.user.cccdBackUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cccdController.dispose();
    _dobController.dispose();
    _hometownController.dispose();
    _permanentAddressController.dispose();
    _expiryDateController.dispose();
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
      final picked = await picker.pickImage(source: source, imageQuality: 90);
      if (picked != null && mounted) {
        final croppedPath = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => AvatarCropScreen(imagePath: picked.path)),
        );

        if (croppedPath != null && mounted) {
          setState(() {
            _selectedAvatar = croppedPath;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  Future<void> _pickCccdImage({required bool isFront}) async {
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
                title: Text('Chụp ${isFront ? "mặt trước" : "mặt sau"} CCCD'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: Text('Chọn ${isFront ? "mặt trước" : "mặt sau"} từ thư viện'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;
      final picked = await picker.pickImage(source: source, imageQuality: 92);
      if (picked != null && mounted) {
        setState(() {
          if (isFront) {
            _frontCccdPath = picked.path;
          } else {
            _backCccdPath = picked.path;
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi chọn ảnh CCCD: $e')));
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
      lastDate: DateTime(2050),
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
    final hometown = _hometownController.text.trim();
    final permanentAddress = _permanentAddressController.text.trim();
    final expiryDate = _expiryDateController.text.trim();

    try {
      // 1. Gọi API nks/user/updateInfo
      final response = await ApiClient.updateUserInfo(
        currentUser: widget.user,
        name: name,
        phone: phone,
        email: email,
        cccd: cccd,
      );

      // 2. Gọi API nks/user/updateCccd nếu có CCCD
      if (widget.user.token != null && widget.user.token!.isNotEmpty && cccd.isNotEmpty) {
        try {
          await ApiClient.updateCccd(token: widget.user.token!, cccd: cccd);
        } catch (_) {}
      }

      // 3. Gọi API nks/user/updateAvatar nếu có đổi ảnh (mã hóa base64 trước khi gửi)
      String? finalAvatar = _selectedAvatar ?? widget.user.avatarUrl;
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

      final updated = (response.data ?? widget.user).copyWith(
        name: name,
        phone: phone,
        email: email,
        cccd: cccd,
        avatarUrl: finalAvatar,
        cccdFrontUrl: _frontCccdPath,
        cccdBackUrl: _backCccdPath,
        dob: dob,
        gender: _gender,
        hometown: hometown,
        permanentAddress: permanentAddress,
        expiryDate: expiryDate,
      );

      // 4. Đồng bộ hồ sơ + nén ảnh đa thiết bị lên Cloud Firestore & lưu vào SharedPreferences
      final syncedUser = await AuthService.syncUserProfileToCloud(updated);
      await AuthService.saveSession(syncedUser, syncCloud: false);

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật & đồng bộ thông tin tài khoản lên Cloud thành công!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, syncedUser);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi cập nhật: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Chỉnh sửa thông tin',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Section (Không có nút chữ dư thừa, chạm avatar để đổi)
              Center(
                child: Stack(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(48),
                      onTap: _pickAvatar,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AppAvatarWidget(
                          avatarUrl: _selectedAvatar,
                          name: _nameController.text.isNotEmpty ? _nameController.text : widget.user.name,
                          size: 96,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Chạm ảnh đại diện để thay đổi',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 20),

              // CARD 1: THÔNG TIN CƠ BẢN
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Thông tin cơ bản',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.border),

                    _buildInputLabel('Họ và tên *'),
                    _buildTextField(
                      controller: _nameController,
                      icon: Icons.person_outline_rounded,
                      hint: 'Nhập họ và tên',
                      validator: (val) => val == null || val.trim().isEmpty ? 'Họ tên không được để trống' : null,
                    ),
                    const SizedBox(height: 14),

                    _buildInputLabel('Số điện thoại *'),
                    _buildTextField(
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      hint: 'Nhập số điện thoại',
                      keyboardType: TextInputType.phone,
                      validator: (val) => val == null || val.trim().length < 9 ? 'Số điện thoại không hợp lệ' : null,
                    ),
                    const SizedBox(height: 14),

                    _buildInputLabel('Địa chỉ Email *'),
                    _buildTextField(
                      controller: _emailController,
                      icon: Icons.email_outlined,
                      hint: 'Nhập địa chỉ email',
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email không được để trống';
                        if (!val.contains('@')) return 'Email không hợp lệ';
                        return null;
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // CARD 2: CĂN CƯỚC CÔNG DÂN (CCCD)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.badge_rounded, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Căn cước công dân (CCCD)',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.border),

                    // 2 Sides CCCD Photos
                    Row(
                      children: [
                        Expanded(
                          child: _buildCccdSideBox(
                            title: 'Mặt trước CCCD',
                            imagePath: _frontCccdPath,
                            icon: Icons.credit_card_rounded,
                            onTap: () => _pickCccdImage(isFront: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCccdSideBox(
                            title: 'Mặt sau CCCD',
                            imagePath: _backCccdPath,
                            icon: Icons.qr_code_scanner_rounded,
                            onTap: () => _pickCccdImage(isFront: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildInputLabel('Số CCCD (12 chữ số)'),
                    _buildTextField(
                      controller: _cccdController,
                      icon: Icons.pin_outlined,
                      hint: '070204000284',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 14),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Ngày sinh'),
                              _buildTextField(
                                controller: _dobController,
                                icon: Icons.calendar_today_rounded,
                                hint: '13/09/2004',
                                readOnly: true,
                                onTap: () => _selectDate(controller: _dobController, title: 'Chọn ngày sinh'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Giới tính'),
                              Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.inputBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _gender = 'Nam'),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _gender == 'Nam' ? AppColors.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Nam',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _gender == 'Nam' ? Colors.white : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => setState(() => _gender = 'Nữ'),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: _gender == 'Nữ' ? AppColors.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Nữ',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _gender == 'Nữ' ? Colors.white : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildInputLabel('Quê quán'),
                    _buildTextField(
                      controller: _hometownController,
                      icon: Icons.place_outlined,
                      hint: 'Phú Mỹ, Thủ Dầu Một, Bình Dương',
                    ),
                    const SizedBox(height: 14),

                    _buildInputLabel('Nơi thường trú'),
                    _buildTextField(
                      controller: _permanentAddressController,
                      icon: Icons.home_outlined,
                      hint: 'Tổ 4, Ấp Sở Nhì, Thanh Bình, Hớn Quản, Bình Phước',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 14),

                    _buildInputLabel('Giá trị đến'),
                    _buildTextField(
                      controller: _expiryDateController,
                      icon: Icons.event_available_outlined,
                      hint: '13/09/2029',
                      readOnly: true,
                      onTap: () => _selectDate(controller: _expiryDateController, title: 'Chọn ngày hết hạn'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Security Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.shield_outlined, size: 20, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Thông tin cá nhân & CCCD được mã hóa an toàn và đồng bộ bảo mật trực tiếp qua máy chủ tài khoản nks.vn',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _handleSave,
            icon: _isSaving
                ? const SizedBox.shrink()
                : const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            label: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Lưu thay đổi',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 18),
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      ),
    );
  }

  Widget _buildCccdSideBox({
    required String title,
    required String? imagePath,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final bool hasImage = imagePath != null && imagePath.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 105,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasImage ? AppColors.primary : AppColors.border, width: hasImage ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CloudMediaService.buildSmartImage(
                    imagePath,
                    fit: BoxFit.cover,
                    fallback: Center(
                      child: Icon(icon, color: AppColors.primary, size: 28),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.primary, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  const Text('Chạm để tải ảnh', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
      ),
    );
  }
}
