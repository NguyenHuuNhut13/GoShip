import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/order_repository.dart';
import '../../../../core/widgets/app_avatar_widget.dart';
import '../../order/models/order_draft_model.dart';
import '../../order/presentation/create_order_flow_screen.dart';
import 'widgets/logistics_chat_bubble_widget.dart';

class CustomerHomeTab extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onOpenNotifications;
  final int unreadNotificationsCount;
  final OrderRecord? activeOrder;
  final VoidCallback? onOpenActiveOrder;
  final OrderRecord? recentlyCompletedOrder;
  final VoidCallback? onOpenRecentlyCompletedOrder;

  const CustomerHomeTab({
    super.key,
    required this.user,
    this.onOpenNotifications,
    this.unreadNotificationsCount = 0,
    this.activeOrder,
    this.onOpenActiveOrder,
    this.recentlyCompletedOrder,
    this.onOpenRecentlyCompletedOrder,
  });

  void _openBookingWithDraft(
    BuildContext context, {
    OrderVehicleType vehicleType = OrderVehicleType.motorbike,
    String promoCode = '',
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOrderFlowScreen(
          initialVehicle: vehicleType,
          initialDraft: OrderDraftModel(
            vehicleType: vehicleType,
            senderName: user.name,
            senderPhone: user.phone,
            promoCode: promoCode,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Greeting Block (Figma greeting-block: 402x76)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      AppAvatarWidget(
                        avatarUrl: user.avatarUrl,
                        name: user.name,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Xin chào,',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            user.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF7F9FC),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF1E293B)),
                          onPressed: () {
                            if (onOpenNotifications != null) {
                              onOpenNotifications!();
                            }
                          },
                        ),
                      ),
                      if (unreadNotificationsCount > 0)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: Text(
                              unreadNotificationsCount > 9 ? '9+' : '$unreadNotificationsCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Active Order Live Tracking Banner
              if (activeOrder != null) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: onOpenActiveOrder,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 22),
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
                                      color: const Color(0xFF4ADE80),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      activeOrder!.status.label.toUpperCase(),
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Đơn #${activeOrder!.orderCode}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Giao tới: ${activeOrder!.dropoffAddresses.isNotEmpty ? activeOrder!.dropoffAddresses.first : activeOrder!.pickupAddress}',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Theo dõi',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Recently Completed Order Banner (e-POD & Rating Reminder)
              if (activeOrder == null && recentlyCompletedOrder != null) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: onOpenRecentlyCompletedOrder,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF065F46), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.stars_rounded, color: Colors.white, size: 22),
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
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'GIAO THÀNH CÔNG',
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Đơn #${recentlyCompletedOrder!.orderCode}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Chạm để xem biên bản e-POD & đánh giá 5 sao tài xế ⭐',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Đánh giá',
                            style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.w800, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // 2. Service Quick Actions Section (Figma service-quick-actions)
              const Text(
                'Bạn cần giao gì?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E283A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Chọn phương tiện phù hợp với đơn hàng',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF63728C),
                ),
              ),

              const SizedBox(height: 18),

              // 4 Circular Service Items in a Row (Icon tròn + chữ ở dưới, icon xe bán tải chuẩn 🛻)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildCircularServiceItem(
                        context: context,
                        icon: '🛻',
                        title: 'Xe Bán tải',
                        bgColor: const Color(0xFFFFF4E8),
                        iconColor: const Color(0xFFFF6B00),
                      ),
                    ),
                    Expanded(
                      child: _buildCircularServiceItem(
                        context: context,
                        icon: '🚐',
                        title: 'Xe van',
                        bgColor: const Color(0xFFEAF7FF),
                        iconColor: const Color(0xFF2563EB),
                      ),
                    ),
                    Expanded(
                      child: _buildCircularServiceItem(
                        context: context,
                        icon: '🚚',
                        title: 'Xe tải',
                        bgColor: const Color(0xFFEFF9F2),
                        iconColor: const Color(0xFF16A34A),
                      ),
                    ),
                    Expanded(
                      child: _buildCircularServiceItem(
                        context: context,
                        icon: '📦',
                        title: 'Container',
                        bgColor: const Color(0xFFF7EFFF),
                        iconColor: const Color(0xFF9333EA),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Discover GoShip Corporate Banner (Figma discover-goship: #1E3359)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3359),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3359).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFC13F).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFFC13F), width: 1),
                      ),
                      child: const Text(
                        'GOSHIP CHO DOANH NGHIỆP',
                        style: TextStyle(
                          color: Color(0xFFFFC13F),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Gửi nhiều, tiết kiệm hơn',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Giải pháp giao hàng đa điểm kèm trợ giá 50.000đ (Mã: TRUCK50) cho Xe van & Xe tải.',
                      style: TextStyle(
                        color: Color(0xFFD8E5F9),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        _openBookingWithDraft(
                          context,
                          vehicleType: OrderVehicleType.van,
                          promoCode: 'TRUCK50',
                        );
                      },
                      child: const Text(
                        'Đặt Xe Van nhận ưu đãi 50K',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Promo Section (Figma promo-heading & promo-card: #EAF7FF)
              const Text(
                'Ưu đãi hôm nay',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E283A),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _openBookingWithDraft(context, promoCode: 'WELCOME30'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0E8FF)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B00).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF6B00), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Giảm 30% cho đơn đầu tiên',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1E283A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Text(
                                  'Áp dụng mã: ',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF63728C)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6B00),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'WELCOME30',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF63728C)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openBookingWithDraft(context, promoCode: 'GOSHIP50'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Siêu hội vận chuyển • Giảm 50% (Tối đa 50K)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF1E283A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Text(
                                  'Áp dụng mã: ',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF63728C)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'GOSHIP50',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF63728C)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      floatingActionButton: const LogisticsChatBubbleWidget(),
    );
  }

  Widget _buildCircularServiceItem({
    required BuildContext context,
    required String icon,
    required String title,
    required Color bgColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: () {
        _openBookingWithDraft(
          context,
          vehicleType: OrderVehicleType.fromName(title),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: iconColor.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E283A),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
