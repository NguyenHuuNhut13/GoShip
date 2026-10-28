import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/firestore_order_service.dart';
import '../../../../../core/services/order_repository.dart';
import '../../models/order_draft_model.dart';
import '../order_detail_screen.dart';

class Step3ConfirmPricingScreen extends StatefulWidget {
  final OrderDraftModel draft;
  final VoidCallback onBack;
  final VoidCallback onOrderCompleted;

  const Step3ConfirmPricingScreen({
    super.key,
    required this.draft,
    required this.onBack,
    required this.onOrderCompleted,
  });

  @override
  State<Step3ConfirmPricingScreen> createState() => _Step3ConfirmPricingScreenState();
}

class _Step3ConfirmPricingScreenState extends State<Step3ConfirmPricingScreen> {
  // Empty by default
  late final TextEditingController _promoController;
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');
  bool _promoApplied = false;
  bool _isSubmitting = false;

  final List<Map<String, String>> _availableVouchers = [
    {
      'code': 'WELCOME30',
      'title': 'Giảm 30% cho khách hàng mới',
      'desc': 'Áp dụng cho mọi loại phương tiện (Tối đa 50.000đ)',
      'expiry': 'HSD: 30 ngày',
      'discountType': 'percent',
      'discountValue': '0.3',
    },
    {
      'code': 'GOSHIP50',
      'title': 'Giảm 50% cước phí toàn sàn',
      'desc': 'Ưu đãi đặc biệt trên trang chủ (Tối đa 50.000đ)',
      'expiry': 'HSD: Hôm nay',
      'discountType': 'percent',
      'discountValue': '0.5',
    },
    {
      'code': 'GOSHIP15',
      'title': 'Giảm ngay 15.000đ cước vận chuyển',
      'desc': 'Áp dụng cho đơn hàng từ 40.000đ',
      'expiry': 'HSD: 7 ngày',
      'discountType': 'fixed',
      'discountValue': '15000',
    },
    {
      'code': 'FREESHIP',
      'title': 'Miễn phí giao hàng (Freeship)',
      'desc': 'Giảm trực tiếp 25.000đ phí giao hàng',
      'expiry': 'HSD: Hôm nay',
      'discountType': 'fixed',
      'discountValue': '25000',
    },
    {
      'code': 'SUPERDEAL',
      'title': 'Siêu ưu đãi tiết kiệm 20%',
      'desc': 'Giảm 20% cho đơn giao đa điểm (Tối đa 35.000đ)',
      'expiry': 'HSD: 14 ngày',
      'discountType': 'percent',
      'discountValue': '0.2',
    },
    {
      'code': 'TRUCK50',
      'title': 'Trợ giá 50.000đ cho Xe tải / Xe van',
      'desc': 'Áp dụng cho Xe van, Xe tải hoặc Container',
      'expiry': 'HSD: 15 ngày',
      'discountType': 'fixed',
      'discountValue': '50000',
    },
  ];

