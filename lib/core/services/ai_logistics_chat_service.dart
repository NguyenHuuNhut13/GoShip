import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_cargo_advisor_service.dart';

/// Đại diện cho một tin nhắn trong cuộc trò chuyện Logistics
class LogisticsChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> quickActions;

  LogisticsChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.quickActions = const [],
  });

  factory LogisticsChatMessage.user(String text) {
    return LogisticsChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );
  }

  factory LogisticsChatMessage.bot(String text, {List<String> quickActions = const []}) {
    return LogisticsChatMessage(
      id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      isUser: false,
      timestamp: DateTime.now(),
      quickActions: quickActions,
    );
  }
}

/// Dịch vụ Trợ lý AI Chuyên trách Tư vấn & Giải đáp Thắc mắc Logistics của GoShip
class AiLogisticsChatService {
  /// Cờ ép buộc chế độ ngoại tuyến (dành cho kiểm thử hoặc môi trường không có mạng)
  static bool forceOfflineMode = false;

  /// Tra cứu trực tiếp từ Bộ tri thức logistics ngoại tuyến
  static String getOfflineKnowledge(String query) => _offlineLogisticsKnowledgeEngine(query);

  /// Danh sách câu hỏi gợi ý nhanh ban đầu
  static const List<String> defaultQuickPrompts = [
    'Bảng giá cước tính như thế nào?',
    'Nên chọn xe Van hay xe Bán tải?',
    'Quy định hàng cấm & hàng dễ vỡ?',
    'Đồ nặng có dịch vụ bửng nâng không?',
    'Chính sách đền bù khi xảy ra sự cố?',
  ];

  /// Gửi câu hỏi của khách hàng tới AI Bot và nhận phản hồi
  static Future<LogisticsChatMessage> sendMessage({
    required String userMessage,
    required List<LogisticsChatMessage> history,
  }) async {
    final cleanInput = userMessage.trim();
    if (cleanInput.isEmpty) {
      return LogisticsChatMessage.bot('Bạn có thể đặt câu hỏi về chọn xe, giá cước hoặc quy định giao hàng nhé!');
    }

    final apiKey = await AiConfig.getApiKey();
    final primaryModel = await AiConfig.getModelName();

    // 1. Thử gọi Google Gemini Cloud AI nếu có API Key và không ép buộc offline
    if (!forceOfflineMode && apiKey.isNotEmpty) {
      final modelsToTry = [
        primaryModel,
        ...AiConfig.availableModels.where((m) => m != primaryModel),
      ];

      for (final model in modelsToTry) {
        try {
          final reply = await _callGeminiApi(
            userMessage: cleanInput,
            history: history,
            apiKey: apiKey,
            modelName: model,
          );
          if (reply != null && reply.isNotEmpty) {
            return LogisticsChatMessage.bot(reply);
          }
        } catch (_) {
          // Thử tiếp model tiếp theo nếu gặp lỗi
          continue;
        }
      }
    }

    // 2. Kích hoạt Bộ Tri thức Nghiệp vụ Ngoại tuyến (Offline Knowledge Engine)
    final offlineResponse = _offlineLogisticsKnowledgeEngine(cleanInput);
    return LogisticsChatMessage.bot(offlineResponse);
  }

