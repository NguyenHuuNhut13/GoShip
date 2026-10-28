import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/models/user_model.dart';
import 'package:goship_app/core/services/ai_logistics_chat_service.dart';
import 'package:goship_app/core/theme/app_theme.dart';
import 'package:goship_app/features/customer/home/presentation/customer_home_tab.dart';
import 'package:goship_app/features/customer/home/presentation/widgets/logistics_chat_bottom_sheet.dart';
import 'package:goship_app/features/customer/home/presentation/widgets/logistics_chat_bubble_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiLogisticsChatService.forceOfflineMode = true;
  });

  tearDown(() {
    AiLogisticsChatService.forceOfflineMode = false;
  });

  testWidgets('CustomerHomeTab renders LogisticsChatBubbleWidget at bottom right', (WidgetTester tester) async {
    final testUser = UserModel(
      id: 'test_1',
      name: 'Nguyen Van A',
      phone: '0901234567',
      email: 'a@gmail.com',
      role: UserRole.customer,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CustomerHomeTab(user: testUser),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LogisticsChatBubbleWidget), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
  });

  testWidgets('Tapping chat bubble opens LogisticsChatBottomSheet', (WidgetTester tester) async {
    final testUser = UserModel(
      id: 'test_2',
      name: 'Nguyen Van B',
      phone: '0901234568',
      email: 'b@gmail.com',
      role: UserRole.customer,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CustomerHomeTab(user: testUser),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap the floating bubble
    await tester.tap(find.byIcon(Icons.smart_toy_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Verify Bottom Sheet is displayed
    expect(find.byType(LogisticsChatBottomSheet), findsOneWidget);
    expect(find.text('GoShip AI Logistics'), findsOneWidget);
    expect(find.text('Trực tuyến • Hỗ trợ 24/7'), findsOneWidget);

    // Verify initial greeting message is present
    expect(find.textContaining('Tôi là Trợ lý AI Logistics của GoShip'), findsOneWidget);

    // Verify quick prompt chips are present
    expect(find.text('Bảng giá cước tính như thế nào?'), findsOneWidget);
  });

  testWidgets('Sending a user message receives AI response in bottom sheet', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: LogisticsChatBottomSheet(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Find input field and enter text
    final inputFinder = find.byType(TextField);
    expect(inputFinder, findsOneWidget);

    await tester.enterText(inputFinder, 'Bảng giá cước tính thế nào?');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify user message is displayed
    expect(find.text('Bảng giá cước tính thế nào?'), findsOneWidget);

    // Verify AI response is displayed
    expect(find.textContaining('Cách tính cước vận chuyển tại GoShip'), findsOneWidget);
  });

  testWidgets('Tapping quick question chip submits the question', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: LogisticsChatBottomSheet(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Tap quick chip
    final chipFinder = find.text('Nên chọn xe Van hay xe Bán tải?');
    expect(chipFinder, findsOneWidget);
    await tester.tap(chipFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify response contains vehicle advice
    expect(find.textContaining('Tư vấn chọn loại xe phù hợp nhu cầu'), findsOneWidget);
  });
}
