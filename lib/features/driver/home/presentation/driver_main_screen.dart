import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/firestore_order_service.dart';
import '../../../../core/services/order_repository.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/presentation/unified_login_screen.dart';
import '../../../customer/home/presentation/customer_main_screen.dart';
import '../../../customer/order/models/order_draft_model.dart';
import '../../../customer/order/presentation/order_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'driver_bank_account_screen.dart';
import 'driver_edit_profile_screen.dart';
import 'driver_home_tab.dart';
import 'widgets/driver_weekly_revenue_chart.dart';

class DriverMainScreen extends StatefulWidget {
  final UserModel user;
  const DriverMainScreen({super.key, required this.user});

  @override
  State<DriverMainScreen> createState() => _DriverMainScreenState();
}

class _DriverMainScreenState extends State<DriverMainScreen> {
  int _currentIndex = 0;
  final NumberFormat _currencyFormat = NumberFormat('#,###', 'vi_VN');
  final DateFormat _dateFormat = DateFormat('dd/MM HH:mm');

  late UserModel _currentUser;
  String _savedBankName = 'MB Bank';
  String _savedAccountNo = '0917795211';
  String _savedHolderName = 'NGUYEN HUU NHUT';
  String _savedBranch = 'Chi nhánh TP. Hồ Chí Minh';
  int _walletBalance = 1500000;
  int _depositBalance = 500000;
  List<Map<String, dynamic>> _walletTransactions = [];
  StreamSubscription<Map<String, dynamic>?>? _walletStreamSub;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadSavedBankInfo();
    _initWalletStream();
    _syncDriverCloudProfile();
  }

  Future<void> _syncDriverCloudProfile() async {
    try {
      final cloudUser = await AuthService.fetchCloudProfile(_currentUser);
      if (mounted) {
        setState(() => _currentUser = cloudUser);
        await AuthService.saveSession(cloudUser, syncCloud: false);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _walletStreamSub?.cancel();
    super.dispose();
  }

  void _initWalletStream() {
    _walletStreamSub?.cancel();
    _walletStreamSub = FirestoreOrderService.streamDriverWallet(_driverId).listen((data) async {
      if (!mounted || data == null) return;
      final bankName = (data['bank_name'] as String?) ?? '';
      final accountNo = ((data['bank_account_no'] ?? data['account_no']) as String?) ?? '';
      final holder = ((data['bank_holder'] ?? data['holder_name']) as String?) ?? '';
      final branch = ((data['bank_branch'] ?? data['branch']) as String?) ?? '';
      final cloudWallet = (data['wallet_balance'] as num?)?.toInt();
      final cloudDeposit = (data['deposit_balance'] as num?)?.toInt();
      final rawTx = data['transactions'] as List?;
      final List<Map<String, dynamic>>? cloudTx = rawTx
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        if (bankName.isNotEmpty) _savedBankName = bankName;
        if (accountNo.isNotEmpty) _savedAccountNo = accountNo;
        if (holder.isNotEmpty) _savedHolderName = holder;
        if (branch.isNotEmpty) _savedBranch = branch;
        if (cloudWallet != null) _walletBalance = cloudWallet;
        if (cloudDeposit != null) _depositBalance = cloudDeposit;
        if (cloudTx != null && cloudTx.isNotEmpty) {
          _walletTransactions = cloudTx.reversed.toList();
        }
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        if (bankName.isNotEmpty) await prefs.setString('driver_bank_name', bankName);
        if (accountNo.isNotEmpty) await prefs.setString('driver_bank_account_no', accountNo);
        if (holder.isNotEmpty) await prefs.setString('driver_bank_holder', holder);
        if (branch.isNotEmpty) await prefs.setString('driver_bank_branch', branch);
        if (cloudWallet != null) await prefs.setInt('driver_wallet_balance', cloudWallet);
        if (cloudDeposit != null) await prefs.setInt('driver_deposit_balance', cloudDeposit);
        if (cloudTx != null && cloudTx.isNotEmpty) {
          await prefs.setString('driver_wallet_transactions_$_driverId', jsonEncode(cloudTx));
        }
      } catch (_) {}
    });
  }

  Future<void> _loadSavedBankInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawTx = prefs.getString('driver_wallet_transactions_$_driverId');
      List<Map<String, dynamic>> localTx = [];
      if (rawTx != null && rawTx.isNotEmpty) {
        final decoded = jsonDecode(rawTx) as List;
        localTx = decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (mounted) {
        setState(() {
          _savedBankName = prefs.getString('driver_bank_name') ?? 'MB Bank';
          _savedAccountNo = prefs.getString('driver_bank_account_no') ?? '0917795211';
          _savedHolderName = prefs.getString('driver_bank_holder') ?? 'NGUYEN HUU NHUT';
          _savedBranch = prefs.getString('driver_bank_branch') ?? 'Chi nhánh TP. Hồ Chí Minh';
          _walletBalance = prefs.getInt('driver_wallet_balance') ?? 1500000;
          _depositBalance = prefs.getInt('driver_deposit_balance') ?? 500000;
          if (localTx.isNotEmpty && _walletTransactions.isEmpty) {
            _walletTransactions = localTx.reversed.toList();
          }
        });
      }
    } catch (_) {}
  }

  String get _driverId => _currentUser.id.isNotEmpty
      ? _currentUser.id
      : (_currentUser.phone.isNotEmpty ? _currentUser.phone : 'drv_02');

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DriverHomeTab(
        user: _currentUser,
        onProfileUpdated: (updated) {
          setState(() => _currentUser = updated);
        },
      ),
      _buildHistoryTab(),
      _buildWalletTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              activeIcon: Icon(Icons.location_on_rounded),
              label: 'Nhận đơn',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_toggle_off_rounded),
              label: 'Lịch sử',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Ví thu nhập',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPER: BUILD EPOD IMAGE ====================
  Widget _buildEpodImage(String path, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    if (path.startsWith('data:image')) {
      try {
        final commaIdx = path.indexOf(',');
        final b64Str = commaIdx != -1 ? path.substring(commaIdx + 1) : path;
        final bytes = base64Decode(b64Str);
        return Image.memory(bytes, fit: fit, width: width, height: height);
      } catch (_) {
        return const Icon(Icons.broken_image_rounded);
      }
    } else if (path.startsWith('http')) {
      return Image.network(path, fit: fit, width: width, height: height);
    } else if (!kIsWeb) {
      return Image.file(File(path), fit: fit, width: width, height: height);
    } else {
      return const Icon(Icons.photo_outlined);
    }
  }

  void _showFullImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: _buildEpodImage(imagePath, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== TAB 2: LỊCH SỬ CUỐC XE & ĐÁNH GIÁ 2 CHIỀU ====================

  void _showRateCustomerModal(OrderRecord order) {
    int tempRating = order.driverRating ?? 5;
    final commentCtrl = TextEditingController(text: order.driverComment ?? '');
    final List<String> availableTags = [
      'Khách đúng giờ',
      'Thanh toán nhanh gọn',
      'Giao tiếp lịch sự',
      'Hàng hóa chuẩn bị sẵn',
      'Vị trí nhận dễ tìm',
      'Hỗ trợ bốc dỡ nhiệt tình',
    ];
    final Set<String> selectedTags = Set<String>.from(order.driverTags ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          String ratingDesc = 'Khách hàng tuyệt vời!';
          if (tempRating == 1) ratingDesc = 'Rất không hài lòng';
          if (tempRating == 2) ratingDesc = 'Chưa hài lòng';
          if (tempRating == 3) ratingDesc = 'Bình thường';
          if (tempRating == 4) ratingDesc = 'Khá hài lòng';

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                const Text(
                  'Đánh giá Khách hàng (Hai chiều)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cuốc ${order.orderCode} • Khách: ${order.senderName}',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),

                // Stars Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    final star = idx + 1;
                    return IconButton(
                      iconSize: 36,
                      icon: Icon(
                        star <= tempRating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFB800),
                      ),
                      onPressed: () => setModalState(() => tempRating = star),
                    );
                  }),
                ),
                Text(
                  ratingDesc,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.accent),
                ),

                const SizedBox(height: 16),

                // Tags
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: availableTags.map((tag) {
                    final isSel = selectedTags.contains(tag);
                    return FilterChip(
                      selected: isSel,
                      label: Text(tag, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500)),
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: commentCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Nhận xét của bạn về người gửi/nhận này...',
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final ok = await FirestoreOrderService.submitDriverRatingForCustomer(
                        orderCode: order.orderCode,
                        rating: tempRating,
                        comment: commentCtrl.text.trim(),
                        tags: selectedTags.toList(),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Đã lưu đánh giá khách hàng ${order.senderName} ($tempRating sao) lên hệ thống!'
                                : 'Đã ghi nhận đánh giá khách hàng!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text('Lưu đánh giá khách hàng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lịch sử cuốc xe & Đánh giá hai chiều', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<OrderRecord>>(
        stream: FirestoreOrderService.streamDriverOrderHistory(_driverId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return _buildEmptyHistoryView();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (ctx, idx) => _buildRealTripCard(orders[idx]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyHistoryView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chưa có cuốc xe nào được ghi nhận',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Khi bạn nhận và hoàn thành các cuốc xe từ khách hàng, lịch sử chuyến đi và chứng từ e-POD sẽ xuất hiện tại đây.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.near_me_rounded, color: Colors.white, size: 18),
              label: const Text('Bật nhận cuốc ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealTripCard(OrderRecord order) {
    final bool driverRated = order.driverRating != null;
    final int driverRating = order.driverRating ?? 5;
    final String driverComment = order.driverComment ?? '';
    final List<String> driverTags = order.driverTags ?? [];

    Color statusColor;
    String statusLabel;
    switch (order.status) {
      case OrderStatus.completed:
        statusColor = AppColors.success;
        statusLabel = 'Hoàn thành';
        break;
      case OrderStatus.delivering:
        statusColor = AppColors.primary;
        statusLabel = 'Đang giao';
        break;
      case OrderStatus.cancelled:
        statusColor = AppColors.danger;
        statusLabel = 'Đã hủy';
        break;
      default:
        statusColor = AppColors.accent;
        statusLabel = order.status.label;
    }

    final dropoffSummary = order.dropoffAddresses.isNotEmpty
        ? order.dropoffAddresses.join(' -> ')
        : 'Chưa rõ điểm giao';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: OrderCode, Status Badge, Fee
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 17),
              const SizedBox(width: 5),
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        order.orderCode,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${_currencyFormat.format(order.totalFee)} đ',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Sender & Cargo summary
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 4),
              Expanded(
                flex: 3,
                child: Text(
                  'Khách: ${order.senderName} (${order.senderPhone})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${order.vehicleName} • ${order.weightCategory}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18),

          // Route Preview
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.circle, color: AppColors.primary, size: 9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.pickupAddress,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.location_on, color: AppColors.accent, size: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dropoffSummary,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date time & Distance
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Thời gian: ${_dateFormat.format(order.createdAt)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.distanceKm > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${order.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ],
            ],
          ),

          // e-POD Proof Photos Thumbnail Strip
          if (order.epodPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.camera_alt_rounded, size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        'Chứng từ e-POD (${order.epodPhotos.length} ảnh đã nộp)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: order.epodPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, pIdx) {
                        final photo = order.epodPhotos[pIdx];
                        return GestureDetector(
                          onTap: () => _showFullImageDialog(context, photo),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _buildEpodImage(photo, width: 52, height: 52),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Two-Way Rating: 1. Khách đánh giá tài xế
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                if (order.customerRating != null && order.customerRating! > 0) ...[
                  Row(
                    children: List.generate(
                      order.customerRating!,
                      (_) => const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.customerComment?.isNotEmpty == true
                          ? 'Khách đánh giá: "${order.customerComment}"'
                          : 'Khách hàng hài lòng 5⭐',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.star_outline_rounded, color: Color(0xFF94A3B8), size: 16),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Khách hàng chưa chấm điểm',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Two-Way Rating: 2. Tài xế đánh giá khách hàng
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: driverRated ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: driverRated ? AppColors.success.withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Icon(
                  driverRated ? Icons.verified_rounded : Icons.rate_review_outlined,
                  size: 18,
                  color: driverRated ? AppColors.success : const Color(0xFFD97706),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverRated ? 'Bạn đã đánh giá khách: $driverRating ⭐' : 'Bạn chưa đánh giá khách hàng',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: driverRated ? AppColors.success : const Color(0xFFB45309),
                        ),
                      ),
                      if (driverRated && (driverComment.isNotEmpty || driverTags.isNotEmpty)) ...[
                        const SizedBox(height: 2),
                        Text(
                          driverComment.isNotEmpty ? '"$driverComment"' : driverTags.join(', '),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: driverRated ? AppColors.success : const Color(0xFFF59E0B),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 30),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () => _showRateCustomerModal(order),
                  child: Text(
                    driverRated ? 'Sửa' : 'Chấm sao',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Button: View Full Order Details
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
              label: const Text('Xem chi tiết hành trình & bản đồ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
              onPressed: () {
                final LatLng? pLatLng = (order.pickupLat != null && order.pickupLng != null)
                    ? LatLng(order.pickupLat!, order.pickupLng!)
                    : null;
                final List<LatLng?> dLatLngs = [];
                if (order.dropoffLats != null && order.dropoffLngs != null) {
                  for (int i = 0; i < order.dropoffLats!.length && i < order.dropoffLngs!.length; i++) {
                    dLatLngs.add(LatLng(order.dropoffLats![i], order.dropoffLngs![i]));
                  }
                }
                final List<LatLng> routePoints = order.routeCoords != null
                    ? order.routeCoords!
                        .where((c) => c.length >= 2)
                        .map((c) => LatLng(c[0], c[1]))
                        .toList()
                    : [];

                PaymentMethod pm = PaymentMethod.cash;
                if (order.paymentMethod.toLowerCase().contains('momo')) {
                  pm = PaymentMethod.momo;
                } else if (order.paymentMethod.toLowerCase().contains('zalo')) {
                  pm = PaymentMethod.zalopay;
                }

                final draft = OrderDraftModel(
                  pickupAddress: order.pickupAddress,
                  dropoffAddresses: order.dropoffAddresses,
                  dropoffRecipients: order.dropoffRecipients.isNotEmpty ? order.dropoffRecipients : null,
                  pickupLatLng: pLatLng,
                  dropoffLatLngs: dLatLngs.isNotEmpty ? dLatLngs : null,
                  drivingRoutePoints: routePoints,
                  vehicleType: OrderVehicleType.fromName(order.vehicleName),
                  paymentMethod: pm,
                  promoCode: order.promoCode ?? '',
                  discountAmount: order.discountAmount.toDouble(),
                  senderName: order.senderName,
                  senderPhone: order.senderPhone,
                  recipientName: order.recipientName,
                  recipientPhone: order.recipientPhone,
                  packageCategory: order.packageCategory,
                  weightCategory: order.weightCategory,
                  driverNote: order.driverNote,
                  distanceKm: order.distanceKm,
                  durationMinutes: order.durationMinutes,
                  epodPhotos: order.epodPhotos,
                  packagePhotoBase64: order.packagePhotoBase64,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(
                      draft: draft,
                      orderCode: order.orderCode,
                      orderStatus: order.status,
                      epodPhotos: order.epodPhotos,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 3: VÍ THU NHẬP ĐỐI TÁC ====================

  Widget _buildWalletTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Ví thu nhập', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<OrderRecord>>(
        stream: FirestoreOrderService.streamDriverOrderHistory(_driverId),
        builder: (_, snapshot) {
          final orders = snapshot.data ?? [];
          final completedOrders = orders.where((o) => o.status == OrderStatus.completed).toList();

          // Tính toán thu nhập thực tế hôm nay
          final now = DateTime.now();
          final todayOrders = completedOrders.where((o) {
            final t = o.completedAt ?? o.createdAt;
            return t.year == now.year && t.month == now.month && t.day == now.day;
          }).toList();

          final int todayEarnings = todayOrders.fold<int>(0, (sum, o) => sum + o.totalFee);
          final int todayTripsCount = todayOrders.length;

          // Tính toán thu nhập tuần này (Thứ 2 đến Chủ nhật)
          final int weekday = now.weekday; // 1 = Thứ 2, ..., 7 = Chủ nhật
          final DateTime monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: weekday - 1));
          final DateTime sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

          final List<DateTime> weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
          final List<int> dailyRevenues = List.filled(7, 0);
          final List<int> dailyTrips = List.filled(7, 0);

          for (final order in completedOrders) {
            final t = order.completedAt ?? order.createdAt;
            if (t.isAfter(monday.subtract(const Duration(seconds: 1))) &&
                t.isBefore(sunday.add(const Duration(seconds: 1)))) {
              final dayIndex = t.weekday - 1;
              if (dayIndex >= 0 && dayIndex < 7) {
                dailyRevenues[dayIndex] += order.totalFee;
                dailyTrips[dayIndex] += 1;
              }
            }
          }

          final int weekTotalGross = dailyRevenues.reduce((a, b) => a + b);
          final int weekTotalNet = (weekTotalGross * 0.85).toInt();
          final int weekPlatformFee = weekTotalGross - weekTotalNet;
          final int weekTotalTrips = dailyTrips.reduce((a, b) => a + b);
          final int maxDailyRevenue = dailyRevenues.reduce((a, b) => a > b ? a : b);

          // Tổng số dư ví khả dụng đồng bộ Cloud Firestore (hoặc tính toán từ đơn hoàn thành)
          final int totalNetEarnings = completedOrders.fold<int>(0, (sum, o) => sum + (o.totalFee * 0.85).toInt());
          final int computedWallet = 1500000 + totalNetEarnings;
          final int walletBalance = _walletBalance != 1500000 ? _walletBalance : computedWallet;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Wallet Balance Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF1E3359)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Số dư ví khả dụng', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Ví ký quỹ: ${_currencyFormat.format(_depositBalance)} đ',
                            style: const TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_currencyFormat.format(walletBalance)} đ',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),

                    // Quick Stats: Today's Earnings and Completed Trips
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Thu nhập hôm nay', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '+${_currencyFormat.format(todayEarnings)} đ',
                                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 26, color: Colors.white24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Hoàn thành hôm nay', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(
                                '$todayTripsCount cuốc',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.account_balance_rounded, size: 18, color: Colors.white),
                            label: const Text('Rút tiền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                            onPressed: () {
                              _showWithdrawDialog(walletBalance);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Nạp ví', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            onPressed: () {
                              _showDepositDialog();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Payout Bank Account Card
              InkWell(
                onTap: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DriverBankAccountScreen(
                        driverId: _driverId,
                        initialBankName: _savedBankName,
                        initialAccountNo: _savedAccountNo,
                        initialHolderName: _savedHolderName,
                        initialBranch: _savedBranch,
                      ),
                    ),
                  );
                  if (res == true) {
                    await _loadSavedBankInfo();
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tài khoản nhận tiền (Payout)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_savedBankName • $_savedAccountNo',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              'Chủ TK: $_savedHolderName',
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverBankAccountScreen(
                                driverId: _driverId,
                                initialBankName: _savedBankName,
                                initialAccountNo: _savedAccountNo,
                                initialHolderName: _savedHolderName,
                                initialBranch: _savedBranch,
                              ),
                            ),
                          );
                          if (res == true) {
                            await _loadSavedBankInfo();
                          }
                        },
                        child: const Text('Cài đặt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Weekly Revenue & Bar Chart Card (Extracted Widget)
              DriverWeeklyRevenueChartCard(
                dailyRevenues: dailyRevenues,
                dailyTrips: dailyTrips,
                weekDays: weekDays,
                weekTotalGross: weekTotalGross,
                weekTotalNet: weekTotalNet,
                weekPlatformFee: weekPlatformFee,
                weekTotalTrips: weekTotalTrips,
                maxDailyRevenue: maxDailyRevenue,
                currentWeekday: weekday,
              ),

              const SizedBox(height: 24),

              const Text(
                'Lịch sử biến động số dư',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),

              if (_walletTransactions.isEmpty && completedOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text(
                      'Chưa có giao dịch biến động số dư phát sinh.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                )
              else ...[
                ..._walletTransactions.where((tx) => tx['type'] != 'earning').map((tx) {
                  final dt = DateTime.tryParse(tx['createdAt']?.toString() ?? '') ?? DateTime.now();
                  final timeStr = _dateFormat.format(dt);
                  final amount = (tx['amount'] as num?)?.toInt() ?? 0;
                  final isPos = tx['isPositive'] == true;
                  final subtitle = tx['subtitle']?.toString() ?? '';
                  return _buildTransactionRow(
                    tx['title']?.toString() ?? 'Giao dịch ví',
                    '${isPos ? "+" : "-"}${_currencyFormat.format(amount)} đ',
                    subtitle.isNotEmpty ? '$timeStr • $subtitle' : timeStr,
                    isPositive: isPos,
                  );
                }),
                ...completedOrders.expand((order) {
                  final timeStr = _dateFormat.format(order.completedAt ?? order.createdAt);
                  final grossFee = order.originalFee ?? order.totalFee;
                  final platformFee = (grossFee * 0.15).round();
                  final netEarning = grossFee - platformFee;
                  return [
                    _buildTransactionRow(
                      'Thu nhập ròng cuốc #${order.orderCode} (85%)',
                      '+${_currencyFormat.format(netEarning)} đ',
                      '$timeStr • ${order.paymentMethod}',
                      isPositive: true,
                    ),
                    _buildTransactionRow(
                      'Khấu trừ ký quỹ nền tảng GoShip (15%)',
                      '-${_currencyFormat.format(platformFee)} đ',
                      '$timeStr • Đơn #${order.orderCode}',
                      isPositive: false,
                    ),
                  ];
                }),
              ],

              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // ==================== TAB 4: TÀI KHOẢN ĐỐI TÁC & CÀI ĐẶT ====================
  Widget _buildProfileTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tài khoản Đối tác', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncDriverCloudProfile();
          await _loadSavedBankInfo();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 1. Profile Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      AppAvatarWidget(
                        avatarUrl: _currentUser.avatarUrl,
                        name: _currentUser.name,
                        size: 64,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _currentUser.name,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _currentUser.phone.isNotEmpty ? _currentUser.phone : 'Chưa cập nhật SĐT',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified_rounded, size: 13, color: Color(0xFF059669)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Đối tác Tài xế Đã xác thực',
                                    style: TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  // Quick stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildProfileStatItem(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        value: _currentUser.rating > 0 ? _currentUser.rating.toStringAsFixed(1) : '5.0',
                        label: 'Đánh giá',
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      _buildProfileStatItem(
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: AppColors.primary,
                        value: '99.2%',
                        label: 'Hoàn thành',
                      ),
                      Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
                      _buildProfileStatItem(
                        icon: Icons.military_tech_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        value: 'VIP Pro',
                        label: 'Hạng đối tác',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Vehicle & License Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_shipping_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Phương tiện & Giấy tờ',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD97706),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () async {
                          final updated = await Navigator.push<UserModel>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DriverEditProfileScreen(user: _currentUser),
                            ),
                          );
                          if (updated != null) {
                            setState(() => _currentUser = updated);
                          }
                        },
                        child: const Row(
                          children: [
                            Text('Chỉnh sửa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      children: [
                        _buildVehicleInfoRow('Loại xe', _currentUser.vehicleType ?? "Xe Bán tải Ranger"),
                        const SizedBox(height: 6),
                        _buildVehicleInfoRow('Biển kiểm soát', _currentUser.plateNumber ?? "51D 892.14"),
                        const SizedBox(height: 6),
                        _buildVehicleInfoRow('Số CCCD', _currentUser.cccd ?? "070204000284"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Settings & Shortcuts Menu
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  _buildProfileMenuItem(
                    icon: Icons.account_balance_rounded,
                    iconColor: AppColors.primary,
                    title: 'Tài khoản ngân hàng liên kết (Payout)',
                    subtitle: '$_savedBankName • $_savedAccountNo',
                    onTap: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverBankAccountScreen(
                            driverId: _driverId,
                            initialBankName: _savedBankName,
                            initialAccountNo: _savedAccountNo,
                            initialHolderName: _savedHolderName,
                            initialBranch: _savedBranch,
                          ),
                        ),
                      );
                      if (res == true) {
                        await _loadSavedBankInfo();
                      }
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildProfileMenuItem(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: const Color(0xFF0284C7),
                    title: 'Chuyển sang giao diện Khách hàng',
                    subtitle: 'Đặt giao hàng và gửi bưu kiện',
                    onTap: () {
                      final customerUser = widget.user.copyWith(
                        role: UserRole.customer,
                        avatarUrl: widget.user.avatarUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                      );
                      AuthService.saveSession(customerUser);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => CustomerMainScreen(user: customerUser)),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildProfileMenuItem(
                    icon: Icons.headset_mic_outlined,
                    iconColor: const Color(0xFF059669),
                    title: 'Tổng đài hỗ trợ Đối tác 24/7',
                    subtitle: '1900 6868 (Bấm phím 2 gặp tư vấn viên)',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildProfileMenuItem(
                    icon: Icons.verified_user_outlined,
                    iconColor: const Color(0xFF64748B),
                    title: 'Quy chế hoạt động & Tiêu chuẩn dịch vụ',
                    subtitle: 'Chính sách thưởng & Trách nhiệm pháp lý',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 4. Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  backgroundColor: const Color(0xFFFEF2F2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Đăng xuất tài khoản Đối tác', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                onPressed: () async {
                  await AuthService.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const UnifiedLoginScreen(initialRole: UserRole.driver)),
                    (route) => false,
                  );
                },
              ),
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                'GoShip Logistics Partner v2.4.0 • Build 2026',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildVehicleInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildProfileMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)) : null,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  void _showWithdrawDialog(int currentBalance) {
    int selectedAmount = currentBalance >= 500000 ? 500000 : (currentBalance >= 50000 ? currentBalance : 0);
    final amountCtrl = TextEditingController(text: selectedAmount > 0 ? selectedAmount.toString() : '');
    final presetAmounts = [200000, 500000, 1000000];
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Row(
            children: [
              Icon(Icons.account_balance_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rút tiền về Ngân hàng',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Số dư khả dụng: ${_currencyFormat.format(currentBalance)} đ', style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    setDialogState(() {
                      selectedAmount = parsed;
                      errorText = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Số tiền muốn rút (VNĐ)',
                    errorText: errorText,
                    suffixText: 'đ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...presetAmounts.where((a) => a <= currentBalance).map((amt) {
                      final isSel = selectedAmount == amt;
                      return ChoiceChip(
                        label: Text('${_currencyFormat.format(amt)} đ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSel ? Colors.white : AppColors.textPrimary)),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedAmount = amt;
                            amountCtrl.text = amt.toString();
                            errorText = null;
                          });
                        },
                      );
                    }),
                    if (currentBalance >= 50000)
                      ChoiceChip(
                        label: Text('Rút tất cả', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selectedAmount == currentBalance ? Colors.white : AppColors.accent)),
                        selected: selectedAmount == currentBalance,
                        selectedColor: AppColors.accent,
                        onSelected: (_) {
                          setDialogState(() {
                            selectedAmount = currentBalance;
                            amountCtrl.text = currentBalance.toString();
                            errorText = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tài khoản thụ hưởng nhận tiền:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          InkWell(
                            onTap: () async {
                              Navigator.pop(ctx);
                              final res = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DriverBankAccountScreen(
                                    driverId: _driverId,
                                    initialBankName: _savedBankName,
                                    initialAccountNo: _savedAccountNo,
                                    initialHolderName: _savedHolderName,
                                    initialBranch: _savedBranch,
                                  ),
                                ),
                              );
                              if (res == true) {
                                await _loadSavedBankInfo();
                              }
                            },
                            child: const Text('Thay đổi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('$_savedBankName • $_savedAccountNo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Chủ TK: $_savedHolderName', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (selectedAmount < 50000) {
                  setDialogState(() => errorText = 'Số tiền rút tối thiểu là 50,000 đ');
                  return;
                }
                if (selectedAmount > currentBalance) {
                  setDialogState(() => errorText = 'Vượt quá số dư khả dụng');
                  return;
                }
                Navigator.pop(ctx);
                final newBalance = currentBalance - selectedAmount;
                final txEntry = {
                  'id': 'tx_wd_${DateTime.now().millisecondsSinceEpoch}',
                  'type': 'withdraw',
                  'title': 'Rút tiền về $_savedBankName ($_savedAccountNo)',
                  'subtitle': 'Chủ TK: $_savedHolderName',
                  'amount': selectedAmount,
                  'isPositive': false,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                setState(() {
                  _walletBalance = newBalance;
                  _walletTransactions = [txEntry, ..._walletTransactions];
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('driver_wallet_balance', newBalance);
                await prefs.setString(
                  'driver_wallet_transactions_$_driverId',
                  jsonEncode(_walletTransactions.reversed.toList()),
                );
                await FirestoreOrderService.saveDriverWallet(
                  driverId: _driverId,
                  walletBalance: newBalance,
                  transactionEntry: txEntry,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Yêu cầu rút ${_currencyFormat.format(selectedAmount)} đ về $_savedBankName ($_savedAccountNo) đã được xử lý!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Xác nhận rút tiền', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDepositDialog() {
    int selectedAmount = 200000;
    final amountCtrl = TextEditingController(text: '200000');
    final amounts = [100000, 200000, 500000, 1000000];
    String? errorText;

    Widget buildChip(int amount, StateSetter setDialogState) {
      final isSelected = selectedAmount == amount;
      return InkWell(
        onTap: () => setDialogState(() {
          selectedAmount = amount;
          amountCtrl.text = amount.toString();
          errorText = null;
        }),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFCBD5E1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${_currencyFormat.format(amount)} đ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: const Row(
            children: [
              Icon(Icons.add_card_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nạp tiền vào Ví ký quỹ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Số dư ký quỹ hiện tại: ${_currencyFormat.format(_depositBalance)} đ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (val) {
                    final parsed = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    setDialogState(() {
                      selectedAmount = parsed;
                      errorText = null;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Số tiền nạp ký quỹ (VNĐ)',
                    errorText: errorText,
                    suffixText: 'đ',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Chọn nhanh số tiền nạp:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: buildChip(amounts[0], setDialogState)),
                    const SizedBox(width: 8),
                    Expanded(child: buildChip(amounts[1], setDialogState)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: buildChip(amounts[2], setDialogState)),
                    const SizedBox(width: 8),
                    Expanded(child: buildChip(amounts[3], setDialogState)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.primary),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hỗ trợ quét mã VietQR và đồng bộ số dư ký quỹ lên Cloud Firestore.',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (selectedAmount < 50000) {
                  setDialogState(() => errorText = 'Số tiền nạp tối thiểu là 50,000 đ');
                  return;
                }
                Navigator.pop(ctx);
                final updatedDeposit = _depositBalance + selectedAmount;
                final txEntry = {
                  'id': 'tx_dep_${DateTime.now().millisecondsSinceEpoch}',
                  'type': 'deposit',
                  'title': 'Nạp tiền vào Ví ký quỹ (VietQR)',
                  'subtitle': 'Số dư sau nạp: ${_currencyFormat.format(updatedDeposit)} đ',
                  'amount': selectedAmount,
                  'isPositive': true,
                  'createdAt': DateTime.now().toIso8601String(),
                };
                setState(() {
                  _depositBalance = updatedDeposit;
                  _walletTransactions = [txEntry, ..._walletTransactions];
                });
                final prefs = await SharedPreferences.getInstance();
                await prefs.setInt('driver_deposit_balance', updatedDeposit);
                await prefs.setString(
                  'driver_wallet_transactions_$_driverId',
                  jsonEncode(_walletTransactions.reversed.toList()),
                );
                await FirestoreOrderService.saveDriverWallet(
                  driverId: _driverId,
                  depositBalance: updatedDeposit,
                  transactionEntry: txEntry,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã nạp +${_currencyFormat.format(selectedAmount)} đ vào Ví ký quỹ (Tổng: ${_currencyFormat.format(updatedDeposit)} đ)!'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Tiếp tục nạp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionRow(String title, String amount, String time, {required bool isPositive}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isPositive ? AppColors.success : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
