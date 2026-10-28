import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../auth/data/auth_service.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/ai_cargo_advisor_service.dart';
import '../../../../../core/services/contact_picker_helper.dart';
import '../../models/order_draft_model.dart';
import '../widgets/ai_cargo_advisor_widget.dart';

class _RecipientPointControllers {
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController noteController;
  final TextEditingController itemDescController;
  final TextEditingController lengthController;
  final TextEditingController widthController;
  final TextEditingController heightController;

  _RecipientPointControllers({
    required String name,
    required String phone,
    required String note,
    String itemDesc = '',
    double? lengthM,
    double? widthM,
    double? heightM,
  })  : nameController = TextEditingController(text: name),
        phoneController = TextEditingController(text: phone),
        noteController = TextEditingController(text: note),
        itemDescController = TextEditingController(text: itemDesc),
        lengthController = TextEditingController(text: lengthM != null && lengthM > 0 ? lengthM.toString() : ''),
        widthController = TextEditingController(text: widthM != null && widthM > 0 ? widthM.toString() : ''),
        heightController = TextEditingController(text: heightM != null && heightM > 0 ? heightM.toString() : '');

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    noteController.dispose();
    itemDescController.dispose();
    lengthController.dispose();
    widthController.dispose();
    heightController.dispose();
  }
}