  /// Gọi Google Gemini REST API với ngữ cảnh chuyên gia Logistics
  static Future<String?> _callGeminiApi({
    required String userMessage,
    required List<LogisticsChatMessage> history,
    required String apiKey,
    required String modelName,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    const systemInstruction = '''
Bạn là "GoShip AI Assistant" - Chuyên viên tư vấn điều phối và giải đáp nghiệp vụ Logistics hàng đầu của nền tảng vận tải GoShip tại Việt Nam.

Nhiệm vụ của bạn là giải đáp mọi câu hỏi của khách hàng về vận chuyển hàng hóa, chọn xe, cước phí và chính sách vận hành với phong thái chuyên nghiệp, tận tâm, súc tích và dễ hiểu:

1. ĐỘI XE GOSHIP:
- Xe Bán tải (Pickup): Tải trọng max 500kg, thùng ~2m³, dài ~1.5m. Thích hợp đồ nhỏ gọn, vài thùng carton, tài liệu, bàn ghế mini.
- Xe Van: Tải trọng max 1000kg (1 tấn), thùng ~3.5m³, dài ~2.1m, cao ~1.3m. Rất phù hợp dọn phòng trọ sinh viên, chở tủ lạnh nhỏ/vừa, máy giặt, đệm gấp, sofa dưới 2m. Không bị cấm giờ trong nội thành.
- Xe Tải (1.5T - 2.5T): Tải trọng max 2500kg, thùng ~10m³, dài ~3.5m, cao ~1.8m. Chở được sofa lớn >2m, tủ lạnh 2 cánh/side-by-side bắt buộc chở đứng, giường tủ tháo lắp, dọn nhà nguyên căn.
- Xe Container: Tải trọng >10 tấn, thể tích >15m³, phục vụ hàng công nghiệp nặng, máy móc cơ khí, dọn kho xưởng quy mô lớn.

2. DỊCH VỤ BỔ TRỢ & TIỆN ÍCH:
- Dịch vụ bốc xếp: Hỗ trợ tài xế bốc xếp hoặc thêm người bốc xếp theo lầu/thang máy/thang bộ.
- Bửng nâng thủy lực: Dành riêng cho xe tải chở hàng siêu nặng (>100kg), két sắt, máy móc, tủ server không thể khuân vác bằng tay.
- Bọc lót an toàn: Màng bọc PE chống xước, chăn bảo vệ nội thất bọc sofa/gỗ, xốp bóng khí (bubble wrap) cho hàng dễ vỡ.
- Giao đa điểm (Multi-drop LIFO): Giao nhiều điểm theo quy tắc Vào sau - Ra trước (hàng điểm 1 xếp ngoài cửa thùng dỡ trước, hàng điểm cuối đặt sát cabin).

3. BẢNG GIÁ & PHÍ DỊCH VỤ:
- Cước được tính tự động theo loại xe + quãng đường thực tế (tính từ 4km đầu mở cửa, các km tiếp theo tính theo đơn giá lũy tiến cạnh tranh).
- Phụ phí minh bạch: Phí bốc xếp theo tầng, phí bửng nâng, phí điểm dừng giao thêm (30.000đ - 50.000đ/điểm).

4. QUY ĐỊNH HÀNG HÓA & AN TOÀN:
- Hàng cấm vận chuyển: Chất nổ, pháo, bình gas mini rò rỉ, hóa chất độc hại, vũ khí, ma túy, động vật hoang dã, hàng cấm theo pháp luật Việt Nam.
- Hàng đặc thù & dễ vỡ: Tủ lạnh bắt buộc vận chuyển ĐỨNG để không trào dầu block máy; TV/màn hình/kính phải bọc bóng khí và chèn xốp cố định.

5. BẢO HIỂM & BỒI THƯỜNG SỰ CỐ:
- Cam kết đền bù 100% giá trị thiệt hại thực tế nếu phát sinh lỗi hư hao, đổ vỡ do quá trình vận chuyển của tài xế khi có hình ảnh check-in 2 đầu giao nhận.
- Đội ngũ CSKH hỗ trợ xử lý khiếu nại nhanh chóng trong vòng 24 giờ qua Hotline 1900 6868.

QUY TẮC TRÌNH BÀY (BẮT BUỘC):
- Tuyệt đối KHÔNG dùng ký tự thăng ### hoặc ## làm tiêu đề.
- KHÔNG dùng cặp dấu sao ** bao quanh từ để in đậm (tránh lộ ký tự thô ra giao diện).
- Trình bày câu trả lời rõ ràng bằng các gạch đầu dòng • hoặc số thứ tự 1., 2., 3.
- Trả lời bằng tiếng Việt tự nhiên, gãy gọn, thân thiện và đưa ra lời khuyên thực tế nhất cho khách hàng!
''';

    // Tạo danh sách contents từ lịch sử hội thoại gần nhất (tối đa 6 tin nhắn để tiết kiệm token)
    final recentHistory = history.length > 6 ? history.sublist(history.length - 6) : history;
    final contents = <Map<String, dynamic>>[];

    for (final msg in recentHistory) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ],
      });
    }

    // Thêm tin nhắn hiện tại của user
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final requestBody = {
      'system_instruction': {
        'parts': [
          {'text': systemInstruction}
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 800,
      },
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final candidates = data['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text']?.toString();
        }
      }
    }

    return null;
  }

  /// Bộ Tri thức Nghiệp vụ Ngoại tuyến (Offline Logistics Knowledge Engine)
  /// Đảm bảo chatbot hoạt động mượt mà 100% khi mất mạng hoặc không có API Key
  static String _offlineLogisticsKnowledgeEngine(String query) {
    final q = query.toLowerCase();

    // 1. Giá cước & chi phí
    if (q.contains('giá') || q.contains('cước') || q.contains('bao nhiêu tiền') || q.contains('chi phí') || q.contains('tính tiền')) {
      return '**Cách tính cước vận chuyển tại GoShip:**\n\n'
          '• **Cước mở cửa (4km đầu):**\n'
          '  - Xe Bán tải: từ 120.000đ\n'
          '  - Xe Van: từ 150.000đ\n'
          '  - Xe Tải: từ 220.000đ\n'
          '• **Các km tiếp theo:** Tính theo đơn giá lũy tiến hiển thị minh bạch khi bạn nhập địa chỉ giao nhận.\n'
          '• **Phụ phí dịch vụ kèm theo (nếu chọn):** Bốc xếp tầng trệt/lầu, bửng nâng xe tải, điểm giao thêm (+30k - 50k/điểm).\n\n'
          '*Mẹo:* Bạn có thể vào màn hình đặt đơn, nhập điểm lấy và trả hàng để hệ thống tính giá chính xác từng mét.';
    }

    // 2. Xe Van vs Xe Bán tải vs Xe Tải
    if (q.contains('van') || q.contains('bán tải') || q.contains('xe tải') || q.contains('chọn xe') || q.contains('loại xe')) {
      return '**Tư vấn chọn loại xe phù hợp nhu cầu:**\n\n'
          '1. **Xe Bán tải (Pickup - Tối đa 500kg):** Thùng xe ~1.5m dài, thích hợp đồ nhỏ gọn, tài liệu, vali, bàn ghế học sinh. Phù hợp đường hẻm nhỏ.\n'
          '2. **Xe Van (Tối đa 1000kg):** Khoang kín cao ráo, dài ~2.1m. Không bị cấm giờ nội thành. Lựa chọn số 1 cho sinh viên, chuyển phòng trọ, chở tủ lạnh 150L-200L, máy giặt, đệm xếp.\n'
          '3. **Xe Tải (1.5T - 2.5T):** Thùng dài ~3.5m, cao ~1.8m. Chở sofa dài >2m, tủ lạnh 2 cánh đứng, chuyển nhà 1-2 phòng ngủ, có hỗ trợ bửng nâng thủy lực.\n'
          '4. **Xe Container:** Phục vụ chở máy móc cơ khí công nghiệp hoặc chuyển kho xưởng nặng >10 tấn.';
    }

    // 3. Bốc xếp & Bê vác
    if (q.contains('bốc xếp') || q.contains('bốc vác') || q.contains('bê') || q.contains('khiêng') || q.contains('người bốc')) {
      return '**Dịch vụ Bốc xếp hỗ trợ:**\n\n'
          '• Khi đặt đơn tại Bước 2, bạn có thể chọn gói dịch vụ bốc xếp:\n'
          '  - **Tài xế hỗ trợ:** Thích hợp khi bạn có sẵn người phụ, tài xế sẽ hỗ trợ khuân vác lên/xuống thùng xe.\n'
          '  - **Thêm người bốc xếp:** GoShip điều phối thêm phụ xe để dọn trọn gói từ trong nhà lên xe.\n'
          '• Hỗ trợ vận chuyển theo thang máy hoặc thang bộ (vui lòng ghi rõ số tầng trong phần ghi chú).';
    }

    // 4. Bửng nâng thủy lực
    if (q.contains('bửng') || q.contains('nâng') || q.contains('thủy lực') || q.contains('nặng') || q.contains('két sắt')) {
      return '**Dịch vụ Xe Tải Bửng Nâng Thủy Lực:**\n\n'
          '• Dành riêng cho các kiện hàng quá nặng không thể bốc vác thủ công như: Két sắt, tủ điện công nghiệp, máy photocopy, máy CNC, đàn piano...\n'
          '• Bàn nâng thủy lực phía đuôi xe tải có sức nâng lên đến **500kg - 1000kg**, đảm bảo hàng lên xe an toàn tuyệt đối, không lo trầy xước hay va đập.';
    }

    // 5. Hàng dễ vỡ & đóng gói bọc lót
    if (q.contains('dễ vỡ') || q.contains('tủ lạnh') || q.contains('tivi') || q.contains('kính') || q.contains('bọc') || q.contains('đóng gói')) {
      return '**Quy định đóng gói hàng dễ vỡ & đồ điện tử:**\n\n'
          '• **Tủ lạnh:** BẮT BUỘC chở đứng và chằng buộc chắc chắn để dầu máy nén không tràn vào đường ống ga làm hỏng block máy.\n'
          '• **Tivi, Màn hình, Gương kính:** Cần được bọc màng xốp bóng khí (bubble wrap), chèn đệm xốp ở 4 góc và dựng đứng áp sát vách thùng xe.\n'
          '• **Vật tư GoShip hỗ trợ:** Bạn có thể yêu cầu màng quấn PE chống trầy xước và chăn bọc chuyên dụng trong ghi chú đơn hàng.';
    }

    // 6. Hàng cấm vận chuyển
    if (q.contains('hàng cấm') ||
        q.contains('nguy hiểm') ||
        q.contains('vũ khí') ||
        q.contains('cháy nổ') ||
        (q.contains('cấm') && !q.contains('cấm giờ') && !q.contains('cấm tải'))) {
      return '**Danh mục hàng cấm vận chuyển tại GoShip:**\n\n'
          '• Các chất dễ cháy nổ: Xăng dầu, bình gas mini, thuốc súng, pháo hoa.\n'
          '• Hàng cấm pháp luật: Vũ khí, vật liệu nổ, ma túy, chất kích thích, tài liệu phản động.\n'
          '• Động vật sống quý hiếm không có giấy kiểm dịch, gia súc gia cầm sống.\n'
          '• Tiền mặt, vàng bạc đá quý, ngoại tệ (khuyên dùng dịch vụ chuyển phát bảo mật chuyên biệt).\n'
          '*Lưu ý: Đối với xe máy, quý khách cần hút cạn xăng trước khi đưa lên xe tải.*';
    }

    // 7. Thời gian giao hàng & giờ cấm tải
    if (q.contains('thời gian') ||
        q.contains('bao lâu') ||
        q.contains('mấy giờ') ||
        q.contains('cấm giờ') ||
        q.contains('cấm tải') ||
        q.contains('giao gấp')) {
      return '**Thời gian giao hàng & Quy định giờ cấm tải:**\n\n'
          '• **Xe Van & Xe Bán tải:** Hoạt động 24/7, **KHÔNG BỊ CẤM GIỜ** trong nội thành TP.HCM và Hà Nội, giao hàng hỏa tốc bất kỳ lúc nào.\n'
          '• **Xe Tải:** Tuân thủ khung giờ cấm tải nội đô (thường cấm từ 6h00 - 9h00 sáng và 16h00 - 20h00 chiều). Nếu cần giao gấp trong giờ cấm, nên chọn Xe Van!\n'
          '• **Thời gian tài xế có mặt:** Trung bình chỉ 10 - 20 phút sau khi quý khách xác nhận đặt chuyến.';
    }

    // 8. Bảo hiểm & Đền bù sự cố
    if (q.contains('bảo hiểm') ||
        q.contains('đền bù') ||
        q.contains('bồi thường') ||
        q.contains('hư hỏng') ||
        q.contains('móp méo') ||
        q.contains('thất lạc') ||
        q.contains('mất hàng') ||
        q.contains('bị mất') ||
        (q.contains('hỏng') && !q.contains('phòng')) ||
        (q.contains('vỡ') && !q.contains('dễ vỡ'))) {
      return '**Chính sách Bảo hiểm & Đền bù của GoShip:**\n\n'
          '• **Cam kết bồi thường 100%:** Nếu hàng hóa bị hư hỏng, móp méo hoặc thất lạc do lỗi vận chuyển của tài xế đối tác.\n'
          '• **Quy trình đảm bảo:**\n'
          '  1. Tài xế chụp ảnh check-in hàng hóa lúc nhận và lúc giao hoàn tất.\n'
          '  2. Nếu phát hiện hư hao, quý khách giữ nguyên hiện trường, chụp ảnh và thông báo ngay trên app.\n'
          '  3. Bộ phận CSKH tiếp nhận và xử lý đền bù thỏa đáng trong vòng 24h làm việc.';
    }

    // 9. Hủy đơn / Đổi điểm giao
    if (q.contains('hủy') || q.contains('đổi') || q.contains('thay đổi') || q.contains('thêm điểm')) {
      return '**Chính sách Hủy đơn & Đổi điểm giao:**\n\n'
          '• **Hủy đơn:** Quý khách có thể hủy miễn phí khi tài xế chưa bắt đầu di chuyển đến điểm lấy hàng.\n'
          '• **Thêm điểm giao:** Ứng dụng hỗ trợ giao tối đa 10 điểm trả hàng (áp dụng sơ đồ xếp xe LIFO dỡ hàng cực nhanh). Mỗi điểm phát sinh thêm từ 30.000đ - 50.000đ.';
    }

    // Mặc định trả lời tổng quát
    return '**Chào bạn, mình là Trợ lý AI Logistics của GoShip!**\n\n'
        'Mình có thể hỗ trợ bạn:\n'
        '• **Tư vấn chọn loại xe** (Bán tải, Van, Xe tải bửng nâng, Container)\n'
        '• **Giải thích cách tính cước** và phụ phí bốc xếp\n'
        '• **Hướng dẫn đóng gói & bảo quản** hàng dễ vỡ, tủ lạnh\n'
        '• **Thông tin chính sách bảo hiểm**, đền bù và quy định hàng cấm\n\n'
        'Bạn muốn tìm hiểu về nội dung nào? Hãy nhắn cho mình nhé!';
  }
}
