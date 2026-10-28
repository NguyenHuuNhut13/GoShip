import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/cloud_media_service.dart';
import '../../../core/services/pricing_config_service.dart';
import '../../auth/data/auth_service.dart';
import '../../auth/presentation/unified_login_screen.dart';
import '../../customer/home/presentation/customer_main_screen.dart';
import '../../driver/home/presentation/driver_main_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final UserModel adminUser;
  const AdminDashboardScreen({super.key, required this.adminUser});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedTab = 0;

  // Filters & Search states
  String _mapFilter = 'all'; // all, delivering, idle
  String _orderStatusFilter = 'all'; // all, pending, in_transit, completed, cancelled
  String _orderSearch = '';
  String _driverStatusFilter = 'all'; // all, active, pending_approval, locked
  String _driverSearch = '';
  String _txFilter = 'all'; // all, deposit, withdraw, commission
  String _selectedPricingVehicle = 'motorbike';
  String _mapTileSource = 'hot';

  final MapController _fleetMapController = MapController();

  // Controllers for pricing form
  final TextEditingController _baseFeeCtrl = TextEditingController();
  final TextEditingController _perKmCtrl = TextEditingController();
  final TextEditingController _peakCtrl = TextEditingController();
  final TextEditingController _waitCtrl = TextEditingController();
  final TextEditingController _minFeeCtrl = TextEditingController();
  bool _isPeakActive = false;
  bool _isSavingPricing = false;

  @override
  void initState() {
    super.initState();
    PricingConfigService.instance.startListening();
    _loadPricingIntoControllers(_selectedPricingVehicle);
    PricingConfigService.instance.addListener(_onPricingCloudChanged);
  }

  void _onPricingCloudChanged() {
    if (!mounted) return;
    _loadPricingIntoControllers(_selectedPricingVehicle);
  }

  void _loadPricingIntoControllers(String vehicleKey) {
    final rule = PricingConfigService.instance.getRule(vehicleKey);
    _baseFeeCtrl.text = rule.baseFee.toString();
    _perKmCtrl.text = rule.perKmFee.toString();
    _peakCtrl.text = rule.peakMultiplier.toString();
    _waitCtrl.text = rule.waitFee.toString();
    _minFeeCtrl.text = rule.minFee.toString();
    setState(() {
      _isPeakActive = rule.isPeakActive;
    });
  }

  @override
  void dispose() {
    PricingConfigService.instance.removeListener(_onPricingCloudChanged);
    _baseFeeCtrl.dispose();
    _perKmCtrl.dispose();
    _peakCtrl.dispose();
    _waitCtrl.dispose();
    _minFeeCtrl.dispose();
    super.dispose();
  }

  String _formatVnd(num amount) {
    final intVal = amount.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return '${amount < 0 ? '-' : ''}${buffer.toString()}đ';
  }

  String _normalizeOrderStatus(String? rawStatus) {
    final s = (rawStatus ?? '').toLowerCase().trim();
    if (s == 'completed' || s == 'delivered' || s.contains('hoàn thành') || s.contains('đã giao')) {
      return 'completed';
    }
    if (s == 'cancelled' || s == 'canceled' || s.contains('hủy')) {
      return 'cancelled';
    }
    if (s == 'accepted' || s == 'picked_up' || s == 'in_transit' || s == 'delivering' || s.contains('đang giao') || s.contains('đã nhận')) {
      return 'in_transit';
    }
    return 'pending';
  }

  Future<void> _handleLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
      (route) => false,
    );
  }

  void _showRoleSwitchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chuyển nhanh góc nhìn kiểm thử',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Giúp Quản trị viên kiểm tra trực tiếp giao diện Khách hàng hoặc Đối tác Tài xế ngay trên thiết bị này.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFEFF6FF),
              leading: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person_rounded, color: Colors.white),
              ),
              title: const Text('Mở giao diện Khách hàng', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Đặt đơn, kiểm tra bảng giá động & theo dõi xe'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerMainScreen(
                      user: widget.adminUser.copyWith(role: UserRole.customer),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFFFFF3EB),
              leading: const CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Icon(Icons.local_shipping_rounded, color: Colors.white),
              ),
              title: const Text('Mở giao diện Đối tác Tài xế', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Bật Online, nhận cuốc xe & kiểm tra ví ký quỹ'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DriverMainScreen(
                      user: widget.adminUser.copyWith(
                        role: UserRole.driver,
                        plateNumber: widget.adminUser.plateNumber ?? '51D-892.14',
                        vehicleType: widget.adminUser.vehicleType ?? 'Xe Bán tải',
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'Tổng quan Hệ thống',
      'Bản đồ Điều hành LIVE',
      'Quản lý Đơn hàng & e-POD',
      'Đối tác Tài xế & Duyệt KYC',
      'Cấu hình Bảng giá Động',
      'Sổ cái Giao dịch & Ví',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'GoShip Admin',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                        ),
                        child: const Text(
                          'CLOUD LIVE',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF34D399)),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    titles[_selectedTab],
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Chuyển góc nhìn Khách/Tài xế',
            onPressed: _showRoleSwitchSheet,
            icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF60A5FA)),
          ),
          IconButton(
            tooltip: 'Đăng xuất Admin',
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFF87171), size: 20),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildDashboardTab(),
          _buildFleetMapTab(),
          _buildOrdersTab(),
          _buildDriversTab(),
          _buildPricingTab(),
          _buildTransactionsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: (i) => setState(() => _selectedTab = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF2563EB),
          unselectedItemColor: const Color(0xFF64748B),
          selectedFontSize: 11,
          unselectedFontSize: 10,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Tổng quan'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Bản đồ'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Đơn hàng'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Tài xế'),
            BottomNavigationBarItem(icon: Icon(Icons.sell_rounded), label: 'Bảng giá'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_rounded), label: 'Giao dịch'),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: TỔNG QUAN (DASHBOARD VIEW)
  // ===========================================================================
  Widget _buildDashboardTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, orderSnap) {
        final orderDocs = orderSnap.data?.docs ?? [];
        int totalOrders = orderDocs.length;
        int completedCount = 0;
        int inTransitCount = 0;
        int pendingCount = 0;
        int cancelledCount = 0;
        int totalGrossRevenue = 0;

        for (final doc in orderDocs) {
          final data = doc.data();
          final st = _normalizeOrderStatus(data['status']?.toString());
          final fee = (data['total_price'] as num?)?.toInt() ??
              (data['fee'] as num?)?.toInt() ??
              (data['raw_fee'] as num?)?.toInt() ??
              0;
          if (st == 'completed') {
            completedCount++;
            totalGrossRevenue += fee;
          } else if (st == 'in_transit') {
            inTransitCount++;
          } else if (st == 'cancelled') {
            cancelledCount++;
          } else {
            pendingCount++;
          }
        }

        final int platformCommission = (totalGrossRevenue * 0.15).round();
        final double completionRate = totalOrders > 0 ? (completedCount * 100.0 / totalOrders) : 100.0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('driver_tracking').snapshots(),
          builder: (context, driverSnap) {
            final trackingDocs = driverSnap.data?.docs ?? [];
            final onlineDrivers = trackingDocs.where((d) => d.data()['is_online'] != false).length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Quick Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trung tâm Điều hành GoShip',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Đồng bộ trực tiếp với Cloud Firestore • Hoa hồng sàn (15%): ${_formatVnd(platformCommission)}',
                              style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => setState(() => _selectedTab = 1),
                        icon: const Icon(Icons.radar_rounded, size: 16),
                        label: const Text('Bản đồ Live', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4 KPI Cards (2x2 Grid)
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Tổng đơn hàng',
                        value: '$totalOrders đơn',
                        subtitle: '$inTransitCount đang giao • $pendingCount chờ nhận',
                        icon: Icons.inventory_2_rounded,
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Tổng doanh thu',
                        value: _formatVnd(totalGrossRevenue),
                        subtitle: 'Phí sàn 15%: ${_formatVnd(platformCommission)}',
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Xe đang Online',
                        value: '$onlineDrivers xe',
                        subtitle: 'Đang phát tín hiệu GPS',
                        icon: Icons.local_shipping_rounded,
                        color: const Color(0xFFFF6B00),
                        bgColor: const Color(0xFFFFF3EB),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Tỷ lệ hoàn thành',
                        value: '${completionRate.toStringAsFixed(1)}%',
                        subtitle: '$completedCount hoàn tất • $cancelledCount đã hủy',
                        icon: Icons.verified_rounded,
                        color: const Color(0xFF2563EB),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Order Status Distribution Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân bổ trạng thái đơn hàng (Real-time)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 14),
                      _buildStatusDistRow('Hoàn thành', completedCount, totalOrders, const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      _buildStatusDistRow('Đang giao hàng', inTransitCount, totalOrders, const Color(0xFF2563EB)),
                      const SizedBox(height: 10),
                      _buildStatusDistRow('Chờ tài xế nhận', pendingCount, totalOrders, const Color(0xFFF59E0B)),
                      const SizedBox(height: 10),
                      _buildStatusDistRow('Đã hủy', cancelledCount, totalOrders, const Color(0xFFEF4444)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Recent Orders Quick List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              'Đơn hàng mới nhất trên hệ thống',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () => setState(() => _selectedTab = 2),
                            child: const Text('Xem tất cả →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      if (orderDocs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('Chưa có đơn hàng nào trên Cloud Firestore.', style: TextStyle(color: Color(0xFF64748B))),
                          ),
                        )
                      else
                        ...orderDocs.take(5).map((doc) {
                          final d = doc.data();
                          final code = d['order_code']?.toString() ?? doc.id;
                          final st = _normalizeOrderStatus(d['status']?.toString());
                          final fee = (d['total_price'] as num?)?.toInt() ?? (d['fee'] as num?)?.toInt() ?? 0;
                          final pickup = d['pickup_address']?.toString() ?? d['pickup']?.toString() ?? 'Điểm lấy hàng';
                          final dropoff = d['dropoff_address']?.toString() ?? d['dropoff']?.toString() ?? 'Điểm giao hàng';

                          return InkWell(
                            onTap: () => _showOrderDetailModal(code, d),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.local_shipping_outlined, size: 18, color: Color(0xFF2563EB)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 2,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              code,
                                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF2563EB)),
                                            ),
                                            _buildStatusBadge(st),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$pickup → $dropoff',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatVnd(fee),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDistRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total) : 0.0;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              ],
            ),
            Text(
              '$count đơn (${(pct * 100).toStringAsFixed(0)}%)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: const Color(0xFFF1F5F9),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: BẢN ĐỒ ĐIỀU HÀNH LIVE (FLEET MAP VIEW)
  // ===========================================================================
  Widget _buildFleetMapTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('driver_tracking').snapshots(),
      builder: (context, snapshot) {
        final rawDocs = snapshot.data?.docs ?? [];
        final drivers = rawDocs.map((doc) {
          final d = doc.data();
          final lat = (d['lat'] as num?)?.toDouble() ?? (d['latitude'] as num?)?.toDouble() ?? 10.7769;
          final lng = (d['lng'] as num?)?.toDouble() ?? (d['longitude'] as num?)?.toDouble() ?? 106.7009;
          final activeOrder = d['active_order_id']?.toString() ?? '';
          final isDelivering = activeOrder.isNotEmpty && activeOrder != 'null';
          return {
            'id': doc.id,
            'name': d['driver_name']?.toString() ?? 'Tài xế GoShip',
            'phone': d['phone']?.toString() ?? '',
            'plate': d['plate']?.toString() ?? '51D-892.14',
            'vehicle': d['vehicle_type']?.toString() ?? 'Xe Bán tải',
            'lat': lat,
            'lng': lng,
            'status': isDelivering ? 'delivering' : 'idle',
            'activeOrder': activeOrder,
            'isOnline': d['is_online'] != false,
          };
        }).where((d) => d['isOnline'] == true).toList();

        final deliveringCount = drivers.where((d) => d['status'] == 'delivering').length;
        final idleCount = drivers.where((d) => d['status'] == 'idle').length;

        final filteredDrivers = _mapFilter == 'all'
            ? drivers
            : drivers.where((d) => d['status'] == _mapFilter).toList();

        return Column(
          children: [
            // Dark Mode Command Header (matching Figma FleetMapView)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Đội xe trực tuyến: ${drivers.length} xe',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapCounterChip('Đang giao', deliveringCount, const Color(0xFFFF6B00)),
                          const SizedBox(width: 6),
                          _buildMapCounterChip('Đang rảnh', idleCount, const Color(0xFF10B981)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildMapFilterPill('all', 'Tất cả (${drivers.length})'),
                      const SizedBox(width: 6),
                      _buildMapFilterPill('delivering', 'Đang giao ($deliveringCount)'),
                      const SizedBox(width: 6),
                      _buildMapFilterPill('idle', 'Đang rảnh ($idleCount)'),
                    ],
                  ),
                ],
              ),
            ),

            // Interactive OpenStreetMap Canvas
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _fleetMapController,
                    options: MapOptions(
                      initialCenter: filteredDrivers.isNotEmpty
                          ? LatLng(filteredDrivers.first['lat'] as double, filteredDrivers.first['lng'] as double)
                          : const LatLng(10.7769, 106.7009),
                      initialZoom: 13.0,
                      minZoom: 4.0,
                      maxZoom: 18.5,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _mapTileSource == 'hot'
                            ? 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        fallbackUrl: _mapTileSource == 'hot'
                            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                            : 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                        subdomains: _mapTileSource == 'hot' ? const ['a', 'b', 'c'] : const ['a', 'b'],
                        userAgentPackageName: 'vn.nks.goship.goship_app',
                        maxZoom: 19,
                        minZoom: 4,
                      ),
                      MarkerLayer(
                        markers: filteredDrivers.map((d) {
                          final isDelivering = d['status'] == 'delivering';
                          final color = isDelivering ? const Color(0xFFFF6B00) : const Color(0xFF10B981);
                          return Marker(
                            point: LatLng(d['lat'] as double, d['lng'] as double),
                            width: 110,
                            height: 64,
                            child: GestureDetector(
                              onTap: () => _showDriverMapPopup(d),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: color, width: 1.2),
                                    ),
                                    child: Text(
                                      d['plate'].toString(),
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, spreadRadius: 2),
                                      ],
                                    ),
                                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 15),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'admin_switch_tiles',
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          tooltip: 'Đổi kiểu bản đồ',
                          onPressed: () {
                            setState(() {
                              _mapTileSource = _mapTileSource == 'hot' ? 'osm' : 'hot';
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(_mapTileSource == 'hot'
                                    ? 'Đang dùng bản đồ OpenStreetMap Đô thị nét cao'
                                    : 'Đang dùng bản đồ OpenStreetMap Tiêu chuẩn'),
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Icon(Icons.layers_rounded, size: 18),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'admin_recenter_map',
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          tooltip: 'Định vị đội xe',
                          onPressed: () {
                            if (filteredDrivers.isNotEmpty) {
                              _fleetMapController.move(
                                LatLng(filteredDrivers.first['lat'] as double, filteredDrivers.first['lng'] as double),
                                14.0,
                              );
                            } else {
                              _fleetMapController.move(const LatLng(10.7769, 106.7009), 12.8);
                            }
                          },
                          child: const Icon(Icons.my_location_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapCounterChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $count',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMapFilterPill(String key, String label) {
    final active = _mapFilter == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mapFilter = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF2563EB) : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  void _showDriverMapPopup(Map<String, dynamic> d) {
    final isDelivering = d['status'] == 'delivering';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDelivering ? const Color(0xFFFF6B00) : const Color(0xFF10B981),
                  child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['name'].toString(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${d['vehicle']} • Biển số: ${d['plate']}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDelivering ? const Color(0xFFFFF3EB) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isDelivering ? 'Đang giao đơn' : 'Đang rảnh',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDelivering ? const Color(0xFFFF6B00) : const Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Số điện thoại: ${d['phone']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            if (isDelivering)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Đơn đang thực hiện: ${d['activeOrder']}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 3: QUẢN LÝ ĐƠN HÀNG & e-POD (ORDERS VIEW)
  // ===========================================================================
  Widget _buildOrdersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final filtered = docs.where((doc) {
          final d = doc.data();
          final st = _normalizeOrderStatus(d['status']?.toString());
          if (_orderStatusFilter != 'all' && st != _orderStatusFilter) return false;
          if (_orderSearch.trim().isNotEmpty) {
            final q = _orderSearch.toLowerCase().trim();
            final code = (d['order_code']?.toString() ?? doc.id).toLowerCase();
            final customer = (d['customer_name']?.toString() ?? d['sender_name']?.toString() ?? '').toLowerCase();
            final driver = (d['driver_name']?.toString() ?? '').toLowerCase();
            return code.contains(q) || customer.contains(q) || driver.contains(q);
          }
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _orderSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm mã đơn (#GS...), tên khách, tài xế...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tất cả (${docs.length})', _orderStatusFilter == 'all', () {
                          setState(() => _orderStatusFilter = 'all');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Đang giao', _orderStatusFilter == 'in_transit', () {
                          setState(() => _orderStatusFilter = 'in_transit');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Hoàn thành', _orderStatusFilter == 'completed', () {
                          setState(() => _orderStatusFilter = 'completed');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Chờ nhận', _orderStatusFilter == 'pending', () {
                          setState(() => _orderStatusFilter = 'pending');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Đã hủy', _orderStatusFilter == 'cancelled', () {
                          setState(() => _orderStatusFilter = 'cancelled');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy đơn hàng phù hợp.', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final doc = filtered[idx];
                        final d = doc.data();
                        final code = d['order_code']?.toString() ?? doc.id;
                        final st = _normalizeOrderStatus(d['status']?.toString());
                        final customer = d['customer_name']?.toString() ?? d['sender_name']?.toString() ?? 'Khách hàng GoShip';
                        final driver = d['driver_name']?.toString() ?? 'Chưa có tài xế';
                        final vehicle = d['vehicle_type']?.toString() ?? 'Xe Bán tải';
                        final fee = (d['total_price'] as num?)?.toInt() ?? (d['fee'] as num?)?.toInt() ?? 0;
                        final pickup = d['pickup_address']?.toString() ?? d['pickup']?.toString() ?? '';
                        final dropoff = d['dropoff_address']?.toString() ?? d['dropoff']?.toString() ?? '';
                        final hasEpod = (d['epod_photo_url']?.toString().isNotEmpty == true) ||
                            (d['epod_photos'] is List && (d['epod_photos'] as List).isNotEmpty);

                        return InkWell(
                          onTap: () => _showOrderDetailModal(code, d),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          code,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(st),
                                        if (hasEpod) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.camera_alt_rounded, size: 11, color: Color(0xFF10B981)),
                                                SizedBox(width: 3),
                                                Text('e-POD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      _formatVnd(fee),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '📍 Lấy: $pickup',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '🏁 Giao: $dropoff',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                ),
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Khách: $customer • TX: $driver ($vehicle)',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const Text(
                                      'Chi tiết →',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _showOrderDetailModal(String orderCode, Map<String, dynamic> data) {
    final st = _normalizeOrderStatus(data['status']?.toString());
    final fee = (data['total_price'] as num?)?.toInt() ?? (data['fee'] as num?)?.toInt() ?? 0;
    final discount = (data['discount_amount'] as num?)?.toInt() ?? 0;
    final paymentMethod = data['payment_method']?.toString() ?? 'Tiền mặt (COD)';
    final pickup = data['pickup_address']?.toString() ?? data['pickup']?.toString() ?? '';
    final dropoff = data['dropoff_address']?.toString() ?? data['dropoff']?.toString() ?? '';
    final epodUrl = data['epod_photo_url']?.toString() ??
        ((data['epod_photos'] is List && (data['epod_photos'] as List).isNotEmpty)
            ? (data['epod_photos'] as List).first.toString()
            : null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Đơn hàng $orderCode',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(st),
                    ],
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Khách hàng: ${data['customer_name'] ?? data['sender_name'] ?? 'Khách hàng GoShip'} (${data['customer_phone'] ?? data['sender_phone'] ?? '---'})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('Tài xế nhận: ${data['driver_name'] ?? 'Chưa có'} (${data['driver_phone'] ?? '---'})',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                    const Divider(height: 18),
                    Text('📍 Điểm lấy: $pickup', style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text('🏁 Điểm giao: $dropoff', style: const TextStyle(fontSize: 13)),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Thanh toán: $paymentMethod', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        if (discount > 0)
                          Text('Giảm giá: -${_formatVnd(discount)}', style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tổng cước thu:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(_formatVnd(fee), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Ảnh xác nhận giao hàng (e-POD)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              if (epodUrl != null && epodUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: CloudMediaService.buildSmartImage(
                      epodUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 90,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Chưa có ảnh chụp e-POD cho đơn hàng này',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ),
              const SizedBox(height: 18),
              // Admin Override Actions
              Row(
                children: [
                  if (st != 'cancelled' && st != 'completed')
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('orders').doc(orderCode).set({
                            'status': 'cancelled',
                            'cancel_reason': 'Quản trị viên hủy điều phối',
                            'updated_at': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Hủy đơn (Admin)', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (st != 'completed') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance.collection('orders').doc(orderCode).set({
                            'status': 'completed',
                            'updated_at': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                        label: const Text('Xác nhận Hoàn tất', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: ĐỐI TÁC TÀI XẾ & DUYỆT HỒ SƠ (DRIVERS VIEW)
  // ===========================================================================
  Widget _buildDriversTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        final allUsers = snapshot.data?.docs ?? [];
        final driverDocs = allUsers.where((doc) {
          final r = (doc.data()['role']?.toString() ?? '').toLowerCase();
          return r.contains('driver') || doc.id.startsWith('drv_') || doc.data()['plateNumber'] != null;
        }).toList();

        final pendingCount = driverDocs.where((doc) {
          final st = doc.data()['account_status']?.toString() ?? doc.data()['accountStatus']?.toString() ?? 'active';
          return st == 'pending_approval';
        }).length;

        final filtered = driverDocs.where((doc) {
          final d = doc.data();
          final st = d['account_status']?.toString() ?? d['accountStatus']?.toString() ?? 'active';
          if (_driverStatusFilter != 'all' && st != _driverStatusFilter) return false;
          if (_driverSearch.trim().isNotEmpty) {
            final q = _driverSearch.toLowerCase().trim();
            final name = (d['name']?.toString() ?? '').toLowerCase();
            final phone = (d['phone']?.toString() ?? '').toLowerCase();
            final plate = (d['plateNumber']?.toString() ?? '').toLowerCase();
            return name.contains(q) || phone.contains(q) || plate.contains(q);
          }
          return true;
        }).toList();

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  if (pendingCount > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Có $pendingCount hồ sơ đối tác tài xế mới đang chờ duyệt!',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _driverStatusFilter = 'pending_approval'),
                            child: const Text(
                              'Xem ngay',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    onChanged: (v) => setState(() => _driverSearch = v),
                    decoration: InputDecoration(
                      hintText: 'Tìm tên tài xế, SĐT, biển số xe...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tất cả (${driverDocs.length})', _driverStatusFilter == 'all', () {
                          setState(() => _driverStatusFilter = 'all');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Hoạt động', _driverStatusFilter == 'active', () {
                          setState(() => _driverStatusFilter = 'active');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Chờ duyệt ($pendingCount)', _driverStatusFilter == 'pending_approval', () {
                          setState(() => _driverStatusFilter = 'pending_approval');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Bị khóa', _driverStatusFilter == 'locked', () {
                          setState(() => _driverStatusFilter = 'locked');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('Chưa có hồ sơ tài xế nào trong danh mục này.', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final doc = filtered[idx];
                        final d = doc.data();
                        final name = d['name']?.toString() ?? 'Đối tác Tài xế';
                        final phone = d['phone']?.toString() ?? '---';
                        final plate = d['plateNumber']?.toString() ?? '51D-892.14';
                        final vehicle = d['vehicleType']?.toString() ?? 'Xe Bán tải';
                        final rating = (d['rating'] as num?)?.toDouble() ?? 5.0;
                        final status = d['account_status']?.toString() ?? d['accountStatus']?.toString() ?? 'active';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 44,
                                      height: 44,
                                      child: CloudMediaService.buildSmartImage(
                                        d['avatarUrl']?.toString(),
                                        fallback: Container(
                                          color: const Color(0xFFEFF6FF),
                                          child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB)),
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
                                          name,
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$phone • $vehicle ($plate)',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildDriverStatusBadge(status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'CCCD: ${d['cccd'] ?? 'Đã xác thực'}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      if (status == 'pending_approval') ...[
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _changeDriverStatus(doc.id, 'active', phone, d['id']?.toString(), name),
                                          icon: const Icon(Icons.check_rounded, size: 14),
                                          label: const Text('Duyệt', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                        const SizedBox(width: 6),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFEF4444),
                                            side: const BorderSide(color: Color(0xFFEF4444)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _changeDriverStatus(doc.id, 'locked', phone, d['id']?.toString(), name),
                                          child: const Text('Từ chối', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                      ] else if (status == 'active') ...[
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFEF4444),
                                            side: const BorderSide(color: Color(0xFFFECACA)),
                                            backgroundColor: const Color(0xFFFEF2F2),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _changeDriverStatus(doc.id, 'locked', phone, d['id']?.toString(), name),
                                          icon: const Icon(Icons.lock_outline_rounded, size: 14),
                                          label: const Text('Khóa TK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                      ] else ...[
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => _changeDriverStatus(doc.id, 'active', phone, d['id']?.toString(), name),
                                          icon: const Icon(Icons.lock_open_rounded, size: 14),
                                          label: const Text('Mở khóa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeDriverStatus(String docId, String newStatus, String phone, String? userId, String name) async {
    final ok = await AuthService.updateUserAccountStatus(
      docId: docId,
      status: newStatus,
      phone: phone,
      userId: userId,
    );
    if (!mounted) return;
    final label = newStatus == 'active' ? 'Đã kích hoạt/mở khóa' : 'Đã tạm khóa';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '$label tài khoản đối tác $name trên Cloud Firestore!' : 'Không thể cập nhật trạng thái.'),
        backgroundColor: newStatus == 'active' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // TAB 5: CẤU HÌNH BẢNG GIÁ ĐỘNG (PRICING VIEW)
  // ===========================================================================
  Widget _buildPricingTab() {
    final rules = PricingConfigService.instance.rules;
    final currentRule = PricingConfigService.instance.getRule(_selectedPricingVehicle);

    final baseVal = int.tryParse(_baseFeeCtrl.text.trim()) ?? currentRule.baseFee;
    final perKmVal = int.tryParse(_perKmCtrl.text.trim()) ?? currentRule.perKmFee;
    final peakVal = double.tryParse(_peakCtrl.text.trim()) ?? currentRule.peakMultiplier;
    final minVal = int.tryParse(_minFeeCtrl.text.trim()) ?? currentRule.minFee;

    final raw5km = (baseVal + 5 * perKmVal) * (_isPeakActive ? peakVal : 1.0);
    final preview5km = raw5km.round() < minVal ? minVal : raw5km.round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Vehicle Type Selector Tabs (4 GoShip Vehicle Types)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: rules.entries.map((entry) {
              final active = _selectedPricingVehicle == entry.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: active,
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: Colors.white,
                  label: Text(
                    '${entry.value.icon} ${entry.value.name}',
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF334155),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedPricingVehicle = entry.key);
                    _loadPricingIntoControllers(entry.key);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(currentRule.icon, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bảng giá — ${currentRule.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const Text(
                          'Thay đổi tại đây sẽ áp dụng tức thì cho App Khách hàng khi đặt đơn.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              _buildPricingField('Cước mở cửa (2km đầu)', 'VNĐ', _baseFeeCtrl),
              const SizedBox(height: 12),
              _buildPricingField('Đơn giá mỗi km tiếp theo', 'VNĐ/km', _perKmCtrl),
              const SizedBox(height: 12),
              _buildPricingField('Cước tối thiểu mỗi chuyến', 'VNĐ', _minFeeCtrl),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPricingField('Hệ số giờ cao điểm', 'x lần', _peakCtrl, isDecimal: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPricingField('Phí chờ bốc xếp', 'VNĐ/phút', _waitCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Kích hoạt phụ phí Giờ cao điểm ngay bây giờ',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                subtitle: Text(
                  _isPeakActive ? 'Đang nhân hệ số x$peakVal vào giá cước' : 'Đang tính giá giờ bình thường (x1.0)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                value: _isPeakActive,
                activeThumbColor: const Color(0xFFFF6B00),
                onChanged: (val) => setState(() => _isPeakActive = val),
              ),

              const SizedBox(height: 8),
              // 5km Preview Box (matching Figma PricingView)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cước tạm tính mẫu cho lộ trình 5km:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(${_formatVnd(baseVal)} + 5km × ${_formatVnd(perKmVal)})${_isPeakActive ? ' × $peakVal (Cao điểm)' : ''} = ${_formatVnd(preview5km)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSavingPricing ? null : _saveCurrentVehiclePricing,
                      icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                      label: Text(
                        _isSavingPricing ? 'Đang lưu...' : 'Lưu bảng giá Cloud',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        await PricingConfigService.instance.resetToDefault();
                        _loadPricingIntoControllers(_selectedPricingVehicle);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã khôi phục bảng giá mặc định cho cả 4 dòng xe!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Mặc định', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingField(String label, String suffix, TextEditingController ctrl, {bool isDecimal = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            suffixText: suffix,
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Future<void> _saveCurrentVehiclePricing() async {
    setState(() => _isSavingPricing = true);
    final current = PricingConfigService.instance.getRule(_selectedPricingVehicle);
    final updatedRule = current.copyWith(
      baseFee: int.tryParse(_baseFeeCtrl.text.trim()) ?? current.baseFee,
      perKmFee: int.tryParse(_perKmCtrl.text.trim()) ?? current.perKmFee,
      peakMultiplier: double.tryParse(_peakCtrl.text.trim()) ?? current.peakMultiplier,
      waitFee: int.tryParse(_waitCtrl.text.trim()) ?? current.waitFee,
      minFee: int.tryParse(_minFeeCtrl.text.trim()) ?? current.minFee,
      isPeakActive: _isPeakActive,
    );

    final newMap = Map<String, VehiclePricingRule>.from(PricingConfigService.instance.rules);
    newMap[_selectedPricingVehicle] = updatedRule;
    final ok = await PricingConfigService.instance.saveRulesToCloud(newMap);
    if (!mounted) return;
    setState(() => _isSavingPricing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Đã lưu bảng giá ${current.name} lên Cloud Firestore! App Khách hàng đã được cập nhật.'
            : 'Lỗi khi lưu bảng giá.'),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===========================================================================
  // TAB 6: SỔ CÁI GIAO DỊCH & VÍ TÀI XẾ (TRANSACTIONS VIEW)
  // ===========================================================================
  Widget _buildTransactionsTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('driver_wallets').snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        int totalWalletBalance = 0;
        int totalEscrowBalance = 0;
        final allTx = <Map<String, dynamic>>[];

        for (final doc in docs) {
          final d = doc.data();
          final driverName = d['driver_name']?.toString() ?? doc.id;
          final walletBal = (d['wallet_balance'] as num?)?.toInt() ?? 0;
          final depositBal = (d['deposit_balance'] as num?)?.toInt() ?? 0;
          totalWalletBalance += walletBal;
          totalEscrowBalance += depositBal;

          if (d['transactions'] is List) {
            final list = d['transactions'] as List;
            for (int i = 0; i < list.length; i++) {
              if (list[i] is Map) {
                final item = Map<String, dynamic>.from(list[i] as Map);
                final title = item['title']?.toString() ?? 'Giao dịch ví';
                final amountStr = item['amount']?.toString() ?? '0đ';
                final isPos = item['isPositive'] == true || amountStr.startsWith('+');
                String txType = item['type']?.toString() ?? '';
                if (txType.isEmpty) {
                  final lower = title.toLowerCase();
                  if (lower.contains('rút')) {
                    txType = 'withdraw';
                  } else if (lower.contains('ký quỹ') || lower.contains('nạp')) {
                    txType = 'deposit';
                  } else if (lower.contains('hoa hồng') || lower.contains('khấu trừ')) {
                    txType = 'commission';
                  } else {
                    txType = 'earning';
                  }
                }
                allTx.add({
                  'id': 'TX-${doc.id.substring(0, doc.id.length > 4 ? 4 : doc.id.length).toUpperCase()}-${i + 1}',
                  'driver': driverName,
                  'title': title,
                  'amount': amountStr,
                  'time': item['time']?.toString() ?? 'Gần đây',
                  'isPositive': isPos,
                  'type': txType,
                  'balanceAfter': walletBal,
                });
              }
            }
          }
        }

        final reversedTx = allTx.reversed.toList();
        final filteredTx = _txFilter == 'all'
            ? reversedTx
            : reversedTx.where((t) => t['type'] == _txFilter).toList();

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tổng Ví Thu nhập TX', style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(_formatVnd(totalWalletBalance), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF065F46))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Tổng Quỹ Ký quỹ giữ', style: TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(_formatVnd(totalEscrowBalance), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Tất cả (${reversedTx.length})', _txFilter == 'all', () {
                          setState(() => _txFilter = 'all');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Nạp / Ký quỹ', _txFilter == 'deposit', () {
                          setState(() => _txFilter = 'deposit');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Rút tiền', _txFilter == 'withdraw', () {
                          setState(() => _txFilter = 'withdraw');
                        }),
                        const SizedBox(width: 8),
                        _buildFilterChip('Hoa hồng 15%', _txFilter == 'commission', () {
                          setState(() => _txFilter = 'commission');
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filteredTx.isEmpty
                  ? const Center(
                      child: Text('Chưa có bút toán giao dịch nào trong mục này.', style: TextStyle(color: Color(0xFF64748B))),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(14),
                      itemCount: filteredTx.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final tx = filteredTx[idx];
                        final isPos = tx['isPositive'] == true;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: isPos ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isPos ? Icons.south_west_rounded : Icons.north_east_rounded,
                                  size: 18,
                                  color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx['title'].toString(),
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Tài xế: ${tx['driver']} • ${tx['time']}',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                tx['amount'].toString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isPos ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // SHARED BADGES & CHIPS
  // ===========================================================================
  Widget _buildFilterChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String st) {
    String label = 'Chờ nhận';
    Color color = const Color(0xFFF59E0B);
    Color bg = const Color(0xFFFFFBEB);
    if (st == 'completed') {
      label = 'Hoàn thành';
      color = const Color(0xFF10B981);
      bg = const Color(0xFFECFDF5);
    } else if (st == 'in_transit') {
      label = 'Đang giao';
      color = const Color(0xFF2563EB);
      bg = const Color(0xFFEFF6FF);
    } else if (st == 'cancelled') {
      label = 'Đã hủy';
      color = const Color(0xFFEF4444);
      bg = const Color(0xFFFEF2F2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _buildDriverStatusBadge(String status) {
    String label = 'Hoạt động';
    Color color = const Color(0xFF10B981);
    Color bg = const Color(0xFFECFDF5);
    if (status == 'pending_approval') {
      label = 'Chờ duyệt';
      color = const Color(0xFFD97706);
      bg = const Color(0xFFFFFBEB);
    } else if (status == 'locked') {
      label = 'Bị khóa';
      color = const Color(0xFFEF4444);
      bg = const Color(0xFFFEF2F2);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