class Step2PackageScreen extends StatefulWidget {
  final OrderDraftModel draft;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const Step2PackageScreen({
    super.key,
    required this.draft,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<Step2PackageScreen> createState() => _Step2PackageScreenState();
}

class _Step2PackageScreenState extends State<Step2PackageScreen> {
  late String _selectedWeight;
  late String _selectedCategory;
  late TextEditingController _customCategoryController;
  late TextEditingController _senderNameController;
  late TextEditingController _senderPhoneController;
  late List<_RecipientPointControllers> _recipientControllers;
  late TextEditingController _noteController;
  bool? _selectedScenario;
  int _selectedDropoffIndex = 0;

  late TextEditingController _dimensionDescController;
  late TextEditingController _lengthController;
  late TextEditingController _widthController;
  late TextEditingController _heightController;

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  final ImagePicker _picker = ImagePicker();

  final List<String> _weightOptions = [
    '<100kg',
    '100-500kg',
    '500-1000kg',
    '>1000kg',
  ];

  final List<String> _categoryOptions = [
    'Hàng tiêu chuẩn / Thùng carton',
    'Hàng cồng kềnh / Quá khổ',
    'Hàng dễ vỡ / Điện tử',
    'Nội thất / Hàng gia dụng',
    'Vật liệu xây dựng / Cơ khí',
    'Nông sản / Thực phẩm tươi sống',
    'Hàng khác (Tự nhập)',
  ];

  @override
  void initState() {
    super.initState();
    if (_weightOptions.contains(widget.draft.weightCategory)) {
      _selectedWeight = widget.draft.weightCategory;
    } else {
      _selectedWeight = _weightOptions.first;
      widget.draft.weightCategory = _selectedWeight;
    }
    
    _customCategoryController = TextEditingController();

    // Ensure selected category is valid in new list or custom
    if (_categoryOptions.contains(widget.draft.packageCategory) &&
        widget.draft.packageCategory != 'Hàng khác (Tự nhập)') {
      _selectedCategory = widget.draft.packageCategory;
    } else if (widget.draft.packageCategory.isNotEmpty &&
        widget.draft.packageCategory != 'Hàng khác (Tự nhập)') {
      _selectedCategory = 'Hàng khác (Tự nhập)';
      _customCategoryController.text = widget.draft.packageCategory;
    } else if (widget.draft.packageCategory == 'Hàng khác (Tự nhập)') {
      _selectedCategory = 'Hàng khác (Tự nhập)';
    } else {
      _selectedCategory = _categoryOptions.first;
      widget.draft.packageCategory = _selectedCategory;
    }

    widget.draft.syncRecipientsWithDropoffs();
    _recipientControllers = widget.draft.dropoffRecipients.asMap().entries.map((entry) {
      final i = entry.key;
      final r = entry.value;
      final itemDesc = r.itemsDescription.isNotEmpty
          ? r.itemsDescription
          : (i == 0 ? widget.draft.packageDimensionDescription : '');
      final len = r.lengthM ?? (i == 0 ? widget.draft.packageLengthM : null);
      final wid = r.widthM ?? (i == 0 ? widget.draft.packageWidthM : null);
      final hei = r.heightM ?? (i == 0 ? widget.draft.packageHeightM : null);

      return _RecipientPointControllers(
        name: r.name,
        phone: r.phone,
        note: r.note,
        itemDesc: itemDesc,
        lengthM: len,
        widthM: wid,
        heightM: hei,
      );
    }).toList();

    _senderNameController = TextEditingController(text: widget.draft.senderName);
    _senderPhoneController = TextEditingController(text: widget.draft.senderPhone);
    _noteController = TextEditingController(text: widget.draft.driverNote);

    _dimensionDescController = TextEditingController(
      text: widget.draft.packageDimensionDescription.isNotEmpty
          ? widget.draft.packageDimensionDescription
          : (widget.draft.dropoffRecipients.isNotEmpty ? widget.draft.dropoffRecipients.first.itemsDescription : ''),
    );
    _lengthController = TextEditingController(
      text: widget.draft.packageLengthM != null
          ? widget.draft.packageLengthM.toString()
          : (widget.draft.dropoffRecipients.isNotEmpty && widget.draft.dropoffRecipients.first.lengthM != null
              ? widget.draft.dropoffRecipients.first.lengthM.toString()
              : ''),
    );
    _widthController = TextEditingController(
      text: widget.draft.packageWidthM != null
          ? widget.draft.packageWidthM.toString()
          : (widget.draft.dropoffRecipients.isNotEmpty && widget.draft.dropoffRecipients.first.widthM != null
              ? widget.draft.dropoffRecipients.first.widthM.toString()
              : ''),
    );
    _heightController = TextEditingController(
      text: widget.draft.packageHeightM != null
          ? widget.draft.packageHeightM.toString()
          : (widget.draft.dropoffRecipients.isNotEmpty && widget.draft.dropoffRecipients.first.heightM != null
              ? widget.draft.dropoffRecipients.first.heightM.toString()
              : ''),
    );
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    _senderNameController.dispose();
    _senderPhoneController.dispose();
    for (final c in _recipientControllers) {
      c.dispose();
    }
    _noteController.dispose();
    _dimensionDescController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _fillMyInfoAsSender() async {
    final user = await AuthService.getCurrentUser();
    final name = (user?.name != null && user!.name.isNotEmpty) ? user.name : 'Nguyễn Hữu Nhựt';
    final phone = (user?.phone != null && user!.phone.isNotEmpty) ? user.phone : '0917795211';

    setState(() {
      _senderNameController.text = name;
      _senderPhoneController.text = phone;
      widget.draft.senderName = name;
      widget.draft.senderPhone = phone;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã điền thông tin của bạn: $name ($phone)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickSenderContact() async {
    final result = await ContactPickerHelper.pickContact(context);
    if (result != null && mounted) {
      setState(() {
        _senderNameController.text = result.name;
        _senderPhoneController.text = result.phone;
        widget.draft.senderName = result.name;
        widget.draft.senderPhone = result.phone;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chọn người gửi: ${result.name} (${result.phone})'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _fillMyInfoAsRecipient(int index) async {
    final user = await AuthService.getCurrentUser();
    final name = (user?.name != null && user!.name.isNotEmpty) ? user.name : 'Nguyễn Hữu Nhựt';
    final phone = (user?.phone != null && user!.phone.isNotEmpty) ? user.phone : '0917795211';

    setState(() {
      if (index < _recipientControllers.length) {
        _recipientControllers[index].nameController.text = name;
        _recipientControllers[index].phoneController.text = phone;
      }
      if (index < widget.draft.dropoffRecipients.length) {
        widget.draft.dropoffRecipients[index].name = name;
        widget.draft.dropoffRecipients[index].phone = phone;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã điền thông tin của bạn vào Người nhận: $name ($phone)'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _applyScenario({required bool isMeSender}) async {
    final user = await AuthService.getCurrentUser();
    final name = (user?.name != null && user!.name.isNotEmpty) ? user.name : 'Nguyễn Hữu Nhựt';
    final phone = (user?.phone != null && user!.phone.isNotEmpty) ? user.phone : '0917795211';

    final targetIdx = _selectedDropoffIndex.clamp(0, _recipientControllers.isEmpty ? 0 : _recipientControllers.length - 1);

    setState(() {
      _selectedScenario = isMeSender;
      if (isMeSender) {
        // Tôi gửi hàng đi -> tôi là người gửi
        _senderNameController.text = name;
        _senderPhoneController.text = phone;
        widget.draft.senderName = name;
        widget.draft.senderPhone = phone;
      } else {
        // Người khác gửi cho tôi -> tôi là người nhận tại điểm giao đang chọn
        if (_recipientControllers.isNotEmpty) {
          _recipientControllers[targetIdx].nameController.text = name;
          _recipientControllers[targetIdx].phoneController.text = phone;
          if (targetIdx < widget.draft.dropoffRecipients.length) {
            widget.draft.dropoffRecipients[targetIdx].name = name;
            widget.draft.dropoffRecipients[targetIdx].phone = phone;
          }
        }
        if (_senderNameController.text == name) {
          _senderNameController.clear();
          _senderPhoneController.clear();
          widget.draft.senderName = '';
          widget.draft.senderPhone = '';
        }
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isMeSender
                ? 'Đã chọn: Bạn là Người gửi ($name)'
                : (_recipientControllers.length > 1
                    ? 'Đã chọn: Bạn là Người nhận tại Điểm giao ${targetIdx + 1} ($name). Vui lòng điền thông tin người gửi!'
                    : 'Đã chọn: Bạn là Người nhận ($name). Vui lòng điền thông tin người gửi!'),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickContactFor(int index) async {
    final result = await ContactPickerHelper.pickContact(context);
    if (result != null && mounted) {
      setState(() {
        _recipientControllers[index].nameController.text = result.name;
        _recipientControllers[index].phoneController.text = result.phone;
        if (index < widget.draft.dropoffRecipients.length) {
          widget.draft.dropoffRecipients[index].name = result.name;
          widget.draft.dropoffRecipients[index].phone = result.phone;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã chọn liên hệ: ${result.name} (${result.phone})'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _pickedImage = photo;
          _imageBytes = bytes;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tải ảnh kiện hàng thành công!'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể truy cập ảnh: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn ảnh kiện hàng',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary, size: 22),
                ),
                title: const Text('Chụp ảnh trực tiếp', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Mở camera để chụp kiện hàng ngay', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),

              const Divider(height: 1, indent: 60),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF4E8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.accent, size: 22),
                ),
                title: const Text('Chọn từ thư viện ảnh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                subtitle: const Text('Tải ảnh kiện hàng có sẵn trong máy', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _saveDraft() {
    widget.draft.weightCategory = _selectedWeight;
    if (_selectedCategory == 'Hàng khác (Tự nhập)') {
      final custom = _customCategoryController.text.trim();
      widget.draft.packageCategory = custom.isNotEmpty ? custom : 'Hàng khác';
    } else {
      widget.draft.packageCategory = _selectedCategory;
    }
    widget.draft.senderName = _senderNameController.text.trim();
    widget.draft.senderPhone = _senderPhoneController.text.trim();
    widget.draft.driverNote = _noteController.text.trim();

    widget.draft.syncRecipientsWithDropoffs();
    for (int i = 0; i < _recipientControllers.length; i++) {
      if (i < widget.draft.dropoffRecipients.length) {
        final ctrl = _recipientControllers[i];
        final r = widget.draft.dropoffRecipients[i];
        r.name = ctrl.nameController.text.trim();
        r.phone = ctrl.phoneController.text.trim();
        r.note = ctrl.noteController.text.trim();
        r.itemsDescription = ctrl.itemDescController.text.trim();
        r.lengthM = double.tryParse(ctrl.lengthController.text.trim().replaceAll(',', '.'));
        r.widthM = double.tryParse(ctrl.widthController.text.trim().replaceAll(',', '.'));
        r.heightM = double.tryParse(ctrl.heightController.text.trim().replaceAll(',', '.'));
      }
    }

    if (widget.draft.dropoffAddresses.length > 1) {
      final multiDescriptions = <String>[];
      for (int i = 0; i < widget.draft.dropoffRecipients.length; i++) {
        final r = widget.draft.dropoffRecipients[i];
        if (r.itemsDescription.isNotEmpty || r.hasDimensions) {
          final dimStr = r.hasDimensions ? ' (${r.dimensionSummary})' : '';
          multiDescriptions.add('Điểm ${i + 1}: ${r.itemsDescription}$dimStr');
        }
      }
      widget.draft.packageDimensionDescription = multiDescriptions.isNotEmpty
          ? multiDescriptions.join('; ')
          : _dimensionDescController.text.trim();
      widget.draft.packageLengthM = widget.draft.maxCargoLengthM;
      widget.draft.packageWidthM = widget.draft.maxCargoWidthM;
      widget.draft.packageHeightM = widget.draft.maxCargoHeightM;
    } else {
      widget.draft.packageDimensionDescription = _dimensionDescController.text.trim();
      widget.draft.packageLengthM = double.tryParse(_lengthController.text.trim().replaceAll(',', '.'));
      widget.draft.packageWidthM = double.tryParse(_widthController.text.trim().replaceAll(',', '.'));
      widget.draft.packageHeightM = double.tryParse(_heightController.text.trim().replaceAll(',', '.'));
      if (widget.draft.dropoffRecipients.isNotEmpty) {
        widget.draft.dropoffRecipients[0].itemsDescription = widget.draft.packageDimensionDescription;
        widget.draft.dropoffRecipients[0].lengthM = widget.draft.packageLengthM;
        widget.draft.dropoffRecipients[0].widthM = widget.draft.packageWidthM;
        widget.draft.dropoffRecipients[0].heightM = widget.draft.packageHeightM;
      }
    }
  }

  bool _validateStep2() {
    final senderName = _senderNameController.text.trim();
    final senderPhone = _senderPhoneController.text.trim().replaceAll(RegExp(r'\s+'), '');

    if (senderName.isEmpty) {
      _showWarningSnackBar('Vui lòng nhập họ tên người gửi hàng');
      return false;
    }
    if (senderPhone.isEmpty || senderPhone.length < 9) {
      _showWarningSnackBar('Vui lòng nhập số điện thoại người gửi hợp lệ (tối thiểu 9-10 số)');
      return false;
    }

    for (int i = 0; i < widget.draft.dropoffAddresses.length; i++) {
      final ctrl = i < _recipientControllers.length ? _recipientControllers[i] : null;
      final recipName = ctrl?.nameController.text.trim() ?? '';
      final recipPhone = (ctrl?.phoneController.text.trim() ?? '').replaceAll(RegExp(r'\s+'), '');

      if (recipName.isEmpty) {
        setState(() => _selectedDropoffIndex = i);
        _showWarningSnackBar('Vui lòng nhập tên người nhận tại Điểm giao ${i + 1}');
        return false;
      }
      if (recipPhone.isEmpty || recipPhone.length < 9) {
        setState(() => _selectedDropoffIndex = i);
        _showWarningSnackBar('Vui lòng nhập số điện thoại người nhận tại Điểm giao ${i + 1}');
        return false;
      }
    }

    return true;
  }

  void _showWarningSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _tryParseDimensionsFromText(String text, {int? pointIndex}) {
    final raw = text.toLowerCase().replaceAll(',', '.');
    String? lStr;
    String? wStr;
    String? hStr;

    // 1. Triple dimension pattern: "2.5 x 2 x 1.5" or "2.5m x 2m x 1.5m"
    final tripleMatch = RegExp(r'(\d+(?:\.\d+)?)\s*m?\s*[x*x×]\s*(\d+(?:\.\d+)?)\s*m?\s*[x*x×]\s*(\d+(?:\.\d+)?)\s*m?').firstMatch(raw);
    if (tripleMatch != null) {
      lStr = tripleMatch.group(1);
      wStr = tripleMatch.group(2);
      hStr = tripleMatch.group(3);
    } else {
      // 2. Double dimension pattern: "2.5 x 1.8" or "2.5m x 1.8m"
      final doubleMatch = RegExp(r'(\d+(?:\.\d+)?)\s*m?\s*[x*x×]\s*(\d+(?:\.\d+)?)\s*m?').firstMatch(raw);
      if (doubleMatch != null) {
        lStr = doubleMatch.group(1);
        wStr = doubleMatch.group(2);
      }

      // 3. Keyword patterns: dài, rộng / ngang, cao
      final lengthMatch = RegExp(r'(?:dài|dai|d)\s*[:=]?\s*(\d+(?:\.\d+)?)\s*m?').firstMatch(raw);
      final widthMatch = RegExp(r'(?:ngang|rộng|rong|r)\s*[:=]?\s*(\d+(?:\.\d+)?)\s*m?').firstMatch(raw);
      final heightMatch = RegExp(r'(?:cao|c)\s*[:=]?\s*(\d+(?:\.\d+)?)\s*m?').firstMatch(raw);

      if (lengthMatch != null) lStr = lengthMatch.group(1);
      if (widthMatch != null) wStr = widthMatch.group(1);
      if (heightMatch != null) hStr = heightMatch.group(1);
    }

    if (pointIndex != null && pointIndex < _recipientControllers.length) {
      final ctrl = _recipientControllers[pointIndex];
      setState(() {
        if (lStr != null) ctrl.lengthController.text = lStr;
        if (wStr != null) ctrl.widthController.text = wStr;
        if (hStr != null) ctrl.heightController.text = hStr;
      });
      _updateDropoffDimensions(pointIndex);
    } else {
      setState(() {
        if (lStr != null) _lengthController.text = lStr;
        if (wStr != null) _widthController.text = wStr;
        if (hStr != null) _heightController.text = hStr;
      });
      _updateDraftDimensions();
    }
  }

  void _updateDraftDimensions() {
    final l = double.tryParse(_lengthController.text.trim().replaceAll(',', '.'));
    final w = double.tryParse(_widthController.text.trim().replaceAll(',', '.'));
    final h = double.tryParse(_heightController.text.trim().replaceAll(',', '.'));
    setState(() {
      widget.draft.packageLengthM = l;
      widget.draft.packageWidthM = w;
      widget.draft.packageHeightM = h;
      widget.draft.packageDimensionDescription = _dimensionDescController.text.trim();
      if (_recipientControllers.isNotEmpty) {
        _recipientControllers[0].itemDescController.text = _dimensionDescController.text;
        _recipientControllers[0].lengthController.text = _lengthController.text;
        _recipientControllers[0].widthController.text = _widthController.text;
        _recipientControllers[0].heightController.text = _heightController.text;
      }
      if (widget.draft.dropoffRecipients.isNotEmpty) {
        widget.draft.dropoffRecipients[0].itemsDescription = _dimensionDescController.text.trim();
        widget.draft.dropoffRecipients[0].lengthM = l;
        widget.draft.dropoffRecipients[0].widthM = w;
        widget.draft.dropoffRecipients[0].heightM = h;
      }
    });
  }

  void _updateDropoffDimensions(int pointIndex) {
    if (pointIndex >= _recipientControllers.length) return;
    final ctrl = _recipientControllers[pointIndex];
    final l = double.tryParse(ctrl.lengthController.text.trim().replaceAll(',', '.'));
    final w = double.tryParse(ctrl.widthController.text.trim().replaceAll(',', '.'));
    final h = double.tryParse(ctrl.heightController.text.trim().replaceAll(',', '.'));
    setState(() {
      if (pointIndex < widget.draft.dropoffRecipients.length) {
        widget.draft.dropoffRecipients[pointIndex].itemsDescription = ctrl.itemDescController.text.trim();
        widget.draft.dropoffRecipients[pointIndex].lengthM = l;
        widget.draft.dropoffRecipients[pointIndex].widthM = w;
        widget.draft.dropoffRecipients[pointIndex].heightM = h;
      }
      if (pointIndex == 0 && widget.draft.dropoffAddresses.length == 1) {
        _dimensionDescController.text = ctrl.itemDescController.text;
        _lengthController.text = ctrl.lengthController.text;
        _widthController.text = ctrl.widthController.text;
        _heightController.text = ctrl.heightController.text;
        widget.draft.packageDimensionDescription = ctrl.itemDescController.text.trim();
        widget.draft.packageLengthM = l;
        widget.draft.packageWidthM = w;
        widget.draft.packageHeightM = h;
      }
    });
  }

  void _applyDimensionPreset({
    required String desc,
    required double length,
    required double width,
    required double height,
  }) {
    setState(() {
      _dimensionDescController.text = desc;
      _lengthController.text = length.toString();
      _widthController.text = width.toString();
      _heightController.text = height.toString();
      widget.draft.packageDimensionDescription = desc;
      widget.draft.packageLengthM = length;
      widget.draft.packageWidthM = width;
      widget.draft.packageHeightM = height;
      if (_recipientControllers.isNotEmpty) {
        _recipientControllers[0].itemDescController.text = desc;
        _recipientControllers[0].lengthController.text = length.toString();
        _recipientControllers[0].widthController.text = width.toString();
        _recipientControllers[0].heightController.text = height.toString();
      }
      if (widget.draft.dropoffRecipients.isNotEmpty) {
        widget.draft.dropoffRecipients[0].itemsDescription = desc;
        widget.draft.dropoffRecipients[0].lengthM = length;
        widget.draft.dropoffRecipients[0].widthM = width;
        widget.draft.dropoffRecipients[0].heightM = height;
      }
    });
  }

  void _applyDropoffDimensionPreset({
    required int pointIndex,
    required String desc,
    required double length,
    required double width,
    required double height,
  }) {
    if (pointIndex >= _recipientControllers.length) return;
    setState(() {
      final ctrl = _recipientControllers[pointIndex];
      ctrl.itemDescController.text = desc;
      ctrl.lengthController.text = length.toString();
      ctrl.widthController.text = width.toString();
      ctrl.heightController.text = height.toString();
      if (pointIndex < widget.draft.dropoffRecipients.length) {
        widget.draft.dropoffRecipients[pointIndex].itemsDescription = desc;
        widget.draft.dropoffRecipients[pointIndex].lengthM = length;
        widget.draft.dropoffRecipients[pointIndex].widthM = width;
        widget.draft.dropoffRecipients[pointIndex].heightM = height;
      }
      if (pointIndex == 0 && widget.draft.dropoffAddresses.length == 1) {
        _dimensionDescController.text = desc;
        _lengthController.text = length.toString();
        _widthController.text = width.toString();
        _heightController.text = height.toString();
        widget.draft.packageDimensionDescription = desc;
        widget.draft.packageLengthM = length;
        widget.draft.packageWidthM = width;
        widget.draft.packageHeightM = height;
      }
    });
  }

  void _clearDimensions() {
    setState(() {
      _dimensionDescController.clear();
      _lengthController.clear();
      _widthController.clear();
      _heightController.clear();
      widget.draft.packageDimensionDescription = '';
      widget.draft.packageLengthM = null;
      widget.draft.packageWidthM = null;
      widget.draft.packageHeightM = null;
      if (_recipientControllers.isNotEmpty) {
        _recipientControllers[0].itemDescController.clear();
        _recipientControllers[0].lengthController.clear();
        _recipientControllers[0].widthController.clear();
        _recipientControllers[0].heightController.clear();
      }
      if (widget.draft.dropoffRecipients.isNotEmpty) {
        widget.draft.dropoffRecipients[0].itemsDescription = '';
        widget.draft.dropoffRecipients[0].lengthM = null;
        widget.draft.dropoffRecipients[0].widthM = null;
        widget.draft.dropoffRecipients[0].heightM = null;
      }
    });
  }

  void _clearDropoffDimensions(int pointIndex) {
    if (pointIndex >= _recipientControllers.length) return;
    setState(() {
      final ctrl = _recipientControllers[pointIndex];
      ctrl.itemDescController.clear();
      ctrl.lengthController.clear();
      ctrl.widthController.clear();
      ctrl.heightController.clear();
      if (pointIndex < widget.draft.dropoffRecipients.length) {
        widget.draft.dropoffRecipients[pointIndex].itemsDescription = '';
        widget.draft.dropoffRecipients[pointIndex].lengthM = null;
        widget.draft.dropoffRecipients[pointIndex].widthM = null;
        widget.draft.dropoffRecipients[pointIndex].heightM = null;
      }
      if (pointIndex == 0 && widget.draft.dropoffAddresses.length == 1) {
        _dimensionDescController.clear();
        _lengthController.clear();
        _widthController.clear();
        _heightController.clear();
        widget.draft.packageDimensionDescription = '';
        widget.draft.packageLengthM = null;
        widget.draft.packageWidthM = null;
        widget.draft.packageHeightM = null;
      }
    });
  }

  void _applyAiRecommendation(CargoRecommendation rec) {
    setState(() {
      widget.draft.vehicleType = rec.vehicleType;

      if (_weightOptions.contains(rec.weightCategoryChip)) {
        _selectedWeight = rec.weightCategoryChip;
        widget.draft.weightCategory = rec.weightCategoryChip;
      } else {
        final w = rec.estimatedWeightKg;
        if (w < 100) {
          _selectedWeight = '<100kg';
        } else if (w <= 500) {
          _selectedWeight = '100-500kg';
        } else if (w <= 1000) {
          _selectedWeight = '500-1000kg';
        } else {
          _selectedWeight = '>1000kg';
        }
        widget.draft.weightCategory = _selectedWeight;
      }

      if (_categoryOptions.contains(rec.packageCategory)) {
        _selectedCategory = rec.packageCategory;
        widget.draft.packageCategory = rec.packageCategory;
      } else {
        _selectedCategory = 'Hàng khác (Tự nhập)';
        _customCategoryController.text = rec.packageCategory;
        widget.draft.packageCategory = rec.packageCategory;
      }

      final stowageSummary = '[Sơ đồ xếp xe LIFO]: Cửa sau (dỡ trước): ${rec.stowagePlan.doorSide} • Sát cabin (dỡ sau): ${rec.stowagePlan.cabinSide}';
      final combinedAdvice = rec.driverNoteAdvice.isNotEmpty
          ? '${rec.driverNoteAdvice}\n$stowageSummary'
          : stowageSummary;

      if (_noteController.text.trim().isEmpty) {
        _noteController.text = combinedAdvice;
      } else if (!_noteController.text.contains('[Sơ đồ xếp xe LIFO]')) {
        _noteController.text = '${_noteController.text}\n$combinedAdvice'.trim();
      }
      widget.draft.driverNote = _noteController.text;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Đã chọn ${rec.vehicleName} & áp dụng đề xuất từ AI!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
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
          onPressed: widget.onBack,
        ),
        title: const Text(
          'Thông tin kiện hàng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
        actions: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 16),
            child: const Text(
              'Bước 2/3',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // AI Smart Cargo & Vehicle Advisor Card
                  AiCargoAdvisorWidget(
                    dropoffCount: widget.draft.dropoffAddresses.where((a) => a.isNotEmpty).length.clamp(1, 10),
                    onApplyRecommendation: _applyAiRecommendation,
                  ),
                  const SizedBox(height: 20),

                  // 1. Weight Selector (Chips from Figma weight-chips)
                  const Text(
                    'Khối lượng kiện hàng',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _weightOptions.map((weight) {
                      final isSelected = _selectedWeight == weight;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setState(() => _selectedWeight = weight),
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Text(
                                    weight,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // 2. Package Category Dropdown (Updated with 'Hàng khác (Tự nhập)')
                  const Text(
                    'Loại hàng hóa vận chuyển',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        items: _categoryOptions.map((cat) {
                          final isOther = cat == 'Hàng khác (Tự nhập)';
                          return DropdownMenuItem(
                            value: cat,
                            child: Row(
                              children: [
                                Icon(
                                  isOther ? Icons.edit_note_rounded : Icons.inventory_2_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    cat,
                                    style: TextStyle(
                                      fontWeight: isOther ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 13,
                                      color: isOther ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCategory = val;
                              if (val != 'Hàng khác (Tự nhập)') {
                                widget.draft.packageCategory = val;
                              } else {
                                final custom = _customCategoryController.text.trim();
                                widget.draft.packageCategory = custom.isNotEmpty ? custom : 'Hàng khác';
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  if (_selectedCategory == 'Hàng khác (Tự nhập)') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _customCategoryController,
                      onChanged: (val) {
                        widget.draft.packageCategory = val.trim().isNotEmpty ? val.trim() : 'Hàng khác';
                      },
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Nhập loại hàng hóa của bạn (VD: Tài liệu, Quần áo...)',
                        prefixIcon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                        fillColor: AppColors.background,
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 3. Package Photo Upload (Di chuyển lên dưới Loại hàng hóa)
                  _buildPhotoUploadSection(),

                  const SizedBox(height: 24),

                  // 4. Cargo Dimensions & Vehicle Bed Fit Analysis (Mô tả kích thước & Kiểm tra vừa thùng xe)
                  _buildDimensionSection(),

                  const SizedBox(height: 24),

                  // Smart Scenario Selector (Gợi ý vai trò đặt đơn nhanh)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _applyScenario(isMeSender: true),
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedScenario == true ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _selectedScenario == true
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.outbox_rounded,
                                    size: 16,
                                    color: _selectedScenario == true ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tôi gửi hàng đi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedScenario == true ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedScenario == true ? AppColors.primary : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => _applyScenario(isMeSender: false),
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _selectedScenario == false ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _selectedScenario == false
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox_rounded,
                                    size: 16,
                                    color: _selectedScenario == false ? AppColors.accent : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Người khác gửi cho tôi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedScenario == false ? FontWeight.w700 : FontWeight.w500,
                                      color: _selectedScenario == false ? AppColors.accent : AppColors.textSecondary,
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

                  const SizedBox(height: 16),

                  // 3. Sender Contact Info (Thông tin người gửi hàng)
                  Row(
                    children: [
                      const Icon(Icons.outbox_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Thông tin người gửi hàng',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                        ),
                      ),
                      InkWell(
                        onTap: _fillMyInfoAsSender,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_pin_rounded, size: 13, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Điền của tôi',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: _pickSenderContact,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.contacts_rounded, size: 13, color: AppColors.textPrimary),
                              SizedBox(width: 4),
                              Text(
                                'Danh bạ',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _senderNameController,
                    onChanged: (val) => widget.draft.senderName = val,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Họ và tên người gửi hàng',
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _senderPhoneController,
                    keyboardType: TextInputType.phone,
                    onChanged: (val) => widget.draft.senderPhone = val,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      hintText: 'Số điện thoại người gửi hàng',
                      prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primary),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recipient Contact Info (Thông tin người nhận từng điểm giao & Mở danh bạ)
                  _buildRecipientSection(),

                  const SizedBox(height: 24),

                  // 6. Driver Note
                  const Text(
                    'Ghi chú cho tài xế',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    onChanged: (val) => widget.draft.driverNote = val,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Nhập ghi chú (VD: Hàng dễ vỡ, bốc vác tầng trệt...)',
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2)),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  if (!_validateStep2()) return;
                  _saveDraft();
                  widget.onNext();
                },
                child: const Text(
                  'Tiếp tục sang bước Tính cước & Xác nhận',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Hình ảnh kiện hàng (Tùy chọn)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
            ),
            if (_imageBytes != null)
              InkWell(
                onTap: () {
                  setState(() {
                    _pickedImage = null;
                    _imageBytes = null;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                      SizedBox(width: 4),
                      Text('Xóa ảnh', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _showImageSourceBottomSheet,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _imageBytes != null ? AppColors.primary : AppColors.border,
                width: _imageBytes != null ? 1.5 : 1,
              ),
            ),
            child: _imageBytes != null
                ? Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _imageBytes!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                                SizedBox(width: 4),
                                Text('Đã đính kèm ảnh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _pickedImage?.name ?? 'image.jpg',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Chạm để đổi ảnh khác',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    ],
                  )
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chụp ảnh trực tiếp hoặc chọn từ thư viện',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Giúp tài xế dễ dàng nhận diện và bảo quản kiện hàng',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDimensionSection() {
    if (widget.draft.dropoffAddresses.length > 1) {
      return _buildMultiDropDimensionSection();
    }
    return _buildSingleDropDimensionSection();
  }

  Widget _buildSingleDropDimensionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.straighten_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Kích thước kiện hàng & Kiểm tra xe',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.draft.vehicleType.icon} ${widget.draft.vehicleType.name}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Kích thước lọt lòng thùng xe: ${widget.draft.vehicleType.dimensionSummary}',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        // Textfield mô tả tự do
        TextField(
          controller: _dimensionDescController,
          onChanged: (val) {
            _tryParseDimensionsFromText(val);
            widget.draft.packageDimensionDescription = val;
          },
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Mô tả kích thước (VD: hàng ngang 2.5m, dài 2m, sofa...)',
            prefixIcon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
            fillColor: AppColors.background,
            filled: true,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          ),
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDimensionChip(
                label: 'Sofa 3 chỗ (2.2×0.9m)',
                onTap: () => _applyDimensionPreset(
                  desc: 'Sofa 3 chỗ',
                  length: 2.2,
                  width: 0.9,
                  height: 0.8,
                ),
              ),
              const SizedBox(width: 6),
              _buildDimensionChip(
                label: 'Tủ lạnh (0.8×0.7m)',
                onTap: () => _applyDimensionPreset(
                  desc: 'Tủ lạnh 2 cánh',
                  length: 0.8,
                  width: 0.7,
                  height: 1.8,
                ),
              ),
              const SizedBox(width: 6),
              _buildDimensionChip(
                label: 'Hàng ngang 2.5m (2.0×2.5m)',
                onTap: () => _applyDimensionPreset(
                  desc: 'Hàng ngang 2.5m',
                  length: 2.0,
                  width: 2.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(width: 6),
              _buildDimensionChip(
                label: 'Nệm 1.8m (2.0×1.8m)',
                onTap: () => _applyDimensionPreset(
                  desc: 'Nệm cao su 1.8m',
                  length: 2.0,
                  width: 1.8,
                  height: 0.2,
                ),
              ),
              if (_lengthController.text.isNotEmpty || _widthController.text.isNotEmpty || _heightController.text.isNotEmpty) ...[
                const SizedBox(width: 6),
                ActionChip(
                  label: const Text('Xóa số đo', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                  avatar: const Icon(Icons.clear_rounded, size: 14, color: Colors.red),
                  backgroundColor: const Color(0xFFFEE2E2),
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: _clearDimensions,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3 Inputs: Dài x Rộng (Ngang) x Cao
        Row(
          children: [
            Expanded(
              child: _buildDimensionInputField(
                controller: _lengthController,
                label: 'Dài (m)',
                hint: '0.0',
                onChanged: (_) => _updateDraftDimensions(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDimensionInputField(
                controller: _widthController,
                label: 'Rộng / Ngang (m)',
                hint: '0.0',
                onChanged: (_) => _updateDraftDimensions(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDimensionInputField(
                controller: _heightController,
                label: 'Cao (m)',
                hint: '0.0',
                onChanged: (_) => _updateDraftDimensions(),
              ),
            ),
          ],
        ),

        // Fit Analysis Realtime Card
        _buildFitAnalysisCard(),
      ],
    );
  }

  Widget _buildMultiDropDimensionSection() {
    final activeIdx = _selectedDropoffIndex.clamp(
      0,
      _recipientControllers.isNotEmpty ? _recipientControllers.length - 1 : 0,
    );
    final activeCtrl = _recipientControllers.isNotEmpty ? _recipientControllers[activeIdx] : null;
    final activeAddress = activeIdx < widget.draft.dropoffAddresses.length
        ? widget.draft.dropoffAddresses[activeIdx]
        : 'Điểm giao ${activeIdx + 1}';

    final multiFitResult = CargoFitResult.analyzeMultiDrop(
      vehicle: widget.draft.vehicleType,
      recipients: widget.draft.dropoffRecipients,
      dropoffAddresses: widget.draft.dropoffAddresses,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            const Icon(Icons.straighten_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Kích thước & Phân bổ hàng theo điểm giao',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${widget.draft.vehicleType.icon} ${widget.draft.vehicleType.name}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Kích thước lọt lòng thùng xe: ${widget.draft.vehicleType.dimensionSummary}',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),

        // Dropoff Selector Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(widget.draft.dropoffAddresses.length, (idx) {
              final isSelected = activeIdx == idx;
              final addr = widget.draft.dropoffAddresses[idx];
              final shortAddr = addr.isNotEmpty ? addr.split(',').first : 'Điểm ${idx + 1}';
              final ctrl = idx < _recipientControllers.length ? _recipientControllers[idx] : null;
              final hasData = ctrl != null && (ctrl.itemDescController.text.isNotEmpty || ctrl.lengthController.text.isNotEmpty);

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => setState(() => _selectedDropoffIndex = idx),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            shortAddr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasData) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 13,
                            color: isSelected ? Colors.white : const Color(0xFF16A34A),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),

        // Active Dropoff Card
        if (activeCtrl != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place_rounded, color: AppColors.accent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Điểm ${activeIdx + 1}: $activeAddress',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Textfield mô tả món hàng tại điểm này
                TextField(
                  controller: activeCtrl.itemDescController,
                  onChanged: (val) {
                    _tryParseDimensionsFromText(val, pointIndex: activeIdx);
                    _updateDropoffDimensions(activeIdx);
                  },
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Món hàng giao tại Điểm ${activeIdx + 1} (VD: Sofa 3 chỗ, Bàn ăn...)',
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 18),
                    fillColor: Colors.white,
                    filled: true,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Preset Chips for this point
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDimensionChip(
                        label: 'Sofa (2.2×0.9m)',
                        onTap: () => _applyDropoffDimensionPreset(
                          pointIndex: activeIdx,
                          desc: 'Sofa 3 chỗ',
                          length: 2.2,
                          width: 0.9,
                          height: 0.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildDimensionChip(
                        label: 'Tủ lạnh (0.8×0.7m)',
                        onTap: () => _applyDropoffDimensionPreset(
                          pointIndex: activeIdx,
                          desc: 'Tủ lạnh 2 cánh',
                          length: 0.8,
                          width: 0.7,
                          height: 1.8,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildDimensionChip(
                        label: 'Hàng ngang 2.5m (2.0×2.5m)',
                        onTap: () => _applyDropoffDimensionPreset(
                          pointIndex: activeIdx,
                          desc: 'Hàng ngang 2.5m',
                          length: 2.0,
                          width: 2.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildDimensionChip(
                        label: 'Thùng carton (0.6×0.4m)',
                        onTap: () => _applyDropoffDimensionPreset(
                          pointIndex: activeIdx,
                          desc: 'Thùng carton',
                          length: 0.6,
                          width: 0.4,
                          height: 0.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildDimensionChip(
                        label: 'Nệm 1.8m (2.0×1.8m)',
                        onTap: () => _applyDropoffDimensionPreset(
                          pointIndex: activeIdx,
                          desc: 'Nệm cao su 1.8m',
                          length: 2.0,
                          width: 1.8,
                          height: 0.2,
                        ),
                      ),
                      if (activeCtrl.lengthController.text.isNotEmpty ||
                          activeCtrl.widthController.text.isNotEmpty ||
                          activeCtrl.heightController.text.isNotEmpty ||
                          activeCtrl.itemDescController.text.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ActionChip(
                          label: const Text('Xóa số đo', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                          avatar: const Icon(Icons.clear_rounded, size: 13, color: Colors.red),
                          backgroundColor: const Color(0xFFFEE2E2),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _clearDropoffDimensions(activeIdx),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 3 Inputs: Dài x Rộng (Ngang) x Cao
                Row(
                  children: [
                    Expanded(
                      child: _buildDimensionInputField(
                        controller: activeCtrl.lengthController,
                        label: 'Dài (m)',
                        hint: '0.0',
                        onChanged: (_) => _updateDropoffDimensions(activeIdx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDimensionInputField(
                        controller: activeCtrl.widthController,
                        label: 'Rộng / Ngang (m)',
                        hint: '0.0',
                        onChanged: (_) => _updateDropoffDimensions(activeIdx),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildDimensionInputField(
                        controller: activeCtrl.heightController,
                        label: 'Cao (m)',
                        hint: '0.0',
                        onChanged: (_) => _updateDropoffDimensions(activeIdx),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // Multi-Drop Fit Analysis Realtime Card
        _buildMultiDropFitAnalysisCard(multiFitResult),

        const SizedBox(height: 10),

        // Sơ đồ bốc xếp LIFO Thông minh kết nối lộ trình đa điểm
        _buildMultiDropLifoDiagramCard(),
      ],
    );
  }

  Widget _buildMultiDropFitAnalysisCard(CargoFitResult fitResult) {
    final hasAnyData = widget.draft.dropoffRecipients.any((r) => r.hasDimensions || r.itemsDescription.isNotEmpty);
    if (!hasAnyData) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nhập kích thước hoặc món hàng cho từng điểm giao để hệ thống kiểm tra độ vừa với thùng xe ${widget.draft.vehicleType.name}.',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }

    if (fitResult.fits) {
      final totalVol = widget.draft.totalCargoVolumeM3;
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tất cả món hàng đều vừa vặn với thùng ${widget.draft.vehicleType.name}!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              fitResult.message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFF15803D)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Tổng thể tích: ${totalVol.toStringAsFixed(2)}m³ / Dung tích thùng: ${widget.draft.vehicleType.maxVolumeM3}m³',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cảnh báo: Có món quá khổ so với xe ${widget.draft.vehicleType.name}!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...fitResult.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      issue,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            )),
            if (fitResult.suggestedVehicle != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Gợi ý nâng loại xe: ',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                TextSpan(
                                  text: fitResult.suggestedVehicle!.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Thùng: ${fitResult.suggestedVehicle!.dimensionSummary}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          widget.draft.vehicleType = fitResult.suggestedVehicle!;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã nâng lên ${fitResult.suggestedVehicle!.name}!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Đổi sang ${fitResult.suggestedVehicle!.name}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildMultiDropLifoDiagramCard() {
    final recipients = widget.draft.dropoffRecipients;
    final dropoffs = widget.draft.dropoffAddresses;
    if (dropoffs.length <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_vert_circle_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Sơ đồ xếp dỡ hàng LIFO theo từng điểm',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Dỡ hàng thông minh',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Quy tắc LIFO (Vào trước - Ra sau): Hàng giao điểm 1 dỡ trước nên để ở Cửa sau; hàng giao điểm cuối để sát cabin.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),

          // LIFO Visual Steps
          ...List.generate(dropoffs.length, (idx) {
            final r = idx < recipients.length ? recipients[idx] : null;
            final itemName = (r != null && r.itemsDescription.isNotEmpty)
                ? r.itemsDescription
                : 'Món hàng Điểm ${idx + 1}';
            final dims = (r != null && r.hasDimensions) ? ' (${r.dimensionSummary})' : '';

            String positionTitle;
            Color posColor;
            IconData posIcon;

            if (idx == 0) {
              positionTitle = 'Cửa sau xe (Dỡ đầu tiên)';
              posColor = const Color(0xFF16A34A);
              posIcon = Icons.meeting_room_outlined;
            } else if (idx == dropoffs.length - 1) {
              positionTitle = 'Sát cabin xe (Dỡ sau cùng)';
              posColor = const Color(0xFFD97706);
              posIcon = Icons.airline_seat_recline_normal_rounded;
            } else {
              positionTitle = 'Giữa thùng xe';
              posColor = AppColors.primary;
              posIcon = Icons.view_column_rounded;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: posColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: posColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(posIcon, size: 14, color: posColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$positionTitle: Điểm ${idx + 1}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: posColor),
                        ),
                        Text(
                          '$itemName$dims',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 6),
          // Button to apply LIFO stowage into driver notes
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                final summary = widget.draft.generateLifoStowageSummary();
                setState(() {
                  if (_noteController.text.trim().isEmpty) {
                    _noteController.text = summary;
                  } else if (!_noteController.text.contains('[Sơ đồ xếp xe LIFO]')) {
                    _noteController.text = '${_noteController.text}\n$summary'.trim();
                  } else {
                    _noteController.text = summary;
                  }
                  widget.draft.driverNote = _noteController.text;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã cập nhật sơ đồ xếp dỡ LIFO vào lời dặn bác tài!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.note_add_outlined, size: 16, color: AppColors.primary),
              label: const Text(
                'Lưu sơ đồ LIFO vào lời dặn bác tài',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFitAnalysisCard() {
    final l = double.tryParse(_lengthController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final w = double.tryParse(_widthController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final h = double.tryParse(_heightController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final hasInput = l > 0 || w > 0 || h > 0;

    if (!hasInput) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Nhập kích thước hoặc mô tả để hệ thống phân tích độ vừa vặn với thùng xe ${widget.draft.vehicleType.name}.',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }

    final fitResult = CargoFitResult.analyze(
      vehicle: widget.draft.vehicleType,
      length: l,
      width: w,
      height: h,
    );

    if (fitResult.fits) {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vừa vặn với thùng xe ${widget.draft.vehicleType.name}!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              fitResult.message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.35),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check, size: 14, color: Color(0xFF15803D)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Thùng xe: ${widget.draft.vehicleType.dimensionSummary}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_rounded, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cảnh báo: Kiện hàng quá khổ xe ${widget.draft.vehicleType.name}!',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFFB91C1C)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...fitResult.issues.map((issue) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      issue,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.straighten, size: 14, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Thùng ${widget.draft.vehicleType.name}: ${widget.draft.vehicleType.dimensionSummary}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
            if (fitResult.suggestedVehicle != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Gợi ý xe phù hợp: ',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                TextSpan(
                                  text: fitResult.suggestedVehicle!.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Thùng: ${fitResult.suggestedVehicle!.dimensionSummary}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          widget.draft.vehicleType = fitResult.suggestedVehicle!;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã chuyển sang ${fitResult.suggestedVehicle!.name}!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        'Đổi sang ${fitResult.suggestedVehicle!.name}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Text(
                'Kiện hàng vượt quá kích thước mọi loại xe thông thường. Vui lòng liên hệ hỗ trợ vận tải siêu trường.',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF991B1B)),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildDimensionChip({
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      backgroundColor: const Color(0xFFF1F5F9),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
    );
  }

  Widget _buildDimensionInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: onChanged,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            fillColor: AppColors.background,
            filled: true,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientSection() {
    final isMultiPoint = _recipientControllers.length > 1;

    if (!isMultiPoint && _recipientControllers.isNotEmpty) {
      // Single drop-off recipient
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.move_to_inbox_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Thông tin người nhận hàng',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              InkWell(
                onTap: () => _fillMyInfoAsRecipient(0),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_pin_rounded, size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Điền của tôi',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _pickContactFor(0),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.contacts_rounded, size: 13, color: AppColors.textPrimary),
                      SizedBox(width: 4),
                      Text(
                        'Danh bạ',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _recipientControllers[0].nameController,
            onChanged: (val) {
              if (widget.draft.dropoffRecipients.isNotEmpty) {
                widget.draft.dropoffRecipients[0].name = val;
              }
            },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Họ và tên người nhận hàng',
              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.accent),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _recipientControllers[0].phoneController,
            keyboardType: TextInputType.phone,
            onChanged: (val) {
              if (widget.draft.dropoffRecipients.isNotEmpty) {
                widget.draft.dropoffRecipients[0].phone = val;
              }
            },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Số điện thoại người nhận hàng',
              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.accent),
            ),
          ),
        ],
      );
    }

    // Multiple drop-off recipients (Giao đa điểm)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.hub_rounded, color: AppColors.accent, size: 18),
            const SizedBox(width: 6),
            Text(
              'Thông tin người nhận hàng (${_recipientControllers.length} điểm giao)',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Thiết lập người nhận và số điện thoại riêng cho từng điểm giao',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        ...List.generate(_recipientControllers.length, (i) {
          final addr = i < widget.draft.dropoffAddresses.length ? widget.draft.dropoffAddresses[i] : '';
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Điểm giao ${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _fillMyInfoAsRecipient(i),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_pin_rounded, size: 12, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Điền của tôi',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _pickContactFor(i),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.contacts_rounded, size: 12, color: AppColors.textPrimary),
                                SizedBox(width: 4),
                                Text(
                                  'Danh bạ',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (addr.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    addr,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: _recipientControllers[i].nameController,
                  onChanged: (val) {
                    if (i < widget.draft.dropoffRecipients.length) {
                      widget.draft.dropoffRecipients[i].name = val;
                    }
                  },
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Họ và tên người nhận điểm ${i + 1}',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.accent, size: 18),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _recipientControllers[i].phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: (val) {
                    if (i < widget.draft.dropoffRecipients.length) {
                      widget.draft.dropoffRecipients[i].phone = val;
                    }
                  },
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Số điện thoại người nhận điểm ${i + 1}',
                    prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.accent, size: 18),
                    fillColor: Colors.white,
                    filled: true,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
