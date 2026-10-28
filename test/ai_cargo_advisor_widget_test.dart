import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/services/ai_cargo_advisor_service.dart';
import 'package:goship_app/core/theme/app_theme.dart';
import 'package:goship_app/features/customer/order/models/order_draft_model.dart';
import 'package:goship_app/features/customer/order/presentation/steps/step2_package_screen.dart';
import 'package:goship_app/features/customer/order/presentation/widgets/ai_cargo_advisor_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiCargoAdvisorWidget Tests', () {
    testWidgets('renders preset chips, analyzes cargo and triggers callback on apply', (WidgetTester tester) async {
      CargoRecommendation? appliedRec;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiCargoAdvisorWidget(
                onApplyRecommendation: (rec) {
                  appliedRec = rec;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify header & preset chips rendered
      expect(find.text('AI Trợ lý Chọn xe & Hàng hóa'), findsOneWidget);
      expect(find.text('📦 Dọn phòng trọ'), findsOneWidget);
      expect(find.text('🛋️ Chuyển căn hộ 1PN'), findsOneWidget);
      expect(find.text('AI Phân tích & Gợi ý xe'), findsOneWidget);

      // 2. Tap preset chip "📦 Dọn phòng trọ"
      await tester.tap(find.text('📦 Dọn phòng trọ'));
      await tester.pumpAndSettle();

      // Verify text field contains student room description
      expect(find.textContaining('1 tủ lạnh đứng 180L'), findsOneWidget);

      // 3. Tap analyze button
      await tester.tap(find.text('AI Phân tích & Gợi ý xe'));
      await tester.pumpAndSettle();

      // 4. Verify recommendation card displays results
      expect(find.text('Khuyên dùng'), findsOneWidget);
      expect(find.text('Ước tính tải'), findsOneWidget);
      expect(find.text('Thể tích ước tính'), findsOneWidget);
      expect(find.text('Cần chở đứng (Tủ lạnh)'), findsOneWidget);
      expect(find.text('Sơ đồ xếp thùng xe thông minh'), findsOneWidget);
      expect(find.text('Chuẩn LIFO'), findsOneWidget);
      expect(find.text('Áp dụng đề xuất này vào đơn'), findsOneWidget);

      // 5. Tap "Áp dụng đề xuất này vào đơn"
      final applyButton = find.text('Áp dụng đề xuất này vào đơn');
      await tester.ensureVisible(applyButton);
      await tester.pumpAndSettle();
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(appliedRec, isNotNull);
      expect(appliedRec!.requiresStanding, isTrue);
      expect(appliedRec!.estimatedWeightKg, greaterThanOrEqualTo(100));
    });

    testWidgets('integrates with Step2PackageScreen and updates draft vehicleType and notes on apply', (WidgetTester tester) async {
      final draft = OrderDraftModel(
        pickupAddress: 'Vinhomes Central Park',
        dropoffAddresses: ['25 Điện Biên Phủ, Quận 3'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Step2PackageScreen(
            draft: draft,
            onNext: () {},
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify AI Advisor widget appears at top of Step 2
      expect(find.text('AI Trợ lý Chọn xe & Hàng hóa'), findsOneWidget);

      // 2. Select sofa/apartment preset
      await tester.tap(find.text('🛋️ Chuyển căn hộ 1PN'));
      await tester.pumpAndSettle();

      // 3. Tap AI analyze
      await tester.tap(find.text('AI Phân tích & Gợi ý xe'));
      await tester.pumpAndSettle();

      // 4. Verify recommended truck for large furniture
      expect(find.text('Xe tải'), findsAtLeastNWidgets(1));

      // 5. Tap apply recommendation
      final applyButton = find.text('Áp dụng đề xuất này vào đơn');
      await tester.ensureVisible(applyButton);
      await tester.pumpAndSettle();
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      // 6. Verify draft state updated
      expect(draft.vehicleType, OrderVehicleType.truck);
      expect(draft.packageCategory, 'Nội thất / Hàng gia dụng');
      expect(draft.weightCategory, '100-500kg');
      expect(find.textContaining('Đã chọn Xe tải & áp dụng đề xuất từ AI!'), findsOneWidget);
    });

    testWidgets('renders header cleanly without third-party Gemini AI badge and uses internal system API key', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AiCargoAdvisorWidget(
                onApplyRecommendation: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Gemini AI brand badge is removed
      expect(find.text('Gemini AI'), findsNothing);
      expect(find.text('AI Trợ lý Chọn xe & Hàng hóa'), findsOneWidget);
      expect(find.byTooltip('Cài đặt AI'), findsNothing); // No confusing user-facing API key button

      // Verify AiConfig can provide system API key
      AiConfig.systemApiKey = 'test_mock_api_key_123';
      final resolvedKey = await AiConfig.getApiKey();
      expect(resolvedKey, 'test_mock_api_key_123');
      AiConfig.systemApiKey = ''; // reset
    });
  });
}
