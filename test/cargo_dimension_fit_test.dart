import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/theme/app_theme.dart';
import 'package:goship_app/features/customer/order/models/order_draft_model.dart';
import 'package:goship_app/features/customer/order/presentation/steps/step2_package_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CargoFitResult Unit Tests', () {
    test('fits within vehicle dimensions', () {
      final result = CargoFitResult.analyze(
        vehicle: OrderVehicleType.motorbike, // 1.5m x 1.2m x 0.9m
        length: 1.0,
        width: 0.8,
        height: 0.6,
      );

      expect(result.fits, isTrue);
      expect(result.issues, isEmpty);
      expect(result.message, contains('vừa vặn'));
    });

    test('detects width exceeded (user scenario: ngang 2.5m xe 1.8m)', () {
      // User case: cargo width 2.5m vs truck width 1.8m
      final result = CargoFitResult.analyze(
        vehicle: OrderVehicleType.truck, // 3.5m x 1.8m x 1.8m
        length: 2.0,
        width: 2.5,
        height: 1.5,
      );

      expect(result.fits, isFalse);
      expect(result.widthExceeded, isTrue);
      expect(result.issues.any((i) => i.contains('Chiều ngang hàng (2.5m) vượt quá')), isTrue);
      // Container has bedWidth 2.4m and bedLength 6.0m, or can fit rotated
      expect(result.suggestedVehicle, equals(OrderVehicleType.container));
    });

    test('detects length exceeded and suggests larger vehicle', () {
      final result = CargoFitResult.analyze(
        vehicle: OrderVehicleType.van, // 2.1m x 1.3m x 1.3m
        length: 3.0,
        width: 1.0,
        height: 1.0,
      );

      expect(result.fits, isFalse);
      expect(result.lengthExceeded, isTrue);
      expect(result.suggestedVehicle, equals(OrderVehicleType.truck));
    });

    test('detects volume exceeded', () {
      // Motorbike max volume 1.6 m3
      final result = CargoFitResult.analyze(
        vehicle: OrderVehicleType.motorbike,
        length: 1.4,
        width: 1.1,
        height: 0.8,
        // cargoVolume = 1.4 * 1.1 * 0.8 = 1.232 -> within 1.6 m3
      );
      expect(result.fits, isTrue);

      final resultOver = CargoFitResult.analyze(
        vehicle: OrderVehicleType.motorbike,
        length: 1.5,
        width: 1.2,
        height: 1.0, // Volume = 1.8 > 1.6
      );
      expect(resultOver.fits, isFalse);
      expect(resultOver.issues.any((i) => i.contains('vượt quá dung tích')), isTrue);
    });
  });

  group('Step2PackageScreen Dimension & Photo Layout Tests', () {
    testWidgets('renders photo section under category and shows dimension analysis', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draft = OrderDraftModel(
        vehicleType: OrderVehicleType.motorbike,
        packageCategory: 'Hàng tiêu chuẩn / Thùng carton',
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

      // 1. Verify photo upload section is rendered
      expect(find.text('Hình ảnh kiện hàng (Tùy chọn)'), findsOneWidget);
      expect(find.text('Chụp ảnh trực tiếp hoặc chọn từ thư viện'), findsOneWidget);

      // 2. Verify dimension section & inputs
      expect(find.text('Kích thước kiện hàng & Kiểm tra xe'), findsOneWidget);
      expect(find.text('Dài (m)'), findsOneWidget);
      expect(find.text('Rộng / Ngang (m)'), findsOneWidget);
      expect(find.text('Cao (m)'), findsOneWidget);

      // 3. Verify preset chips
      final presetChip = find.text('Hàng ngang 2.5m (2.0×2.5m)');
      expect(presetChip, findsOneWidget);
      expect(find.text('Sofa 3 chỗ (2.2×0.9m)'), findsOneWidget);

      // 4. Tap the 2.5m preset chip (simulating user case: hàng ngang 2.5m)
      await tester.tap(presetChip);
      await tester.pumpAndSettle();

      // 5. Verify warning appears because motorbike bed is only 1.5 x 1.2m
      expect(find.textContaining('Cảnh báo: Kiện hàng quá khổ xe'), findsOneWidget);
      expect(find.textContaining('Chiều ngang hàng (2.5m) vượt quá chiều rộng thùng xe'), findsOneWidget);

      // 6. Verify suggestion to switch vehicle is rendered
      expect(find.textContaining('Gợi ý xe phù hợp'), findsOneWidget);

      // 7. Tap switch vehicle button
      final switchBtn = find.widgetWithText(ElevatedButton, 'Đổi sang Container');
      expect(switchBtn, findsOneWidget);
      await tester.tap(switchBtn);
      await tester.pumpAndSettle();

      // 8. Verify vehicle switched in draft and fit analysis is updated
      expect(draft.vehicleType, equals(OrderVehicleType.container));
      expect(find.textContaining('Vừa vặn với thùng xe Container!'), findsOneWidget);
    });

    testWidgets('typing freeform description parses dimensions automatically', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draft = OrderDraftModel(
        vehicleType: OrderVehicleType.truck,
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

      // Enter text into description field: "hàng ngang 2.5m dài 2.0m cao 1.0m"
      final descField = find.widgetWithText(TextField, 'Mô tả kích thước (VD: hàng ngang 2.5m, dài 2m, sofa...)');
      expect(descField, findsOneWidget);

      await tester.enterText(descField, 'hàng ngang 2.5m dài 2.0m cao 1.0m');
      await tester.pumpAndSettle();

      // Check that width is 2.5 and length is 2.0
      expect(find.text('2.5'), findsOneWidget);
      expect(find.text('2.0'), findsOneWidget);

      // Check that truck (1.8m width) triggers warning
      expect(find.textContaining('Cảnh báo: Kiện hàng quá khổ xe Xe tải!'), findsOneWidget);
      expect(find.textContaining('Chiều ngang hàng (2.5m) vượt quá chiều rộng thùng xe (1.8m)'), findsOneWidget);
    });
  });
}
