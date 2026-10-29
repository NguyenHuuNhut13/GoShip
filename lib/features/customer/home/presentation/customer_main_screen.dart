import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/firestore_order_service.dart';
import '../../../../core/services/order_repository.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../../auth/data/auth_service.dart';
import '../../../auth/presentation/unified_login_screen.dart';
import '../../../driver/home/presentation/driver_main_screen.dart';
import '../../order/models/order_draft_model.dart';
import '../../order/models/simulated_driver_model.dart';
import '../../order/presentation/create_order_flow_screen.dart';
import '../../order/presentation/order_detail_screen.dart';
import '../../profile/presentation/customer_profile_detail_screen.dart';
import '../../profile/presentation/saved_addresses_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'customer_home_tab.dart';

class CustomerMainScreen extends StatefulWidget {
  final UserModel user;
  const CustomerMainScreen({super.key, required this.user});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;
  late UserModel _currentUser;

  // Order history state
  List<OrderRecord> _orders = [];
  bool _isLoadingOrders = true;
  String _selectedOrderStatusFilter = 'all'; // 'all', 'pending', 'delivering', 'completed', 'cancelled'
  final _currencyFormat = NumberFormat('#,###', 'vi_VN');
  StreamSubscription<List<OrderRecord>>? _ordersSubscription;
  final Set<String> _readNotificationIds = {};

  String get _notifPrefsKey =>
      'customer_read_notifs_${_currentUser.phone.isNotEmpty ? _currentUser.phone : (_currentUser.id.isNotEmpty ? _currentUser.id : "default")}';

