import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/models/user_model.dart';
import 'package:goship_app/core/theme/app_theme.dart';
import 'package:goship_app/features/auth/presentation/unified_login_screen.dart';
import 'package:goship_app/features/customer/home/presentation/customer_main_screen.dart';
import 'package:goship_app/features/customer/order/models/order_draft_model.dart';
import 'package:goship_app/features/customer/order/presentation/create_order_flow_screen.dart';
import 'package:goship_app/core/services/order_repository.dart';
import 'package:goship_app/features/customer/order/presentation/order_detail_screen.dart';
import 'package:goship_app/features/driver/home/presentation/driver_main_screen.dart';
import 'package:goship_app/features/driver/home/presentation/driver_home_tab.dart';
import 'package:latlong2/latlong.dart';
import 'package:goship_app/features/customer/order/models/simulated_driver_model.dart';
import 'package:goship_app/features/customer/order/presentation/steps/step1_address_screen.dart';
import 'package:goship_app/core/widgets/in_trip_chat_sheet.dart';
import 'package:goship_app/core/widgets/in_app_call_screen.dart';
import 'package:goship_app/core/widgets/in_app_message_banner.dart';
import 'package:goship_app/core/widgets/incoming_call_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('UnifiedLoginScreen renders customer and driver roles correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const UnifiedLoginScreen(),
      ),
    );

    expect(find.text('Khách hàng'), findsOneWidget);
    expect(find.text('Đối tác Tài xế'), findsOneWidget);
    expect(find.text('Xin chào!'), findsOneWidget);
    expect(find.text('Đăng nhập Khách hàng'), findsOneWidget);

    // Switch to Driver role tab
    await tester.tap(find.text('Đối tác Tài xế'));
    await tester.pumpAndSettle();

    expect(find.text('Xin chào Đối tác!'), findsOneWidget);
    expect(find.text('DÀNH CHO TÀI XẾ'), findsOneWidget);
    expect(find.text('Đăng nhập Đối tác Tài xế'), findsOneWidget);
  });

  testWidgets('CustomerMainScreen renders 4 bottom tabs and services correctly', (WidgetTester tester) async {
    final testUser = UserModel(
      id: 'test_cus_1',
      name: 'Nguyễn Minh Tuấn',
      phone: '0987654321',
      email: 'tuan@goship.vn',
      role: UserRole.customer,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CustomerMainScreen(user: testUser),
      ),
    );

    expect(find.text('Xin chào,'), findsOneWidget);
    expect(find.text('Nguyễn Minh Tuấn'), findsOneWidget);
    expect(find.text('Bạn cần giao gì?'), findsOneWidget);
    expect(find.text('Xe Bán tải'), findsOneWidget);
    expect(find.text('Xe van'), findsOneWidget);
    expect(find.text('Xe tải'), findsOneWidget);
    expect(find.text('Container'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);
  });

  testWidgets('CreateOrderFlowScreen navigates through 3 steps and calculates price', (WidgetTester tester) async {
    final initialDraft = OrderDraftModel(
      pickupAddress: 'Landmark 81, Bình Thạnh',
      dropoffAddresses: ['25 Điện Biên Phủ, Quận 3'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CreateOrderFlowScreen(initialDraft: initialDraft),
      ),
    );

    // Step 1: Address
    expect(find.text('Địa chỉ giao hàng'), findsOneWidget);
    expect(find.text('Bước 1/3'), findsOneWidget);
    expect(find.textContaining('Tiếp tục sang bước 2'), findsOneWidget);

    await tester.tap(find.textContaining('Tiếp tục sang bước 2'));
    await tester.pumpAndSettle();

    // Step 2: Package
    expect(find.text('Thông tin kiện hàng'), findsOneWidget);
    expect(find.text('Bước 2/3'), findsOneWidget);
    expect(find.text('Thông tin người gửi hàng'), findsOneWidget);
    expect(find.text('Thông tin người nhận hàng'), findsOneWidget);
    expect(find.text('Tiếp tục sang bước Tính cước & Xác nhận'), findsOneWidget);

    await tester.tap(find.text('Tiếp tục sang bước Tính cước & Xác nhận'));
    await tester.pumpAndSettle();

    // Step 3: Confirmation & Pricing
    expect(find.text('Xác nhận & Thanh toán'), findsOneWidget);
    expect(find.text('Bước 3/3'), findsOneWidget);
    expect(find.text('Thông tin đơn hàng'), findsOneWidget);
    expect(find.text('Phương thức thanh toán'), findsOneWidget);
    expect(find.text('Đặt đơn ngay'), findsOneWidget);

    await tester.tap(find.text('Đặt đơn ngay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // Order Detail Screen (Tracking screen)
    expect(find.text('Chi tiết đơn hàng'), findsOneWidget);
    expect(find.text('Đang tìm tài xế gần bạn...'), findsOneWidget);
    expect(find.text('Hành trình di chuyển'), findsOneWidget);
  });

  testWidgets('DriverMainScreen renders status header and performance stats', (WidgetTester tester) async {
    final testDriver = UserModel(
      id: 'test_drv_1',
      name: 'Lê Hoàng Nam',
      phone: '0901234567',
      email: 'nam@goship.vn',
      role: UserRole.driver,
      rating: 4.9,
      totalOrders: 348,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: DriverMainScreen(user: testDriver),
      ),
    );

    expect(find.text('Lê Hoàng Nam'), findsOneWidget);
    expect(find.text('Khách hàng'), findsOneWidget); // Switch to customer mode button!
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.text('Nhận đơn'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.text('Ví thu nhập'), findsOneWidget);
  });

  testWidgets('OrderDetailScreen displays e-POD exclusively for completed orders', (WidgetTester tester) async {
    final draft = OrderDraftModel(
      pickupAddress: '123 Lê Lợi, Q1',
      dropoffAddresses: ['456 Nguyễn Huệ, Q1'],
      recipientName: 'Trần Văn A',
    );

    // 1. When order is delivering: e-POD must NOT be shown
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderDetailScreen(
          draft: draft,
          orderCode: 'GS-DELIVERING-1',
          orderStatus: OrderStatus.delivering,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chứng từ điện tử (e-POD)'), findsNothing);

    // 2. When order is completed: e-POD MUST be shown with multi-photo support
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderDetailScreen(
          draft: draft,
          orderCode: 'GS-COMPLETED-1',
          orderStatus: OrderStatus.completed,
          epodPhotos: const ['mock_photo_1', 'mock_photo_2', 'mock_photo_3'],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Chứng từ điện tử (e-POD)'), findsOneWidget);
    expect(find.text('3 ảnh chứng từ'), findsOneWidget);

    // Scroll until visible and tap
    final epodFinder = find.text('Chạm để xem chi tiết ảnh có watermark GPS');
    await tester.ensureVisible(epodFinder);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(epodFinder);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify modal title renders without overflow and shows multiple photos
    expect(find.text('Chứng từ giao hàng điện tử (e-POD)'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Ảnh 1')), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Ảnh 2')), findsOneWidget);
    expect(find.descendant(of: find.byType(Dialog), matching: find.text('Ảnh 3')), findsOneWidget);
  });

  testWidgets('OrderDetailScreen connects pre-selected driver immediately', (WidgetTester tester) async {
    final preSelectedDriver = SimulatedDriver(
      id: 'drv_02',
      name: 'Nguyễn Hoàng Long',
      phone: '0908 765 432',
      plate: '51D 892.14',
      vehicleType: 'pickup',
      vehicleName: 'Xe bán tải Ranger 750kg',
      rating: 4.95,
      tripsCount: 620,
      avatarUrl: '',
      currentPosition: const LatLng(10.7940, 106.7180),
      addressHint: 'Đậu gần ngã tư Điện Biên Phủ',
    );

    final draft = OrderDraftModel(
      pickupAddress: 'Landmark 81, Bình Thạnh',
      dropoffAddresses: ['25 Điện Biên Phủ, Quận 3'],
      selectedDriver: preSelectedDriver,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderDetailScreen(
          draft: draft,
          orderCode: 'GS-PRESELECT-1',
        ),
      ),
    );
    await tester.pump();

    // Verify finding banner specifically displays pre-selected driver's name and vehicle
    expect(find.text('Đang kết nối tài xế: Nguyễn Hoàng Long'), findsOneWidget);
    expect(find.text('Xe: Xe bán tải Ranger 750kg'), findsOneWidget);
  });

  testWidgets('OrderDetailScreen features fullscreen map and draggable sheet with driver card and swipe hint', (WidgetTester tester) async {
    final draft = OrderDraftModel(
      pickupAddress: 'Landmark 81, Bình Thạnh',
      dropoffAddresses: ['25 Điện Biên Phủ, Quận 3'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderDetailScreen(
          draft: draft,
          orderCode: 'GS-SHEET-TEST-1',
          orderStatus: OrderStatus.delivering,
          enableAutoSimulation: true,
        ),
      ),
    );
    await tester.pump();

    // Verify DraggableScrollableSheet is rendered
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    // Initial finding state
    expect(find.text('Đang tìm tài xế gần bạn...'), findsOneWidget);
    expect(find.text('Đang kết nối tài xế phù hợp...'), findsOneWidget);
    expect(find.text('Vuốt lên để xem chi tiết đơn hàng'), findsOneWidget);

    // Fast-forward past driver matching timer (3.5s)
    await tester.pump(const Duration(milliseconds: 3600));
    await tester.pump();

    // Verify Driver Card & Action Buttons appear in bottom sheet once driver accepts
    expect(find.text('Trần Văn Hùng'), findsOneWidget);
    expect(find.text('Nhắn tin'), findsOneWidget);
    expect(find.text('Gọi tài xế'), findsOneWidget);
  });

  testWidgets('Step1AddressScreen removes 5-car suggestion banner and supports full-screen map toggle', (WidgetTester tester) async {
    final draft = OrderDraftModel(
      pickupAddress: 'Vinhomes Central Park, Bình Thạnh',
      pickupLatLng: const LatLng(10.7946, 106.7218),
      dropoffAddresses: ['25 Điện Biên Phủ, Quận 3'],
      dropoffLatLngs: [const LatLng(10.7830, 106.6960)],
      distanceKm: 5.2,
      durationMinutes: 18,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Step1AddressScreen(
          draft: draft,
          onNext: () {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Verify 5-car suggestion banner is NOT present
    expect(find.textContaining('xe tải GoShip quanh điểm lấy'), findsNothing);

    // 2. Verify single dedicated fullscreen trigger button exists (no duplicate "Mở rộng")
    expect(find.text('Mở rộng'), findsNothing);
    expect(find.text('Toàn màn hình'), findsOneWidget);

    // 3. Tap "Toàn màn hình" to open fullscreen map
    await tester.tap(find.text('Toàn màn hình'));
    await tester.pump(const Duration(milliseconds: 200));

    // 4. Verify Fullscreen Map Header & single Collapse button appear (no redundant bottom button)
    expect(find.text('Bản đồ lộ trình & Tài xế'), findsOneWidget);
    expect(find.byTooltip('Thu nhỏ bản đồ'), findsOneWidget);
    expect(find.text('Thu nhỏ bản đồ (Tiếp tục đặt hàng)'), findsNothing);

    // 5. Tap the single "Thu nhỏ bản đồ" back button to return to normal view
    await tester.tap(find.byTooltip('Thu nhỏ bản đồ'));
    await tester.pump(const Duration(milliseconds: 200));

    // 6. Verify returned to normal Step 1 input view
    expect(find.text('Địa chỉ giao hàng'), findsOneWidget);
    expect(find.text('Toàn màn hình'), findsOneWidget);
  });

  testWidgets('OrderDetailScreen displays cancel order button during finding state and opens confirmation modal', (WidgetTester tester) async {
    final draft = OrderDraftModel(
      pickupAddress: 'Landmark 81, Bình Thạnh',
      dropoffAddresses: ['25 Điện Biên Phủ, Quận 3'],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: OrderDetailScreen(
          draft: draft,
          orderCode: 'GS-CANCEL-TEST',
          orderStatus: OrderStatus.pending,
          enableAutoSimulation: false,
        ),
      ),
    );
    await tester.pump();

    // Verify finding state & cancel button are displayed
    expect(find.text('Hủy tìm kiếm chuyến xe'), findsOneWidget);

    // Tap cancel button
    await tester.tap(find.text('Hủy tìm kiếm chuyến xe'));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify cancel confirmation modal appears with reasons
    expect(find.text('Xác nhận hủy đơn hàng'), findsOneWidget);
    expect(find.text('Đổi ý, không muốn gửi hàng nữa'), findsOneWidget);
    expect(find.text('Xác nhận hủy'), findsOneWidget);
    expect(find.text('Giữ lại đơn'), findsOneWidget);
  });

  testWidgets('InTripChatSheet renders header, suggestion chips and message input', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: InTripChatSheet(
            orderCode: 'GS-CHAT-TEST',
            currentUserId: 'cust_01',
            currentUserName: 'Nguyễn Văn A',
            currentUserRole: 'customer',
            otherPartyName: 'Tài xế Hùng',
            otherPartyPhone: '0901234567',
            otherPartyRole: 'Tài xế',
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify header with contact name and order code
    expect(find.text('Tài xế Hùng'), findsOneWidget);
    expect(find.text('Tài xế'), findsOneWidget);
    expect(find.text('Đơn #GS-CHAT-TEST'), findsOneWidget);

    // Verify customer quick suggestion tags
    expect(find.text('Bác tài tới đâu rồi ạ?'), findsOneWidget);
    expect(find.text('Em đang đợi ở trước cổng/sảnh'), findsOneWidget);

    // Verify input field
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('DriverHomeTab renders online status switch and map controls', (WidgetTester tester) async {
    final testDriver = UserModel(
      id: 'drv_test_99',
      name: 'Nguyễn Văn Tài Xế',
      phone: '0988776655',
      email: 'taixe@goship.vn',
      role: UserRole.driver,
      vehicleType: 'Xe Bán tải',
      plateNumber: '51D-999.88',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: DriverHomeTab(user: testDriver),
        ),
      ),
    );
    await tester.pump();

    // Verify driver info header
    expect(find.text('Nguyễn Văn Tài Xế'), findsOneWidget);

    // Verify Online switch
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);

    // Toggle switch to Offline
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Đang tạm nghỉ'), findsOneWidget);

    // Toggle back to Online
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('Đang hoạt động'), findsOneWidget);
  });

  testWidgets('InAppCallScreen renders callee details, security badge, and call controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InAppCallScreen(
          calleeName: 'Trần Văn Tài',
          calleePhone: '0912345678',
          calleeRole: 'Tài xế GoShip',
          orderCode: 'GS-CALL-99',
        ),
      ),
    );
    await tester.pump();

    // Verify callee information
    expect(find.text('Trần Văn Tài'), findsOneWidget);
    expect(find.text('Tài xế GoShip • 0912345678'), findsOneWidget);
    expect(find.text('Mã chuyến: GS-CALL-99'), findsOneWidget);
    expect(find.text('Cuộc gọi nội bộ bảo mật GoShip'), findsOneWidget);

    // Verify initial call status
    expect(find.text('Đang đổ chuông...'), findsOneWidget);

    // Verify control labels
    expect(find.text('Tắt mic'), findsOneWidget);
    expect(find.text('Mở camera'), findsOneWidget);
    expect(find.text('Loa ngoài'), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);

    // Test mute toggle
    await tester.tap(find.text('Tắt mic'));
    await tester.pump();
    expect(find.text('Đã tắt mic'), findsOneWidget);

    // Test speaker toggle
    await tester.tap(find.text('Loa ngoài'));
    await tester.pump();
    expect(find.text('Loa trong'), findsOneWidget);
  });

  testWidgets('InAppMessageNotification displays slide down banner with sender name and message preview', (WidgetTester tester) async {
    bool bannerTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                InAppMessageNotification.show(
                  context,
                  senderName: 'Nguyễn Văn Tài',
                  senderRole: 'Tài xế',
                  messageText: 'Tôi đã đến nơi, đang đợi ở sảnh.',
                  onTap: () {
                    bannerTapped = true;
                  },
                );
              },
              child: const Text('Show Banner'),
            ),
          ),
        ),
      ),
    );

    // Tap button to show in-app banner
    await tester.tap(find.text('Show Banner'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify banner content
    expect(find.text('Nguyễn Văn Tài'), findsOneWidget);
    expect(find.text('Tài xế'), findsOneWidget);
    expect(find.text('Tôi đã đến nơi, đang đợi ở sảnh.'), findsOneWidget);
    expect(find.text('Vừa xong'), findsOneWidget);
    expect(find.text('Xem'), findsOneWidget);

    // Tap banner and verify callback
    await tester.tap(find.text('Xem'));
    await tester.pump();
    expect(bannerTapped, isTrue);
  });

  testWidgets('IncomingCallDialog renders caller info and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IncomingCallDialog(
            orderCode: 'GS-CALL-TEST-01',
            callerName: 'Nguyễn Văn Khách',
            callerRole: 'Khách hàng',
            callerPhone: '0901234567',
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify caller info and order
    expect(find.text('Nguyễn Văn Khách'), findsOneWidget);
    expect(find.text('Khách hàng đang gọi cho bạn...'), findsOneWidget);
    expect(find.text('Đơn hàng: GS-CALL-TEST-01'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Từ chối'), findsOneWidget);
    expect(find.text('Trả lời'), findsOneWidget);
  });
}
