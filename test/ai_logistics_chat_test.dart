import 'package:flutter_test/flutter_test.dart';
import 'package:goship_app/core/services/ai_logistics_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiLogisticsChatService.forceOfflineMode = true;
  });

  tearDown(() {
    AiLogisticsChatService.forceOfflineMode = false;
  });

  group('AiLogisticsChatService Tests', () {
    test('Empty user message returns helpful prompt', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: '',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Bạn có thể đặt câu hỏi'));
    });

    test('Pricing query returns accurate tariff breakdown', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Bảng giá cước tính như thế nào vậy shop?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Cách tính cước vận chuyển tại GoShip'));
      expect(reply.text, contains('4km đầu'));
    });

    test('Vehicle comparison query answers Van vs Pickup vs Truck', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Nên chọn xe Van hay xe Bán tải để chuyển đồ phòng trọ?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Xe Van'));
      expect(reply.text, contains('Xe Bán tải'));
      expect(reply.text, contains('phòng trọ'));
    });

    test('Porter inquiry details loading and handling services', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Có hỗ trợ người bốc xếp lên lầu không?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Bốc xếp'));
      expect(reply.text, contains('thang máy hoặc thang bộ'));
    });

    test('Heavy equipment inquiry explains tailgate lift truck', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Tôi muốn chở két sắt nặng 300kg có bửng nâng không?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Bửng Nâng Thủy Lực'));
      expect(reply.text, contains('sức nâng'));
    });

    test('Fragile cargo and fridge inquiry provides safety instructions', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Chở tủ lạnh và tivi màn hình dễ vỡ có cần lưu ý gì?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Tủ lạnh'));
      expect(reply.text, contains('chở đứng'));
      expect(reply.text, contains('xốp bóng khí'));
    });

    test('Prohibited goods inquiry lists restricted items', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Những mặt hàng nào bị cấm vận chuyển?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('hàng cấm vận chuyển'));
      expect(reply.text, contains('chất dễ cháy nổ'));
    });

    test('Insurance and claims inquiry explains 100% compensation policy', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Nếu hàng bị rơi vỡ thì công ty bồi thường thế nào?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('Bảo hiểm & Đền bù'));
      expect(reply.text, contains('bồi thường 100%'));
    });

    test('Delivery time query explains 24/7 hours and no-truck-ban for Vans', () async {
      final reply = await AiLogisticsChatService.sendMessage(
        userMessage: 'Giao hàng mất bao lâu và xe có bị cấm giờ không?',
        history: [],
      );

      expect(reply.isUser, isFalse);
      expect(reply.text, contains('KHÔNG BỊ CẤM GIỜ'));
      expect(reply.text, contains('Xe Van & Xe Bán tải'));
    });
  });
}
