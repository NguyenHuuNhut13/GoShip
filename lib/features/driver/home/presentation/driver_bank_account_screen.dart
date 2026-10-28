import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/firestore_order_service.dart';

class BankItem {
  final String code;
  final String shortName;
  final String fullName;
  final Color primaryColor;

  const BankItem({
    required this.code,
    required this.shortName,
    required this.fullName,
    required this.primaryColor,
  });
}

class DriverBankAccountScreen extends StatefulWidget {
  final String? driverId;
  final String? initialBankName;
  final String? initialAccountNo;
  final String? initialHolderName;
  final String? initialBranch;

  const DriverBankAccountScreen({
    super.key,
    this.driverId,
    this.initialBankName,
    this.initialAccountNo,
    this.initialHolderName,
    this.initialBranch,
  });

  @override
  State<DriverBankAccountScreen> createState() => _DriverBankAccountScreenState();
}

class _DriverBankAccountScreenState extends State<DriverBankAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _accountNoController;
  late TextEditingController _holderNameController;
  late TextEditingController _branchController;

  static const List<BankItem> supportedBanks = [
    BankItem(code: 'MB', shortName: 'MB Bank', fullName: 'Ngân hàng Quân đội (MB)', primaryColor: Color(0xFF0038A8)),
    BankItem(code: 'VCB', shortName: 'Vietcombank', fullName: 'Ngân hàng Ngoại thương Việt Nam', primaryColor: Color(0xFF006838)),
    BankItem(code: 'TCB', shortName: 'Techcombank', fullName: 'Ngân hàng Kỹ Thương Việt Nam', primaryColor: Color(0xFFE31837)),
    BankItem(code: 'BIDV', shortName: 'BIDV', fullName: 'Ngân hàng Đầu tư và Phát triển VN', primaryColor: Color(0xFF006B68)),
    BankItem(code: 'CTG', shortName: 'VietinBank', fullName: 'Ngân hàng Công Thương Việt Nam', primaryColor: Color(0xFF004B87)),
    BankItem(code: 'VPB', shortName: 'VPBank', fullName: 'Ngân hàng Thịnh Vượng (VPBank)', primaryColor: Color(0xFF009A44)),
    BankItem(code: 'ACB', shortName: 'ACB', fullName: 'Ngân hàng Á Châu (ACB)', primaryColor: Color(0xFF005BAA)),
    BankItem(code: 'TPB', shortName: 'TPBank', fullName: 'Ngân hàng Tiên Phong (TPBank)', primaryColor: Color(0xFF862D86)),
    BankItem(code: 'STB', shortName: 'Sacombank', fullName: 'Ngân hàng Sài Gòn Thương Tín', primaryColor: Color(0xFF005DAA)),
    BankItem(code: 'VBA', shortName: 'Agribank', fullName: 'Ngân hàng Nông nghiệp & PT Nông thôn', primaryColor: Color(0xFF8B181B)),
    BankItem(code: 'HDB', shortName: 'HDBank', fullName: 'Ngân hàng Phát triển TP.HCM', primaryColor: Color(0xFFED1C24)),
    BankItem(code: 'OCB', shortName: 'OCB', fullName: 'Ngân hàng Phương Đông', primaryColor: Color(0xFF007A3D)),
  ];

  late BankItem _selectedBank;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBank = supportedBanks.first;
    _accountNoController = TextEditingController();
    _holderNameController = TextEditingController();
    _branchController = TextEditingController();
    _loadSavedBankDetails();
  }

  @override
  void dispose() {
    _accountNoController.dispose();
    _holderNameController.dispose();
    _branchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedBankDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String savedBankName = prefs.getString('driver_bank_name') ?? widget.initialBankName ?? 'MB Bank';
      String savedAccountNo = prefs.getString('driver_bank_account_no') ?? widget.initialAccountNo ?? '0917795211';
      String savedHolder = prefs.getString('driver_bank_holder') ?? widget.initialHolderName ?? 'NGUYEN HUU NHUT';
      String savedBranch = prefs.getString('driver_bank_branch') ?? widget.initialBranch ?? 'Chi nhánh TP. Hồ Chí Minh';

      // Đồng bộ từ Cloud Firestore nếu có driverId
      if (widget.driverId != null && widget.driverId!.isNotEmpty) {
        final cloudWallet = await FirestoreOrderService.getDriverWallet(widget.driverId!);
        if (cloudWallet != null) {
          if (cloudWallet['bank_name']?.toString().isNotEmpty == true) {
            savedBankName = cloudWallet['bank_name'].toString();
          }
          if (cloudWallet['account_no']?.toString().isNotEmpty == true) {
            savedAccountNo = cloudWallet['account_no'].toString();
          }
          if (cloudWallet['holder_name']?.toString().isNotEmpty == true) {
            savedHolder = cloudWallet['holder_name'].toString();
          }
          if (cloudWallet['branch']?.toString().isNotEmpty == true) {
            savedBranch = cloudWallet['branch'].toString();
          }
        }
      }

      final matchedBank = supportedBanks.firstWhere(
        (b) => b.shortName.toLowerCase() == savedBankName.toLowerCase() || b.code.toLowerCase() == savedBankName.toLowerCase(),
        orElse: () => supportedBanks.first,
      );

      if (mounted) {
        setState(() {
          _selectedBank = matchedBank;
          _accountNoController.text = savedAccountNo;
          _holderNameController.text = savedHolder;
          _branchController.text = savedBranch;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final bankName = _selectedBank.shortName;
      final accountNo = _accountNoController.text.trim();
      final holderName = _holderNameController.text.trim().toUpperCase();
      final branch = _branchController.text.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('driver_bank_name', bankName);
      await prefs.setString('driver_bank_code', _selectedBank.code);
      await prefs.setString('driver_bank_account_no', accountNo);
      await prefs.setString('driver_bank_holder', holderName);
      await prefs.setString('driver_bank_branch', branch);

      if (widget.driverId != null && widget.driverId!.isNotEmpty) {
        await FirestoreOrderService.saveDriverWallet(
          driverId: widget.driverId!,
          bankName: bankName,
          accountNo: accountNo,
          holderName: holderName,
          branch: branch,
        );
      }

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã cập nhật & đồng bộ tài khoản nhận tiền $bankName lên Cloud!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu tài khoản: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBankSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Chọn ngân hàng thụ hưởng',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: supportedBanks.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
                itemBuilder: (ctx, idx) {
                  final bank = supportedBanks[idx];
                  final isSelected = bank.code == _selectedBank.code;
                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: bank.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: bank.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text(
                          bank.code,
                          style: TextStyle(
                            color: bank.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      bank.shortName,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 14,
                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      bank.fullName,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      setState(() => _selectedBank = bank);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final accountNo = _accountNoController.text.trim().isNotEmpty
        ? _accountNoController.text.trim()
        : '•••• •••• ••••';
    final holderName = _holderNameController.text.trim().isNotEmpty
        ? _holderNameController.text.trim().toUpperCase()
        : 'NGUYEN HUU NHUT';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tài khoản nhận tiền (Payout)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
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
              // Virtual Bank Card Preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _selectedBank.primaryColor,
                      const Color(0xFF0F172A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedBank.primaryColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedBank.code,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedBank.shortName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981), width: 1),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF34D399)),
                              SizedBox(width: 4),
                              Text(
                                'Mặc định nhận',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      accountNo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CHỦ TÀI KHOẢN',
                                style: TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                holderName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.contactless_rounded, color: Colors.white60, size: 28),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Title Section
              const Text(
                'Thông tin tài khoản thụ hưởng',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              const Text(
                'Thu nhập từ các cuốc giao hàng sau khi kết thúc sẽ được đối soát và rút trực tiếp về tài khoản này 24/7.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),

              const SizedBox(height: 18),

              // Bank Selector Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ngân hàng thụ hưởng',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: _showBankSelector,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _selectedBank.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _selectedBank.code,
                                style: TextStyle(
                                  color: _selectedBank.primaryColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedBank.shortName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedBank.fullName,
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Account Number Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Số tài khoản ngân hàng',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _accountNoController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(20),
                    ],
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 1, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Nhập số tài khoản ngân hàng',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted, letterSpacing: 0),
                      prefixIcon: const Icon(Icons.credit_card_rounded, color: AppColors.primary, size: 20),
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
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập số tài khoản ngân hàng';
                      }
                      if (val.trim().length < 6) {
                        return 'Số tài khoản không hợp lệ (tối thiểu 6 chữ số)';
                      }
                      return null;
                    },
                    onChanged: (val) => setState(() {}),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Account Holder Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tên chủ tài khoản (Viết in hoa không dấu)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _holderNameController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'VD: NGUYEN VAN A',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary, size: 20),
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
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Vui lòng nhập tên chủ tài khoản';
                      }
                      return null;
                    },
                    onChanged: (val) => setState(() {}),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Branch Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi nhánh phát hành (Tùy chọn)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _branchController,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'VD: Chi nhánh TP. Hồ Chí Minh',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.location_city_rounded, color: AppColors.primary, size: 20),
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
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Note card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hệ thống bảo mật liên ngân hàng Napas 24/7. Tên chủ tài khoản phải khớp hoàn toàn với thông tin định danh CCCD của tài xế.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isSaving ? null : _saveBankDetails,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Đang lưu...' : 'Lưu tài khoản nhận tiền',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
