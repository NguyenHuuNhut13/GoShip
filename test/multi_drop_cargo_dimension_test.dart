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

  group('DropoffRecipient & Multi-Drop Cargo Dimensions Model Tests', () {
    test('DropoffRecipient dimensions calculation and serialization', () {
      final recipient = DropoffRecipient(
        name: 'Trần Văn A',
        phone: '0901234567',
        note: 'Giao giờ hành chính',
        itemsDescription: 'Sofa góc chữ L 3 chỗ',
        lengthM: 2.2,
        widthM: 0.9,
        heightM: 0.8,
      );

      expect(recipient.hasDimensions, isTrue);
      expect(recipient.volumeM3, closeTo(2.2 * 0.9 * 0.8, 0.001));
      expect(recipient.dimensionSummary, equals('2.2m x 0.9m x 0.8m'));

      final json = recipient.toJson();
      expect(json['itemsDescription'], equals('Sofa góc chữ L 3 chỗ'));
      expect(json['lengthM'], equals(2.2));
      expect(json['widthM'], equals(0.9));
      expect(json['heightM'], equals(0.8));

      final fromJson = DropoffRecipient.fromJson(json);
      expect(fromJson.name, equals('Trần Văn A'));
      expect(fromJson.itemsDescription, equals('Sofa góc chữ L 3 chỗ'));
      expect(fromJson.lengthM, equals(2.2));
      expect(fromJson.widthM, equals(0.9));
      expect(fromJson.heightM, equals(0.8));

      final cloned = recipient.clone();
      expect(cloned.itemsDescription, equals(recipient.itemsDescription));
      expect(cloned.volumeM3, equals(recipient.volumeM3));
    });

    test('CargoFitResult.analyzeMultiDrop fits comfortably in Truck', () {
      final recipients = [
        DropoffRecipient(
          name: 'Điểm 1',
          itemsDescription: 'Bàn họp',
          lengthM: 2.0,
          widthM: 1.0,
          heightM: 0.75,
        ),
        DropoffRecipient(
          name: 'Điểm 2',
          itemsDescription: 'Tủ tài liệu',
          lengthM: 1.2,
          widthM: 0.5,
          heightM: 1.6,
        ),
      ];

      final result = CargoFitResult.analyzeMultiDrop(
        vehicle: OrderVehicleType.truck, // 3.5m x 1.8m x 1.8m, 11.3m3
        recipients: recipients,
        dropoffAddresses: ['208 Nguyễn Hữu Cảnh', '10 Mai Chí Thọ'],
      );

      expect(result.fits, isTrue);
      expect(result.issues.isEmpty, isTrue);
      expect(result.message, contains('vừa vặn'));
    });

    test('CargoFitResult.analyzeMultiDrop detects oversized item and suggests larger vehicle', () {
      final recipients = [
        DropoffRecipient(
          name: 'Điểm 1',
          itemsDescription: 'Hàng ngang quá khổ 2.5m',
          lengthM: 2.0,
          widthM: 2.5, // 2.5m exceeds Van bed width 1.3m and bed length 2.1m
          heightM: 1.0,
        ),
        DropoffRecipient(
          name: 'Điểm 2',
          itemsDescription: 'Thùng carton',
          lengthM: 0.6,
          widthM: 0.4,
          heightM: 0.4,
        ),
      ];

      final result = CargoFitResult.analyzeMultiDrop(
        vehicle: OrderVehicleType.van, // 2.1m x 1.3m x 1.3m, 3.5m3
        recipients: recipients,
        dropoffAddresses: ['Điểm 1', 'Điểm 2'],
      );

      expect(result.fits, isFalse);
      expect(result.issues.any((msg) => msg.contains('Chiều ngang')), isTrue);
      expect(result.suggestedVehicle, anyOf(OrderVehicleType.truck, OrderVehicleType.container));
    });

    test('OrderDraftModel multi-drop volume, max dimensions and LIFO summary', () {
      final draft = OrderDraftModel(
        dropoffAddresses: [
          'Vinhomes Central Park, Bình Thạnh',
          'Estella Heights, Quận 2',
          'Thảo Điền Pearl, Quận 2',
        ],
        dropoffRecipients: [
          DropoffRecipient(
            itemsDescription: 'Sofa 3 chỗ',
            lengthM: 2.2,
            widthM: 0.9,
            heightM: 0.8,
          ),
          DropoffRecipient(
            itemsDescription: 'Tủ lạnh 2 cánh',
            lengthM: 0.8,
            widthM: 0.7,
            heightM: 1.8,
          ),
          DropoffRecipient(
            itemsDescription: 'Máy giặt cửa ngang',
            lengthM: 0.6,
            widthM: 0.6,
            heightM: 0.85,
          ),
        ],
      );

      expect(draft.totalCargoVolumeM3, greaterThan(2.0));
      expect(draft.maxCargoLengthM, equals(2.2));
      expect(draft.maxCargoWidthM, equals(0.9));
      expect(draft.maxCargoHeightM, equals(1.8));

      final lifoSummary = draft.generateLifoStowageSummary();
      expect(lifoSummary, contains('Cửa sau (dỡ đầu tiên tại Điểm 1): Sofa 3 chỗ'));
      expect(lifoSummary, contains('Giữa thùng xe (dỡ tại Điểm 2): Tủ lạnh 2 cánh'));
      expect(lifoSummary, contains('Sát cabin (dỡ sau cùng tại Điểm 3): Máy giặt cửa ngang'));
    });
  });

  group('Step2PackageScreen Multi-Drop Cargo UI Widget Tests', () {
    testWidgets('renders multi-drop tabs and allows assigning items per destination', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draft = OrderDraftModel(
        pickupAddress: 'Kho Tân Cảng, Bình Thạnh',
        dropoffAddresses: [
          'Landmark 81, Bình Thạnh',
          'Estella Heights, TP Thủ Đức',
        ],
        vehicleType: OrderVehicleType.truck,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Step2PackageScreen(
              draft: draft,
              onNext: () {},
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // 1. Verify multi-drop section header exists
      expect(find.text('Kích thước & Phân bổ hàng theo điểm giao'), findsOneWidget);

      // 2. Verify tabs for Điểm 1 and Điểm 2 are rendered
      expect(find.text('Landmark 81'), findsOneWidget);
      expect(find.text('Estella Heights'), findsOneWidget);

      // 3. Verify LIFO diagram is displayed
      expect(find.text('Sơ đồ xếp dỡ hàng LIFO theo từng điểm'), findsOneWidget);
      expect(find.text('Cửa sau xe (Dỡ đầu tiên): Điểm 1'), findsOneWidget);
      expect(find.text('Sát cabin xe (Dỡ sau cùng): Điểm 2'), findsOneWidget);

      // 4. Test tapping "Lưu sơ đồ LIFO vào lời dặn bác tài"
      final lifoButton = find.text('Lưu sơ đồ LIFO vào lời dặn bác tài');
      expect(lifoButton, findsOneWidget);
      await tester.tap(lifoButton);
      await tester.pump();

      expect(draft.driverNote, contains('[Sơ đồ xếp xe LIFO]'));
      expect(find.text('Đã cập nhật sơ đồ xếp dỡ LIFO vào lời dặn bác tài!'), findsOneWidget);
    });
  });
}