  Future<void> _loadReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_notifPrefsKey) ?? [];
      if (mounted && list.isNotEmpty) {
        setState(() {
          _readNotificationIds.addAll(list);
        });
      }
    } catch (e) {
      debugPrint('Error loading read notifications: $e');
    }
  }

  Future<void> _saveReadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_notifPrefsKey, _readNotificationIds.toList());
    } catch (e) {
      debugPrint('Error saving read notifications: $e');
    }
  }

  void _markAllNotificationsAsRead() {
    final recentOrders = _orders.take(8).toList();
    setState(() {
      for (final o in recentOrders) {
        _readNotificationIds.add('${o.orderCode}_${o.status.name}');
      }
      _readNotificationIds.add('promo_welcome30');
      _readNotificationIds.add('promo_goship50');
    });
    _saveReadNotifications();
  }

  void _markNotificationAsRead(String notifId) {
    if (!_readNotificationIds.contains(notifId)) {
      setState(() {
        _readNotificationIds.add(notifId);
      });
      _saveReadNotifications();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadReadNotifications();
    _loadOrders();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _initOrdersStream() {
    _ordersSubscription?.cancel();
    final phone = _currentUser.phone;
    if (phone.isNotEmpty) {
      _ordersSubscription = FirestoreOrderService.streamCustomerOrders(phone).listen(
        (cloudOrders) {
          if (!mounted) return;
          if (cloudOrders.isNotEmpty) {
            setState(() {
              _orders = cloudOrders;
              _isLoadingOrders = false;
            });
          }
        },
        onError: (e) {
          debugPrint('>>> [CustomerMainScreen _initOrdersStream Error]: $e');
          if (mounted) {
            setState(() => _isLoadingOrders = false);
          }
        },
      );
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final res = await ApiClient.getUserProfile(currentUser: _currentUser);
      var updated = (res.isSuccess && res.data != null) ? res.data! : _currentUser;
      updated = await AuthService.fetchCloudProfile(updated);
      if (mounted) {
        setState(() => _currentUser = updated);
        await AuthService.saveSession(updated, syncCloud: false);
      }
    } catch (_) {}
  }

  Future<void> _openProfileDetail() async {
    final updated = await Navigator.push<UserModel>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerProfileDetailScreen(user: _currentUser),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoadingOrders = true);
    // 1. Load local cache first
    final list = await OrderRepository.getOrders();
    if (mounted) {
      setState(() {
        _orders = list;
        _isLoadingOrders = false;
      });
    }
    // 2. Start/Restart live stream from Firestore
    _initOrdersStream();
  }

  OrderDraftModel _buildDraftFromOrder(OrderRecord order) {
    return OrderDraftModel(
      pickupAddress: order.pickupAddress,
      dropoffAddresses: List<String>.from(order.dropoffAddresses),
      dropoffRecipients: order.dropoffRecipients.map((r) => r.clone()).toList(),
      vehicleType: OrderVehicleType.fromName(order.vehicleName),
      packageCategory: order.packageCategory,
      weightCategory: order.weightCategory,
      senderName: order.senderName.isNotEmpty ? order.senderName : _currentUser.name,
      senderPhone: order.senderPhone.isNotEmpty ? order.senderPhone : _currentUser.phone,
      recipientName: order.recipientName,
      recipientPhone: order.recipientPhone,
      driverNote: order.driverNote,
      paymentMethod: PaymentMethod.fromName(order.paymentMethod),
      promoCode: order.promoCode ?? '',
      discountAmount: order.discountAmount.toDouble(),
      packagePhotoBase64: order.packagePhotoBase64,
      distanceKm: order.distanceKm,
      durationMinutes: order.durationMinutes,
      pickupLatLng: (order.pickupLat != null && order.pickupLng != null)
          ? LatLng(order.pickupLat!, order.pickupLng!)
          : null,
      dropoffLatLngs: (order.dropoffLats != null && order.dropoffLngs != null)
          ? List.generate(
              order.dropoffLats!.length,
              (i) => LatLng(order.dropoffLats![i], order.dropoffLngs![i]),
            )
          : [],
      drivingRoutePoints: order.routeCoords != null
          ? order.routeCoords!.map((c) => LatLng(c[0], c[1])).toList()
          : [],
      epodPhotos: List<String>.from(order.epodPhotos),
      selectedDriver: (order.driverName?.isNotEmpty == true || order.assignedDriverName?.isNotEmpty == true)
          ? SimulatedDriver(
              id: order.driverId ?? order.assignedDriverId ?? 'drv_01',
              name: order.driverName ?? order.assignedDriverName ?? 'Tài xế GoShip',
              phone: (order.driverPhone != null && order.driverPhone!.trim().isNotEmpty)
                  ? order.driverPhone!.trim()
                  : '0917795211',
              plate: (order.driverPlate != null && order.driverPlate!.trim().isNotEmpty)
                  ? order.driverPlate!.trim()
                  : '59P1-987.65',
              vehicleType: 'van',
              vehicleName: order.vehicleName,
              rating: 4.9,
              tripsCount: 120,
              avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
              currentPosition: (order.pickupLat != null && order.pickupLng != null)
                  ? LatLng(order.pickupLat!, order.pickupLng!)
                  : const LatLng(10.7725, 106.6980),
            )
          : null,
    );
  }

  void _openOrderDetail(OrderRecord order) {
    final draft = _buildDraftFromOrder(order);
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
  }

  void _rebookOrder(OrderRecord order) {
    final rebookDraft = _buildDraftFromOrder(order);
    rebookDraft.epodPhotos = [];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrderFlowScreen(initialDraft: rebookDraft),
      ),
    );
  }

  OrderRecord? get _activeOrder {
    for (final o in _orders) {
      if (o.status == OrderStatus.delivering ||
          o.status == OrderStatus.pending ||
          o.status == OrderStatus.pendingDirect) {
        return o;
      }
    }
    return null;
  }

  OrderRecord? get _recentlyCompletedOrder {
    final now = DateTime.now();
    for (final o in _orders) {
      if (o.status == OrderStatus.completed) {
        final diff = now.difference(o.createdAt);
        // Completed within the last 24 hours
        if (diff.inHours < 24) {
          return o;
        }
      }
    }
    return null;
  }

  int get _unreadNotificationsCount {
    int count = 0;
    for (final o in _orders.take(8)) {
      final id = '${o.orderCode}_${o.status.name}';
      if (!_readNotificationIds.contains(id)) count++;
    }
    if (!_readNotificationIds.contains('promo_welcome30')) count++;
    if (!_readNotificationIds.contains('promo_goship50')) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final activeOrder = _activeOrder;
    final recentlyCompleted = _recentlyCompletedOrder;
    final unreadCount = _unreadNotificationsCount;

    final tabs = [
      CustomerHomeTab(
        user: _currentUser,
        onOpenNotifications: () {
          setState(() => _currentIndex = 2);
          _markAllNotificationsAsRead();
        },
        unreadNotificationsCount: unreadCount,
        activeOrder: activeOrder,
        onOpenActiveOrder: activeOrder != null ? () => _openOrderDetail(activeOrder) : null,
        recentlyCompletedOrder: recentlyCompleted,
        onOpenRecentlyCompletedOrder: recentlyCompleted != null ? () => _openOrderDetail(recentlyCompleted) : null,
      ),
      _buildOrdersTab(),
      _buildNotificationsTab(),
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
          onTap: (idx) {
            setState(() => _currentIndex = idx);
            if (idx == 1) _loadOrders();
            if (idx == 2) _markAllNotificationsAsRead();
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Trang chủ',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Đơn hàng',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: unreadCount > 0,
                label: Text('$unreadCount', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800)),
                child: const Icon(Icons.notifications_rounded),
              ),
              label: 'Thông báo',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Tài khoản',
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 2: LỊCH SỬ ĐƠN HÀNG (ORDER HISTORY) ---
  Widget _buildOrdersTab() {
    final filtered = _orders.where((o) {
      if (_selectedOrderStatusFilter == 'pending') {
        return o.status == OrderStatus.pending || o.status == OrderStatus.pendingDirect;
      }
      if (_selectedOrderStatusFilter == 'delivering') return o.status == OrderStatus.delivering;
      if (_selectedOrderStatusFilter == 'completed') return o.status == OrderStatus.completed;
      if (_selectedOrderStatusFilter == 'cancelled') return o.status == OrderStatus.cancelled;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Lịch sử Đơn hàng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusFilterChip('all', 'Tất cả (${_orders.length})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('pending', 'Đang tìm xe (${_orders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.pendingDirect).length})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('delivering', 'Đang giao (${_orders.where((o) => o.status == OrderStatus.delivering).length})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('completed', 'Hoàn thành (${_orders.where((o) => o.status == OrderStatus.completed).length})'),
                  const SizedBox(width: 8),
                  _buildStatusFilterChip('cancelled', 'Đã hủy (${_orders.where((o) => o.status == OrderStatus.cancelled).length})'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Orders List
          Expanded(
            child: _isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.inbox_outlined, size: 64, color: AppColors.textMuted),
                            SizedBox(height: 16),
                            Text(
                              'Không có đơn hàng nào',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 6),
                            Text('Các đơn bạn tạo sẽ xuất hiện tại đây để theo dõi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 14),
                          itemBuilder: (ctx, idx) {
                            return _buildOrderHistoryCard(filtered[idx]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterChip(String key, String label) {
    final isSelected = _selectedOrderStatusFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedOrderStatusFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderHistoryCard(OrderRecord order) {
    Color statusColor = AppColors.primary;
    Color statusBg = const Color(0xFFEFF6FF);
    if (order.status == OrderStatus.pending || order.status == OrderStatus.pendingDirect) {
      statusColor = AppColors.accent;
      statusBg = const Color(0xFFFFF7ED);
    } else if (order.status == OrderStatus.completed) {
      statusColor = AppColors.success;
      statusBg = const Color(0xFFEFF9F2);
    } else if (order.status == OrderStatus.cancelled) {
      statusColor = AppColors.danger;
      statusBg = const Color(0xFFFEF2F2);
    }

    final dropoffText = order.dropoffAddresses.length > 1
        ? '${order.dropoffAddresses.first} (+${order.dropoffAddresses.length - 1} điểm nữa)'
        : (order.dropoffAddresses.isNotEmpty ? order.dropoffAddresses.first : '');

    return InkWell(
      onTap: () => _openOrderDetail(order),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Code & Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      order.orderCode,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                    ),
                    Builder(
                      builder: (context) {
                        final pm = PaymentMethod.fromName(order.paymentMethod);
                        final Color badgeBg;
                        final Color badgeColor;
                        final String badgeText;

                        switch (pm) {
                          case PaymentMethod.momo:
                            badgeBg = const Color(0xFFFDF2F8);
                            badgeColor = const Color(0xFFA50064);
                            badgeText = 'MoMo';
                            break;
                          case PaymentMethod.zalopay:
                            badgeBg = const Color(0xFFEFF6FF);
                            badgeColor = const Color(0xFF0068FF);
                            badgeText = 'ZaloPay';
                            break;
                          case PaymentMethod.cash:
                            badgeBg = const Color(0xFFF0FDF4);
                            badgeColor = const Color(0xFF15803D);
                            badgeText = 'Tiền mặt';
                            break;
                        }

                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeColor),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    order.status.fullLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const Divider(height: 18),

            // Route points
            Row(
              children: [
                const Icon(Icons.circle, color: AppColors.primary, size: 10),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.pickupAddress.isNotEmpty ? order.pickupAddress : 'Điểm lấy hàng',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.circle, color: AppColors.accent, size: 10),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dropoffText.isNotEmpty ? dropoffText : 'Điểm giao hàng',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bottom metadata: vehicle, time, total fee + Rebook button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          order.vehicleName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DateFormat('dd/MM HH:mm').format(order.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      '${_currencyFormat.format(order.totalFee)} đ',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.accent),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () => _rebookOrder(order),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.replay_rounded, size: 13, color: AppColors.primary),
                            SizedBox(width: 4),
                            Text(
                              'Đặt lại',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 3: THÔNG BÁO (NOTIFICATIONS) ---
  Widget _buildNotificationsTab() {
    final recentOrders = _orders.take(8).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          if (_unreadNotificationsCount > 0)
            TextButton.icon(
              onPressed: _markAllNotificationsAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 16, color: AppColors.primary),
              label: const Text('Đọc tất cả', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Real-time order status notifications
          ...recentOrders.map((order) {
            final notifId = '${order.orderCode}_${order.status.name}';
            final isUnread = !_readNotificationIds.contains(notifId);
            String title;
            String desc;
            IconData icon;
            Color badgeColor;

            if (order.status == OrderStatus.delivering) {
              title = 'Tài xế ${order.driverName ?? "GoShip"} đang giao đơn #${order.orderCode}';
              desc = 'Phương tiện ${order.vehicleName} (${order.driverPlate ?? "Đang cập nhật"}) đang di chuyển trên lộ trình. Nhấn để xem GPS trực tiếp.';
              icon = Icons.local_shipping_rounded;
              badgeColor = AppColors.primary;
            } else if (order.status == OrderStatus.completed) {
              title = 'Đơn hàng #${order.orderCode} đã giao thành công!';
              desc = 'Biên bản e-POD (${order.epodPhotos.length} ảnh) đã lưu. Tổng cước: ${_currencyFormat.format(order.totalFee)} đ.';
              icon = Icons.verified_rounded;
              badgeColor = AppColors.success;
            } else if (order.status == OrderStatus.cancelled) {
              title = 'Đơn hàng #${order.orderCode} đã bị hủy';
              desc = 'Nhấn vào để xem chi tiết hoặc đặt lại chuyến xe mới nhanh chóng.';
              icon = Icons.cancel_rounded;
              badgeColor = AppColors.danger;
            } else {
              title = 'Đang tìm tài xế cho đơn #${order.orderCode}';
              desc = 'Hệ thống đang phát sóng đơn hàng tới các tài xế ${order.vehicleName} gần điểm lấy hàng nhất.';
              icon = Icons.radar_rounded;
              badgeColor = AppColors.accent;
            }

            return _buildNotifItem(
              title: title,
              desc: desc,
              time: DateFormat('dd/MM HH:mm').format(order.createdAt),
              isNew: isUnread,
              icon: icon,
              badgeColor: badgeColor,
              onTap: () {
                _markNotificationAsRead(notifId);
                _openOrderDetail(order);
              },
            );
          }),

          // Interactive Promo Notifications
          _buildNotifItem(
            title: '🎁 Ưu đãi 30% cho chuyến xe GoShip (Mã: WELCOME30)',
            desc: 'Chạm vào thông báo này để tạo đơn ngay với mã giảm 30% (tối đa 50.000đ) tự động áp dụng.',
            time: 'Khuyến mãi đang mở',
            isNew: !_readNotificationIds.contains('promo_welcome30'),
            icon: Icons.local_offer_rounded,
            badgeColor: AppColors.accent,
            onTap: () {
              _markNotificationAsRead('promo_welcome30');
              final draft = OrderDraftModel(
                senderName: _currentUser.name,
                senderPhone: _currentUser.phone,
                promoCode: 'WELCOME30',
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateOrderFlowScreen(initialDraft: draft)),
              );
            },
          ),
          _buildNotifItem(
            title: '🚚 Giảm ngay 50.000đ cho đơn Xe Van & Xe Tải (Mã: GOSHIP50)',
            desc: 'Áp dụng cho mọi tuyến đường nội thành & liên tỉnh. Nhấn để đặt xe ngay!',
            time: 'Khuyến mãi đang mở',
            isNew: !_readNotificationIds.contains('promo_goship50'),
            icon: Icons.discount_rounded,
            badgeColor: AppColors.primary,
            onTap: () {
              _markNotificationAsRead('promo_goship50');
              final draft = OrderDraftModel(
                senderName: _currentUser.name,
                senderPhone: _currentUser.phone,
                vehicleType: OrderVehicleType.van,
                promoCode: 'GOSHIP50',
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateOrderFlowScreen(initialDraft: draft)),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotifItem({
    required String title,
    required String desc,
    required String time,
    required bool isNew,
    IconData icon = Icons.notifications_rounded,
    Color badgeColor = AppColors.primary,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNew ? AppColors.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isNew ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isNew ? badgeColor : AppColors.border,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 16),
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
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      if (onTap != null)
                        const Text(
                          'Xem ngay →',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 4: TÀI KHOẢN & HỒ SƠ (ACCOUNT PROFILE) ---
  Widget _buildProfileTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tài khoản & Cài đặt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchUserProfile();
          await _loadOrders();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // User Profile Summary Card (Compact, tap to view full profile)
            InkWell(
              onTap: _openProfileDetail,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    AppAvatarWidget(
                      avatarUrl: _currentUser.avatarUrl,
                      name: _currentUser.name,
                      size: 58,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentUser.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tài khoản Khách hàng',
                              style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Switch to Driver Mode Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_rounded, color: AppColors.accent, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chuyển sang giao diện Tài xế',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Nhận đơn và xem ví thu nhập tài xế',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    final driverUser = _currentUser.copyWith(
                      role: UserRole.driver,
                      avatarUrl: _currentUser.avatarUrl ?? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                      rating: 4.9,
                      totalOrders: 348,
                      plateNumber: _currentUser.plateNumber ?? '59P1-987.65',
                      vehicleType: _currentUser.vehicleType ?? 'Xe Bán tải',
                    );
                    AuthService.saveSession(driverUser);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => DriverMainScreen(user: driverUser)),
                    );
                  },
                  child: const Text('Chuyển', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Menu items
          _buildMenuRow(
            Icons.person_outline_rounded,
            'Xem thông tin tài khoản',
            onTap: _openProfileDetail,
          ),
          _buildMenuRow(
            Icons.location_on_outlined,
            'Quản lý địa chỉ đã lưu (Nhà, Công ty, Kho)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
              );
            },
          ),
          _buildMenuRow(
            Icons.credit_card_outlined,
            'Phương thức thanh toán liên kết',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hỗ trợ Tiền mặt, Ví MoMo, ZaloPay khi thanh toán đơn hàng.')),
              );
            },
          ),
          _buildMenuRow(
            Icons.headset_mic_outlined,
            'Hỗ trợ khách hàng 24/7 (Hotline 1900 6868)',
            onTap: () async {
              final uri = Uri.parse('tel:19006868');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tổng đài hỗ trợ GoShip: 1900 6868 (Phục vụ 24/7)')),
                );
              }
            },
          ),
          _buildMenuRow(
            Icons.security_outlined,
            'Chính sách bảo mật & Điều khoản sử dụng',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('GoShip cam kết bảo mật 100% dữ liệu khách hàng.')),
              );
            },
          ),

          const SizedBox(height: 28),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất tài khoản', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const UnifiedLoginScreen()),
                  (route) => false,
                );
              },
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

  Widget _buildMenuRow(IconData icon, String title, {required VoidCallback onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
