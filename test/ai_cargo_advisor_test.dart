import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/services/ai_cargo_advisor_service.dart';
import 'package:goship_app/features/customer/order/models/order_draft_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AiCargoAdvisorService Tests', () {
    test('Student room moving scenario recommends Van or appropriate vehicle with standing fridge', () async {
      final desc = 'Tôi cần chuyển đồ phòng trọ gồm: 1 tủ lạnh 180L, 1 máy giặt, 1 đệm gấp và 4 thùng carton';
      final rec = await AiCargoAdvisorService.analyzeCargo(desc);

      expect(rec.vehicleType, anyOf(OrderVehicleType.van, OrderVehicleType.truck));
      expect(rec.estimatedWeightKg, greaterThanOrEqualTo(100));
      expect(rec.estimatedVolumeM3, greaterThanOrEqualTo(1.5));
      expect(rec.requiresStanding, isTrue); // Tủ lạnh cần chở đứng
      expect(rec.reasoning.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('Large furniture moving scenario with 2m+ sofa and wardrobe recommends Truck', () async {
      final desc = 'Cần dọn căn hộ: 1 bộ sofa góc chữ L dài 2m2, 1 tủ quần áo gỗ 3 cánh, 1 giường 1m8';
      final rec = await AiCargoAdvisorService.analyzeCargo(desc);

      expect(rec.vehicleType, OrderVehicleType.truck);
      expect(rec.estimatedWeightKg, greaterThanOrEqualTo(200));
      expect(rec.estimatedVolumeM3, greaterThanOrEqualTo(3.5));
      expect(rec.packageCategory, 'Nội thất / Hàng gia dụng');
      expect(rec.reasoning.isNotEmpty, isTrue);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('Heavy industrial or safe equipment scenario flags requiresTailgate', () async {
      final desc = 'Chuyển 1 két sắt ngân hàng 350kg và máy phát điện cơ khí';
      final rec = await AiCargoAdvisorService.analyzeCargo(desc);

      expect(rec.requiresTailgate, isTrue);
      expect(rec.packageCategory, 'Vật liệu xây dựng / Cơ khí');
      expect(rec.estimatedWeightKg, greaterThanOrEqualTo(300));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('Fragile electronics scenario flags isFragile and sets fragile category', () async {
      final desc = 'Giao 1 tivi OLED 65 inch và 2 gương kính phòng tắm dễ vỡ';
      final rec = await AiCargoAdvisorService.analyzeCargo(desc);

      expect(rec.isFragile, isTrue);
      expect(rec.packageCategory, 'Hàng dễ vỡ / Điện tử');
      expect(rec.driverNoteAdvice.isNotEmpty, isTrue);
      expect(rec.stowagePlan, isNotNull);
      expect(rec.recommendedSupplies, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('Empty input returns fallback safely without throwing exception', () async {
      final rec = await AiCargoAdvisorService.analyzeCargo('');
      expect(rec.vehicleType, isNotNull);
      expect(rec.reasoning, isNotEmpty);
      expect(rec.stowagePlan, isNotNull);
      expect(rec.recommendedSupplies, isNotEmpty);
    });

    test('Multi-drop scenario generates LIFO stowage plan with distinct doorSide and cabinSide', () async {
      final desc = 'Chuyển hàng 2 điểm: Điểm 1 giao 4 thùng carton; Điểm 2 giao 1 tủ lạnh đứng và 1 máy giặt';
      final rec = await AiCargoAdvisorService.analyzeCargo(desc, dropoffCount: 2);

      expect(rec.stowagePlan, isNotNull);
      expect(rec.stowagePlan.doorSide, isNotEmpty);
      expect(rec.stowagePlan.cabinSide, isNotEmpty);
      expect(rec.stowagePlan.stackingAdvice, isNotEmpty);
      expect(rec.recommendedSupplies, isNotEmpty);
      expect(rec.estimatedHandlingMinutes, greaterThanOrEqualTo(20));
    });
  });
}