  @override
  void initState() {
    super.initState();
    _promoController = TextEditingController(text: widget.draft.promoCode);
    _loadCloudVouchers();
    if (widget.draft.promoCode.isNotEmpty && widget.draft.discountAmount <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyPromoCode(widget.draft.promoCode);
      });
    } else {
      _promoApplied = widget.draft.promoCode.isNotEmpty && widget.draft.discountAmount > 0;
    }
  }

  Future<void> _loadCloudVouchers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('vouchers').where('isActive', isEqualTo: true).get();
      if (snap.docs.isNotEmpty) {
        final List<Map<String, String>> cloudVouchers = [];
        for (final doc in snap.docs) {
          final data = doc.data();
          final code = (data['code'] ?? '').toString().toUpperCase();
          if (code.isEmpty) continue;
          final discountPercent = (data['discountPercent'] as num?)?.toDouble() ?? 0.0;
          final discountAmount = (data['discountAmount'] as num?)?.toDouble() ?? 0.0;

          cloudVouchers.add({
            'code': code,
            'title': (data['description'] ?? 'Mã ưu đãi $code').toString(),
            'desc': discountPercent > 0
                ? 'Giảm ${(discountPercent * (discountPercent < 1 ? 100 : 1)).round()}% (Tối đa ${_currencyFormat.format((data['maxDiscount'] as num?)?.toDouble() ?? 50000)}đ)'
                : 'Giảm trực tiếp ${_currencyFormat.format(discountAmount)}đ',
            'expiry': data['expiryDate'] != null ? 'HSD: ${data['expiryDate']}' : 'HSD: Dài hạn',
            'discountType': discountPercent > 0 ? 'percent' : 'fixed',
            'discountValue': discountPercent > 0
                ? (discountPercent > 1 ? (discountPercent / 100).toString() : discountPercent.toString())
                : discountAmount.toString(),
          });
        }
        if (mounted && cloudVouchers.isNotEmpty) {
          setState(() {
            for (final cv in cloudVouchers) {
              _availableVouchers.removeWhere((v) => v['code'] == cv['code']);
              _availableVouchers.insert(0, cv);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('>>> [Load Cloud Vouchers Warning]: $e');
    }
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  void _applyPromoCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return;

    final voucher = _availableVouchers.firstWhere(
      (v) => v['code'] == cleanCode,
      orElse: () => {},
    );

    if (voucher.isEmpty) {
      setState(() {
        widget.draft.promoCode = '';
        widget.draft.discountAmount = 0.0;
        _promoApplied = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã giảm giá không hợp lệ hoặc đã hết hạn')),
      );
      return;
    }

    // Kiểm tra điều kiện áp dụng thực tế của từng voucher
    final int feeBefore = widget.draft.totalFeeBeforeDiscount;
    if (cleanCode == 'GOSHIP15' && feeBefore < 40000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã GOSHIP15 yêu cầu cước đơn hàng tối thiểu 40.000đ')),
      );
      return;
    }
    if (cleanCode == 'TRUCK50' && widget.draft.vehicleType == OrderVehicleType.motorbike) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mã TRUCK50 chỉ áp dụng cho Xe van, Xe tải hoặc Container')),
      );
      return;
    }

    setState(() {
      widget.draft.promoCode = cleanCode;
      _promoController.text = cleanCode;

      final type = voucher['discountType'];
      final val = double.parse(voucher['discountValue']!);
      final double maxCap = cleanCode == 'SUPERDEAL' ? 35000.0 : 50000.0;
      if (type == 'percent') {
        widget.draft.discountAmount = (feeBefore * val).clamp(0.0, maxCap);
      } else {
        widget.draft.discountAmount = val.clamp(0.0, feeBefore.toDouble());
      }
      _promoApplied = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Áp dụng thành công mã $cleanCode: -${_currencyFormat.format(widget.draft.discountAmount.round())} đ'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removePromoCode() {
    setState(() {
      _promoController.clear();
      widget.draft.promoCode = '';
      widget.draft.discountAmount = 0.0;
      _promoApplied = false;
    });
  }

  void _showVoucherPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mã giảm giá GoShip',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _availableVouchers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (c, idx) {
                    final v = _availableVouchers[idx];
                    final isApplied = _promoController.text.trim().toUpperCase() == v['code'];

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isApplied ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isApplied ? AppColors.primary : const Color(0xFFE2E8F0),
                          width: isApplied ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isApplied ? AppColors.primary : const Color(0xFFFF6B00).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.confirmation_number_outlined,
                              color: isApplied ? Colors.white : const Color(0xFFFF6B00),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        v['code']!,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      v['expiry']!,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  v['title']!,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                ),
                                Text(
                                  v['desc']!,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isApplied ? AppColors.success : AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _applyPromoCode(v['code']!);
                            },
                            child: Text(
                              isApplied ? 'Đang dùng' : 'Chọn',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _showWalletPaymentConfirmationSheet(PaymentMethod method, int amount) async {
    final isMomo = method == PaymentMethod.momo;
    final Color brandColor = isMomo ? const Color(0xFFA50064) : const Color(0xFF0068FF);
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'CỔNG THANH TOÁN ĐIỆN TỬ ${method.title.toUpperCase()}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: brandColor),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${_currencyFormat.format(amount)} đ',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Quét mã QR hoặc xác nhận liên kết ${method.title}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: brandColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2_rounded, size: 150, color: brandColor),
                    const SizedBox(height: 8),
                    Text(
                      'Thụ hưởng: CONG TY TNHH GOSHIP LOGISTICS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: brandColor),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tài xế sẽ không thu thêm tiền mặt khi giao hàng',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Đổi phương thức', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: brandColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                      label: const Text(
                        'Xác nhận đã thanh toán',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result == true;
  }

  void _handlePlaceOrder() async {
    if (widget.draft.paymentMethod != PaymentMethod.cash && widget.draft.finalTotalFee > 0) {
      final paid = await _showWalletPaymentConfirmationSheet(
        widget.draft.paymentMethod,
        widget.draft.finalTotalFee,
      );
      if (!paid || !mounted) return;
    }

    setState(() => _isSubmitting = true);

    final generatedOrderCode = 'GS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}-VN';
    final selectedDriver = widget.draft.selectedDriver;
    final isDirect = selectedDriver != null && selectedDriver.id.isNotEmpty;

    final orderRecord = OrderRecord.fromDraft(
      draft: widget.draft,
      orderCode: generatedOrderCode,
      status: isDirect ? OrderStatus.pendingDirect : OrderStatus.pending,
      assignedDriverId: isDirect ? selectedDriver.id : null,
      assignedDriverName: isDirect ? selectedDriver.name : null,
    );

    // Save to real Firestore Database + local cache
    await FirestoreOrderService.createOrder(
      order: orderRecord,
      assignedDriverId: isDirect ? selectedDriver.id : null,
      assignedDriverName: isDirect ? selectedDriver.name : null,
      directTimeoutSeconds: 45,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          draft: widget.draft,
          orderCode: generatedOrderCode,
          orderStatus: isDirect ? OrderStatus.pendingDirect : OrderStatus.pending,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final totalFee = draft.finalTotalFee;

    final pickupDisplay = draft.pickupAddress.isNotEmpty ? draft.pickupAddress : 'Landmark 81, Quận Bình Thạnh';
    final dropoffList = draft.dropoffAddresses.where((a) => a.isNotEmpty).toList();
    if (dropoffList.isEmpty) dropoffList.add('25 Điện Biên Phủ, Quận 3');

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
          'Xác nhận & Thanh toán',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
        actions: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 16),
            child: const Text(
              'Bước 3/3',
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
                  // 1. Summary Card (Figma summary-card: #F7F9FC)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin đơn hàng',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 12),

                        // Route: Pickup
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lấy: $pickupDisplay',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                  ),
                                  if (draft.senderName.isNotEmpty || draft.senderPhone.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Người gửi: ${draft.senderName}${draft.senderPhone.isNotEmpty ? ' (${draft.senderPhone})' : ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Route: Dropoffs
                        ...dropoffList.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final addr = entry.value;
                          final label = dropoffList.length > 1
                              ? 'Giao ${idx + 1}: $addr'
                              : 'Giao: $addr';
                          final recipient = (idx < draft.dropoffRecipients.length)
                              ? draft.dropoffRecipients[idx]
                              : DropoffRecipient();

                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                      ),
                                      if (recipient.name.isNotEmpty || recipient.phone.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFF7ED),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                                          ),
                                          child: Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 6,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.person_rounded, size: 12, color: AppColors.accent),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    recipient.name.isNotEmpty ? recipient.name : 'Người nhận',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9A3412)),
                                                  ),
                                                ],
                                              ),
                                              if (recipient.phone.isNotEmpty)
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.phone_rounded, size: 11, color: AppColors.accent),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      recipient.phone,
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9A3412)),
                                                    ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (recipient.itemsDescription.isNotEmpty || recipient.hasDimensions) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.inventory_2_outlined, size: 12, color: AppColors.primary),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Hàng: ${recipient.itemsDescription}${recipient.hasDimensions ? " (${recipient.dimensionSummary})" : ""}',
                                                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFEDEFF4)),
                        const SizedBox(height: 12),

                        // Details Row: Distance & Time (Figma details-row)
                        Wrap(
                          spacing: 16,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Khoảng cách: ${draft.distanceKm > 0 ? draft.distanceKm : 7.2} km',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 6),
                                Text(
                                  'Thời gian: ~${draft.durationMinutes > 0 ? draft.durationMinutes : 20} phút',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Package Row (Figma pkg-row)
                        Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Kiện hàng: ${draft.packageCategory} (${draft.weightCategory})',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 2. Payment Method Section (Figma payment-method-section)
                  const Text(
                    'Phương thức thanh toán',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),

                  _buildPaymentMethodCard(
                    method: PaymentMethod.cash,
                    title: 'Tiền mặt',
                    desc: 'Thanh toán khi lấy/giao',
                    icon: Icons.payments_outlined,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentMethodCard(
                    method: PaymentMethod.momo,
                    title: 'Ví MoMo',
                    desc: 'Liên kết ví siêu tiện lợi',
                    icon: Icons.account_balance_wallet_outlined,
                    iconBg: const Color(0xFFFDF2F8),
                    iconColor: const Color(0xFFD946EF),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentMethodCard(
                    method: PaymentMethod.zalopay,
                    title: 'ZaloPay',
                    desc: 'Quét mã thanh toán',
                    icon: Icons.qr_code_2_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF0284C7),
                  ),

                  const SizedBox(height: 24),

                  // 3. Promo Code Section (Tap to open voucher list)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Mã giảm giá',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E283A)),
                      ),
                      GestureDetector(
                        onTap: _showVoucherPickerModal,
                        child: const Row(
                          children: [
                            Icon(Icons.discount_outlined, color: AppColors.primary, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Chọn từ danh sách ưu đãi',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _promoApplied ? AppColors.success : const Color(0xFFEDEFF4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, color: AppColors.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _promoController,
                            textCapitalization: TextCapitalization.characters,
                            readOnly: false,
                            onTap: () {
                              if (_promoController.text.isEmpty) {
                                _showVoucherPickerModal();
                              }
                            },
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.8),
                            decoration: const InputDecoration(
                              hintText: 'Nhập hoặc chọn mã giảm giá',
                              hintStyle: TextStyle(color: Color(0xFF7A879E), fontWeight: FontWeight.normal),
                              border: InputBorder.none,
                              isDense: true,
                              filled: false,
                            ),
                          ),
                        ),
                        if (_promoApplied)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                            onPressed: _removePromoCode,
                            tooltip: 'Xóa mã',
                          ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _promoApplied ? AppColors.success : AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (_promoController.text.trim().isEmpty) {
                              _showVoucherPickerModal();
                            } else {
                              _applyPromoCode(_promoController.text);
                            }
                          },
                          child: Text(
                            _promoApplied ? 'Đã áp dụng' : (_promoController.text.trim().isEmpty ? 'Xem mã' : 'Áp dụng'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),



                  const SizedBox(height: 24),

                  // 4. Price Breakdown Details
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        _buildPriceRow('Phương tiện (${draft.vehicleType.name})', '${_currencyFormat.format(draft.baseDeliveryFee)} đ'),
                        if (draft.multiStopSurcharge > 0) ...[
                          const SizedBox(height: 6),
                          _buildPriceRow('Phụ phí thêm điểm giao (${dropoffList.length - 1} điểm)', '+${_currencyFormat.format(draft.multiStopSurcharge)} đ'),
                        ],
                        if (draft.weightSurcharge > 0) ...[
                          const SizedBox(height: 6),
                          _buildPriceRow('Phụ phí khối lượng (${draft.weightCategory})', '+${_currencyFormat.format(draft.weightSurcharge)} đ'),
                        ],
                        if (draft.discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          _buildPriceRow('Giảm giá (${draft.promoCode})', '-${_currencyFormat.format(draft.discountAmount.round())} đ', isDiscount: true),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Bottom Payment Bar (Figma bottom-payment-bar)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFEDEFF4))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Price summary row (Figma price-summary-row)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tổng phí vận chuyển',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${_currencyFormat.format(totalFee)} đ',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFFF6B00)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Big Orange Action Button (Figma btn-Đặt đơn ngay: #FF6B00, height: 50)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B00),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _isSubmitting ? null : _handlePlaceOrder,
                    child: _isSubmitting
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text(
                            'Đặt đơn ngay',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard({
    required PaymentMethod method,
    required String title,
    required String desc,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
  }) {
    final isSelected = widget.draft.paymentMethod == method;

    return GestureDetector(
      onTap: () => setState(() => widget.draft.paymentMethod = method),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFEDEFF4),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
                  width: 2,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(Icons.circle, color: Colors.white, size: 8),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDiscount ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
