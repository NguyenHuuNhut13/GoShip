import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/customer/order/models/order_draft_model.dart';

/// Sơ đồ bố trí & sắp xếp hàng hóa lên thùng xe theo nguyên tắc LIFO (Vào sau ra trước)
class LoadingStowagePlan {
  final String doorSide;      // Cửa sau (Giao điểm 1 / Dỡ trước / Hàng cần lấy nhanh)
  final String middleSection;  // Giữa thùng (Hàng kích thước vừa, thùng carton)
  final String cabinSide;      // Sát vách cabin (Giao điểm cuối / Dỡ sau / Hàng nặng làm trọng tâm)
  final String stackingAdvice; // Hướng dẫn phân tầng Đáy-Đỉnh & chèn lót an toàn

  LoadingStowagePlan({
    required this.doorSide,
    required this.middleSection,
    required this.cabinSide,
    required this.stackingAdvice,
  });

  factory LoadingStowagePlan.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return LoadingStowagePlan(
        doorSide: 'Kiện hàng dỡ trước (Điểm 1), đồ nhỏ gọn dễ lấy.',
        middleSection: 'Thùng carton tiêu chuẩn, vật dụng kích thước vừa.',
        cabinSide: 'Hàng nặng nhất đặt sát sàn xe tạo trọng tâm, kiện giao điểm cuối (Điểm 2).',
        stackingAdvice: 'Đồ nặng xếp đáy sàn xe, đồ nhẹ xếp trên, chèn màng xốp xung quanh.',
      );
    }
    return LoadingStowagePlan(
      doorSide: json['door_side']?.toString() ?? 'Kiện hàng dỡ trước (Điểm 1), đồ nhỏ gọn dễ lấy.',
      middleSection: json['middle_section']?.toString() ?? 'Thùng carton tiêu chuẩn, vật dụng kích thước vừa.',
      cabinSide: json['cabin_side']?.toString() ?? 'Hàng nặng nhất đặt sát sàn xe tạo trọng tâm, kiện giao điểm cuối (Điểm 2).',
      stackingAdvice: json['stacking_advice']?.toString() ?? 'Đồ nặng xếp đáy sàn xe, đồ nhẹ xếp trên, chèn màng xốp xung quanh.',
    );
  }

  Map<String, dynamic> toJson() => {
    'door_side': doorSide,
    'middle_section': middleSection,
    'cabin_side': cabinSide,
    'stacking_advice': stackingAdvice,
  };
}

/// Kết quả khuyến nghị phương tiện và thông số hàng hóa từ AI
class CargoRecommendation {
  final OrderVehicleType vehicleType;
  final String vehicleName;
  final int estimatedWeightKg;
  final double estimatedVolumeM3;
  final String packageCategory;
  final String weightCategoryChip; // '<100kg', '100-500kg', '500-1000kg', '>1000kg'
  final bool requiresTailgate;
  final bool isFragile;
  final bool requiresStanding;
  final bool requiresPorter;
  final bool hasLongDimensions;
  final String reasoning;
  final String driverNoteAdvice;
  final bool isFromCloudAi;
  final String modelUsed;

  // Mở rộng thông minh: Sơ đồ xếp hàng LIFO & Vật tư bọc lót
  final LoadingStowagePlan stowagePlan;
  final List<String> recommendedSupplies;
  final int estimatedHandlingMinutes;

  CargoRecommendation({
    required this.vehicleType,
    required this.vehicleName,
    required this.estimatedWeightKg,
    required this.estimatedVolumeM3,
    required this.packageCategory,
    required this.weightCategoryChip,
    required this.requiresTailgate,
    required this.isFragile,
    required this.requiresStanding,
    this.requiresPorter = false,
    this.hasLongDimensions = false,
    required this.reasoning,
    required this.driverNoteAdvice,
    required this.isFromCloudAi,
    required this.modelUsed,
    required this.stowagePlan,
    this.recommendedSupplies = const [],
    this.estimatedHandlingMinutes = 20,
  });

  factory CargoRecommendation.fromJson(
    Map<String, dynamic> json, {
    required bool isFromCloudAi,
    required String modelUsed,
  }) {
    final vehicleCode = json['recommended_vehicle']?.toString().toLowerCase() ?? 'truck';
    OrderVehicleType matchedVehicle;
    switch (vehicleCode) {
      case 'motorbike':
      case 'pickup':
        matchedVehicle = OrderVehicleType.motorbike;
        break;
      case 'van':
        matchedVehicle = OrderVehicleType.van;
        break;
      case 'container':
        matchedVehicle = OrderVehicleType.container;
        break;
      case 'truck':
      default:
        matchedVehicle = OrderVehicleType.truck;
        break;
    }

    final weight = (json['estimated_weight_kg'] as num?)?.toInt() ?? 200;
    final tailgate = json['requires_tailgate'] == true;

    final rawChip = json['weight_category_chip']?.toString();
    String resolvedChip;
    if (rawChip != null && ['<100kg', '100-500kg', '500-1000kg', '>1000kg'].contains(rawChip)) {
      resolvedChip = rawChip;
    } else {
      if (weight < 100) {
        resolvedChip = '<100kg';
      } else if (weight <= 500) {
        resolvedChip = '100-500kg';
      } else if (weight <= 1000) {
        resolvedChip = '500-1000kg';
      } else {
        resolvedChip = '>1000kg';
      }
    }

    final rawPlan = json['loading_plan'] as Map<String, dynamic>?;
    final stowage = LoadingStowagePlan.fromJson(rawPlan);

    final rawSupplies = json['recommended_supplies'];
    List<String> supplies = [];
    if (rawSupplies is List) {
      supplies = rawSupplies.map((s) => s.toString()).toList();
    }
    if (supplies.isEmpty) {
      supplies = ['Màng quấn PE chống trầy', 'Dây chằng hàng tăng đơ'];
    }

    final handlingMinutes = (json['estimated_handling_minutes'] as num?)?.toInt() ?? 20;

    return CargoRecommendation(
      vehicleType: matchedVehicle,
      vehicleName: matchedVehicle.name,
      estimatedWeightKg: weight,
      estimatedVolumeM3: (json['estimated_volume_m3'] as num?)?.toDouble() ?? 2.0,
      packageCategory: json['package_category']?.toString() ?? 'Nội thất / Hàng gia dụng',
      weightCategoryChip: resolvedChip,
      requiresTailgate: tailgate,
      isFragile: json['is_fragile'] == true,
      requiresStanding: json['requires_standing'] == true,
      requiresPorter: json['requires_porter'] == true || weight > 120 || tailgate,
      hasLongDimensions: json['has_long_dimensions'] == true,
      reasoning: json['reasoning']?.toString() ??
          'Dựa trên danh sách đồ đạc, phương tiện ${matchedVehicle.name} đáp ứng tốt nhất về tải trọng và thể tích.',
      driverNoteAdvice: json['driver_note_advice']?.toString() ?? '',
      isFromCloudAi: isFromCloudAi,
      modelUsed: modelUsed,
      stowagePlan: stowage,
      recommendedSupplies: supplies,
      estimatedHandlingMinutes: handlingMinutes,
    );
  }
}

/// Quản lý cấu hình mô hình AI và API Key linh hoạt
class AiConfig {
  static const String keyGeminiApiKey = 'config_gemini_api_key';
  static const String keySelectedModel = 'config_gemini_model_name';

  static const String defaultModel = 'gemini-3.6-flash';
  static const List<String> availableModels = [
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-flash-latest',
  ];

  /// API Key hệ thống do GoShip cài đặt sẵn phía mã nguồn/hệ thống.
  /// Khuyến nghị: Truyền qua --dart-define=GEMINI_API_KEY=... khi build hoặc cấu hình Firestore
  static String systemApiKey = const String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final customKey = prefs.getString(keyGeminiApiKey);
    if (customKey != null && customKey.trim().isNotEmpty) {
      return customKey.trim();
    }
    if (systemApiKey.trim().isNotEmpty) {
      return systemApiKey.trim();
    }
    // Hỗ trợ đồng bộ API Key từ Cloud Firestore nếu được quản trị viên thiết lập
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_config')
          .doc('ai')
          .get()
          .timeout(const Duration(seconds: 2));
      if (doc.exists && doc.data() != null) {
        final firestoreKey = doc.data()!['gemini_api_key']?.toString();
        if (firestoreKey != null && firestoreKey.trim().isNotEmpty) {
          return firestoreKey.trim();
        }
      }
    } catch (_) {
      // Bỏ qua lỗi kết nối và chuyển sang bộ Heuristic Ngoại tuyến
    }
    return '';
  }

  static Future<void> setApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.trim().isEmpty) {
      await prefs.remove(keyGeminiApiKey);
    } else {
      await prefs.setString(keyGeminiApiKey, key.trim());
    }
  }

  static Future<String> getModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySelectedModel) ?? defaultModel;
  }

  static Future<void> setModelName(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keySelectedModel, model.trim());
  }
}

/// Dịch vụ Trợ lý AI Điều phối & Tư vấn phương tiện GoShip
class AiCargoAdvisorService {
  /// Phân tích danh sách hàng hóa và trả về khuyến nghị phương tiện tối ưu kèm sơ đồ xếp hàng LIFO
  static Future<CargoRecommendation> analyzeCargo(
    String cargoDescription, {
    int dropoffCount = 1,
  }) async {
    final cleanInput = cargoDescription.trim();
    if (cleanInput.isEmpty) {
      return _generateDefaultRecommendation('Không có mô tả hàng hóa');
    }

    final apiKey = await AiConfig.getApiKey();
    final primaryModel = await AiConfig.getModelName();

    // Nếu người dùng đã cài đặt API Key, ưu tiên gọi Google Gemini Cloud AI
    if (apiKey.isNotEmpty) {
      final modelsToTry = [
        primaryModel,
        ...AiConfig.availableModels.where((m) => m != primaryModel),
      ];

      for (final model in modelsToTry) {
        try {
          final result = await _callGeminiApi(cleanInput, apiKey, model, dropoffCount: dropoffCount);
          if (result != null) {
            return result;
          }
        } catch (_) {
          // Thử tiếp model fallback nếu model hiện tại hết hạn / lỗi
          continue;
        }
      }
    }

    // Nếu không có API Key, mất mạng, hoặc API lỗi -> kích hoạt Động cơ Heuristic Thông minh Offline
    return _offlineHeuristicAnalyze(cleanInput, dropoffCount: dropoffCount);
  }

  /// Gọi REST API Google Gemini với Structured JSON System Prompt
  static Future<CargoRecommendation?> _callGeminiApi(
    String cargoDescription,
    String apiKey,
    String modelName, {
    int dropoffCount = 1,
  }) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey',
    );

    final multiDropNote = dropoffCount > 1
        ? 'Đơn hàng có $dropoffCount ĐIỂM GIAO. Nguyên tắc LIFO bắt buộc: Hàng Điểm 1 xếp ngay CỬA SAU xe để dỡ trước, hàng Điểm $dropoffCount xếp SÁT CABIN để dỡ sau cùng.'
        : 'Đơn hàng có 1 điểm giao. Hàng dỡ trước/nhỏ gọn để cửa sau, hàng nặng làm trọng tâm đặt sát vách cabin.';

    final systemPrompt = '''
Bạn là chuyên gia điều phối vận tải logistics hàng đầu của ứng dụng GoShip tại Việt Nam.
Nhiệm vụ của bạn: Phân tích danh sách đồ đạc, hàng hóa do khách hàng cung cấp và chọn đúng LOẠI XE TỐI ƯU NHẤT trong đội xe GoShip:
1. "motorbike" (Xe Bán tải): Tải trọng max 500kg, thể tích thùng ~2.0 m³, chiều dài thùng ~1.5m. Thích hợp đồ nhỏ gọn, vài thùng đồ, bàn ghế nhỏ. KHÔNG chở được tủ lạnh lớn đứng hoặc sofa >1.6m.
2. "van" (Xe van): Tải trọng max 1000kg, thể tích thùng ~3.5 m³, chiều dài ~2.1m, chiều cao ~1.3m. Rất thích hợp đồ phòng trọ, tủ lạnh nhỏ/vừa, máy giặt, đệm gấp, sofa nhỏ <2m.
3. "truck" (Xe tải): Tải trọng max 2500kg, thể tích thùng ~10.0 m³, chiều dài ~3.5m, chiều cao ~1.8m. Chở được sofa lớn >2m, tủ lạnh 2 cánh/side by side chở đứng, giường tủ tháo lắp, đồ đạc nhà 1-2 phòng ngủ.
4. "container" (Container): Tải trọng max 10000kg, thể tích >15 m³. Dùng cho hàng siêu trường, máy móc cơ khí công nghiệp nặng >2.5 tấn hoặc chuyển trọn gói nhà xưởng lớn.

NGỮ CẢNH VẬN CHUYỂN:
$multiDropNote

QUY TẮC BẮT BUỘC:
- Trả về DUY NHẤT một chuỗi JSON hợp lệ (không chứa markdown ```json hay text ngoài).
- Định dạng JSON mẫu:
{
  "recommended_vehicle": "van" | "motorbike" | "truck" | "container",
  "estimated_weight_kg": 250,
  "estimated_volume_m3": 2.4,
  "package_category": "Nội thất / Hàng gia dụng" | "Hàng tiêu chuẩn / Thùng carton" | "Hàng cồng kềnh / Quá khổ" | "Hàng dễ vỡ / Điện tử" | "Vật liệu xây dựng / Cơ khí" | "Nông sản / Thực phẩm tươi sống",
  "weight_category_chip": "<100kg" | "100-500kg" | "500-1000kg" | ">1000kg",
  "requires_tailgate": false,
  "is_fragile": false,
  "requires_standing": false,
  "requires_porter": false,
  "has_long_dimensions": false,
  "reasoning": "Giải thích ngắn gọn 1-2 câu tiếng Việt lý do chọn xe này (chiều dài, thể tích, tư thế chở).",
  "driver_note_advice": "Ghi chú hữu ích cho tài xế (VD: Tủ lạnh cần chở đứng, hàng có tivi dễ vỡ cần chèn xốp).",
  "loading_plan": {
    "door_side": "Mô tả cụ thể món đồ nào xếp tại cửa sau thùng xe (Lấy trước - Điểm 1)",
    "middle_section": "Mô tả cụ thể món đồ xếp giữa thùng xe (Thùng carton, hàng kích thước vừa)",
    "cabin_side": "Mô tả cụ thể món đồ xếp sát vách cabin (Hàng nặng nhất / Lấy sau cùng)",
    "stacking_advice": "Hướng dẫn phân tầng Đáy - Đỉnh, chèn lót đồ dễ vỡ, cố định dây chằng"
  },
  "recommended_supplies": [
    "Màng quấn PE chống trầy",
    "Chăn bọc bảo vệ nội thất",
    "Dây tăng đơ chằng thùng"
  ],
  "estimated_handling_minutes": 25
}
''';

    final requestBody = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': '$systemPrompt\n\nKhách hàng mô tả hàng hóa:\n"$cargoDescription"'}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'responseMimeType': 'application/json',
      }
    };

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text != null) {
        String cleanJson = text.toString().trim();
        if (cleanJson.startsWith('```json')) {
          cleanJson = cleanJson.substring(7);
        }
        if (cleanJson.startsWith('```')) {
          cleanJson = cleanJson.substring(3);
        }
        if (cleanJson.endsWith('```')) {
          cleanJson = cleanJson.substring(0, cleanJson.length - 3);
        }
        cleanJson = cleanJson.trim();

        final parsed = jsonDecode(cleanJson) as Map<String, dynamic>;
        return CargoRecommendation.fromJson(
          parsed,
          isFromCloudAi: true,
          modelUsed: modelName,
        );
      }
    }
    return null;
  }

  /// Động cơ Heuristic Thông minh Offline (Chạy nội bộ độc lập 100%, không cần internet)
  static CargoRecommendation _offlineHeuristicAnalyze(String desc, {int dropoffCount = 1}) {
    final lower = desc.toLowerCase();

    int totalWeight = 0;
    double totalVolume = 0.0;
    bool hasFragile = false;
    bool needsStanding = false;
    bool hasLongItem = false; // Món đồ dài > 2m
    bool needsTailgate = false;
    final detectedItems = <String>[];

    // 1. Tủ lạnh
    if (lower.contains('tủ lạnh')) {
      if (lower.contains('side by side') || lower.contains('2 cánh') || lower.contains('to') || lower.contains('lớn') || lower.contains('400') || lower.contains('500')) {
        totalWeight += 85;
        totalVolume += 1.4;
        needsStanding = true;
        detectedItems.add('Tủ lạnh 2 cánh lớn (~85kg, chở đứng)');
      } else {
        totalWeight += 45;
        totalVolume += 0.7;
        needsStanding = true;
        detectedItems.add('Tủ lạnh tiêu chuẩn (~45kg, chở đứng)');
      }
    }

    // 2. Máy giặt
    if (lower.contains('máy giặt')) {
      if (lower.contains('cửa ngang') || lower.contains('lồng ngang')) {
        totalWeight += 70;
        totalVolume += 0.55;
        detectedItems.add('Máy giặt cửa ngang (~70kg)');
      } else {
        totalWeight += 40;
        totalVolume += 0.45;
        detectedItems.add('Máy giặt cửa trên (~40kg)');
      }
    }

    // 3. Sofa / Ghế dài
    if (lower.contains('sofa') || lower.contains('ghế dài') || lower.contains('salon') || lower.contains('sa lông')) {
      if (lower.contains('chữ l') || lower.contains('3 chỗ') || lower.contains('2m') || lower.contains('lớn')) {
        totalWeight += 75;
        totalVolume += 2.0;
        hasLongItem = true;
        detectedItems.add('Sofa dài (>2m, chiếm ~2.0m³)');
      } else {
        totalWeight += 40;
        totalVolume += 1.0;
        detectedItems.add('Sofa đôi/nhỏ (~40kg)');
      }
    }

    // 4. Giường / Nệm
    if (lower.contains('giường')) {
      totalWeight += 60;
      totalVolume += 1.5;
      hasLongItem = true;
      detectedItems.add('Giường tháo lắp (~60kg, dài ~2m)');
    }
    if (lower.contains('nệm') || lower.contains('đệm')) {
      if (lower.contains('kymdan') || lower.contains('lò xo') || lower.contains('cao su') || lower.contains('1m8') || lower.contains('2m')) {
        totalWeight += 45;
        totalVolume += 0.9;
        hasLongItem = true;
        detectedItems.add('Nệm nguyên tấm lớn (~45kg)');
      } else {
        totalWeight += 15;
        totalVolume += 0.35;
        detectedItems.add('Nệm gấp gọn (~15kg)');
      }
    }

    // 5. Tủ quần áo / Tủ gỗ
    if (lower.contains('tủ quần áo') || lower.contains('tủ gỗ') || lower.contains('tủ sắt')) {
      totalWeight += 80;
      totalVolume += 1.8;
      hasLongItem = true;
      detectedItems.add('Tủ quần áo/gỗ lớn (~80kg)');
    }

    // 6. Bàn làm việc / Bàn ăn
    if (lower.contains('bàn làm việc') || lower.contains('bàn ăn') || lower.contains('bàn họp')) {
      totalWeight += 35;
      totalVolume += 0.7;
      detectedItems.add('Bàn làm việc/bàn ăn (~35kg)');
    }

    // 7. Thùng carton / Hộp đồ
    final boxRegex = RegExp(r'(\d+)\s*(thùng|kiện|hộp|bao)');
    final match = boxRegex.firstMatch(lower);
    if (match != null) {
      final count = int.tryParse(match.group(1) ?? '1') ?? 1;
      totalWeight += count * 15;
      totalVolume += count * 0.12;
      detectedItems.add('$count thùng/kiện hàng (~${count * 15}kg)');
    } else if (lower.contains('thùng') || lower.contains('thùng carton') || lower.contains('kiện đồ')) {
      totalWeight += 45;
      totalVolume += 0.4;
      detectedItems.add('Một số thùng carton đồ đạc (~45kg)');
    }

    // 8. Tivi / Màn hình / Đồ dễ vỡ
    if (lower.contains('tivi') || lower.contains('tv') || lower.contains('màn hình') || lower.contains('gương') || lower.contains('kính') || lower.contains('dễ vỡ') || lower.contains('đồ sứ')) {
      hasFragile = true;
      totalWeight += 20;
      totalVolume += 0.3;
      detectedItems.add('Thiết bị điện tử / hàng dễ vỡ');
    }

    // 9. Hàng công nghiệp nặng / Két sắt / Đàn Piano / Vật liệu
    if (lower.contains('két sắt') || lower.contains('piano') || lower.contains('máy phát điện') || lower.contains('cơ khí') || lower.contains('xi măng') || lower.contains('sắt thép')) {
      totalWeight += 300;
      totalVolume += 1.5;
      needsTailgate = true;
      detectedItems.add('Hàng nặng/cơ khí đặc thù (khuyến nghị bửng nâng)');
    }

    // Trọng lượng tối thiểu nếu không nhận diện được món cụ thể
    if (totalWeight == 0) {
      totalWeight = 50;
      totalVolume = 0.5;
    }

    // Quy tắc chọn phương tiện
    OrderVehicleType recommended;
    String reasoning;

    if (totalWeight > 2500 || totalVolume > 11.0) {
      recommended = OrderVehicleType.container;
      reasoning = 'Tổng khối lượng hàng hóa ước tính $totalWeight kg (thể tích ~${totalVolume.toStringAsFixed(1)} m³) vượt quá sức chứa xe tải thông thường. Khuyên dùng Container/Xe tải hạng nặng để đảm bảo an toàn.';
    } else if (totalWeight > 1000 || totalVolume > 3.6 || hasLongItem || (needsStanding && totalVolume > 2.0)) {
      recommended = OrderVehicleType.truck;
      if (hasLongItem) {
        reasoning = 'Hàng hóa có các món đồ dài/cồng kềnh (>2m như sofa, đệm hoặc tủ lớn). Xe tải (thùng dài 3.5m, tải trọng 2.5 tấn) là lựa chọn duy nhất đảm bảo xếp vừa trọn gói.';
      } else if (needsStanding) {
        reasoning = 'Đơn hàng có tủ lạnh cần chở đứng kết hợp lượng lớn đồ đạc ($totalWeight kg, ~${totalVolume.toStringAsFixed(1)} m³). Xe tải thùng cao đảm bảo chở đứng an toàn và đủ chỗ cho toàn bộ đồ đạc.';
      } else {
        reasoning = 'Tổng khối lượng ước tính $totalWeight kg, thể tích ~${totalVolume.toStringAsFixed(1)} m³. Xe tải 2.5 tấn thùng kín/bạt đảm bảo chở hết đồ trong 1 chuyến mà không bị quá tải.';
      }
    } else if (totalWeight > 450 || totalVolume > 1.8 || needsStanding) {
      recommended = OrderVehicleType.van;
      if (needsStanding) {
        reasoning = 'Đơn hàng có tủ lạnh cần chở đứng để bảo vệ block máy. Xe van (tải 1000kg, thể tích thùng 3.5 m³) là phương án vừa vặn, che chắn mưa nắng và tối ưu chi phí nhất.';
      } else {
        reasoning = 'Tổng khối lượng ~$totalWeight kg và thể tích ~${totalVolume.toStringAsFixed(1)} m³ phù hợp hoàn hảo với khoang thùng xe van (sức chứa 1000kg, 3.5 m³).';
      }
    } else {
      recommended = OrderVehicleType.motorbike; // Xe Bán tải (500kg)
      reasoning = 'Hàng hóa gọn nhẹ (khoảng $totalWeight kg, ${totalVolume.toStringAsFixed(1)} m³). Xe Bán tải GoShip (tải trọng 500kg) là lựa chọn nhanh chóng và tiết kiệm chi phí nhất.';
    }

    // Xác định phân loại hàng hóa và chip cân nặng
    String category = 'Hàng tiêu chuẩn / Thùng carton';
    if (hasFragile) {
      category = 'Hàng dễ vỡ / Điện tử';
    } else if (hasLongItem || totalVolume > 2.0) {
      category = 'Nội thất / Hàng gia dụng';
    } else if (needsTailgate) {
      category = 'Vật liệu xây dựng / Cơ khí';
    }

    String weightChip = '>1000kg';
    if (totalWeight < 100) {
      weightChip = '<100kg';
    } else if (totalWeight <= 500) {
      weightChip = '100-500kg';
    } else if (totalWeight <= 1000) {
      weightChip = '500-1000kg';
    }

    // Lời khuyên cho tài xế
    final adviceParts = <String>[];
    if (needsStanding) adviceParts.add('Tủ lạnh cần chở đứng');
    if (hasFragile) adviceParts.add('Hàng có thiết bị dễ vỡ/màn hình');
    if (needsTailgate) adviceParts.add('Hàng nặng cần hỗ trợ bốc xếp');
    if (detectedItems.isNotEmpty) {
      adviceParts.add('Đồ gồm: ${detectedItems.take(3).join(", ")}');
    }

    // Sơ đồ phân bổ thùng xe LIFO thông minh
    String doorSide;
    String middleSection;
    String cabinSide;
    final supplies = <String>['Màng quấn PE chống trầy', 'Dây chằng tăng đơ'];

    if (dropoffCount > 1) {
      doorSide = 'Điểm 1 (Dỡ trước): Các kiện thùng carton, đồ dùng cần giao ngay tại điểm đầu tiên.';
      middleSection = 'Hàng trung chuyển, thùng đồ kích thước vừa, đồ bọc lót chống sốc.';
      cabinSide = 'Điểm $dropoffCount (Dỡ sau cùng): Đồ cồng kềnh, kiện hàng nặng nhất neo sát vách cabin.';
    } else {
      doorSide = 'Thùng carton nhỏ, vali, đồ đạc gọn nhẹ hoặc các món cần lấy ra đầu tiên khi tới nơi.';
      middleSection = 'Thùng đồ tiêu chuẩn, đồ gia dụng vừa, bàn làm việc hoặc ghế tháo rời.';
      cabinSide = 'Hàng nặng và cồng kềnh nhất (giường tủ, máy giặt, tủ lạnh) đặt sát vách cabin làm trọng tâm xe.';
    }

    if (needsStanding) {
      cabinSide = 'Tủ lạnh dựng đứng áp sát vách cabin, chằng dây đai tăng đơ chắc chắn (tránh chảy dầu block máy).';
      supplies.add('Dây đai tăng đơ chằng thùng');
    }
    if (hasFragile) {
      middleSection = 'Tivi/màn hình/đồ sứ bọc xốp bóng khí, kê trên đệm lót, chèn chặt bằng thùng mềm xung quanh.';
      supplies.add('Màng xốp bóng khí (Bubble wrap)');
      supplies.add('Băng keo dán Hàng dễ vỡ');
    }
    if (hasLongItem) {
      supplies.add('Chăn bọc chống trầy nội thất');
    }
    if (needsTailgate) {
      supplies.add('Xe đẩy hàng bánh cao su');
    }

    final stowagePlan = LoadingStowagePlan(
      doorSide: doorSide,
      middleSection: middleSection,
      cabinSide: cabinSide,
      stackingAdvice: 'Quy tắc Đáy - Đỉnh: Đồ nặng đặt sát sàn xe gần trục bánh sau; thùng carton nhẹ xếp lên trên; chèn chặt khe hở bằng màng xốp để hàng không bị xô lệch khi xe thắng gấp.',
    );

    int handlingMins = 15;
    if (totalWeight > 500 || totalVolume > 4.0) {
      handlingMins = 35;
    } else if (totalWeight > 180 || totalVolume > 2.0) {
      handlingMins = 25;
    }
    if (dropoffCount > 1) {
      handlingMins += (dropoffCount - 1) * 10;
    }

    return CargoRecommendation(
      vehicleType: recommended,
      vehicleName: recommended.name,
      estimatedWeightKg: totalWeight,
      estimatedVolumeM3: double.parse(totalVolume.toStringAsFixed(1)),
      packageCategory: category,
      weightCategoryChip: weightChip,
      requiresTailgate: needsTailgate,
      isFragile: hasFragile,
      requiresStanding: needsStanding,
      requiresPorter: totalWeight > 120 || needsTailgate,
      hasLongDimensions: hasLongItem,
      reasoning: reasoning,
      driverNoteAdvice: adviceParts.join(' • '),
      isFromCloudAi: false,
      modelUsed: 'Động cơ Phân tích Ngữ nghĩa Nội bộ (Local Heuristics)',
      stowagePlan: stowagePlan,
      recommendedSupplies: supplies.toSet().toList(),
      estimatedHandlingMinutes: handlingMins,
    );
  }

  static CargoRecommendation _generateDefaultRecommendation(String reason) {
    return CargoRecommendation(
      vehicleType: OrderVehicleType.van,
      vehicleName: OrderVehicleType.van.name,
      estimatedWeightKg: 100,
      estimatedVolumeM3: 1.5,
      packageCategory: 'Hàng tiêu chuẩn / Thùng carton',
      weightCategoryChip: '100-500kg',
      requiresTailgate: false,
      isFragile: false,
      requiresStanding: false,
      reasoning: 'Vui lòng mô tả chi tiết các món đồ cần vận chuyển để AI tính toán chính xác nhất.',
      driverNoteAdvice: '',
      isFromCloudAi: false,
      modelUsed: 'Hệ thống Mặc định',
      stowagePlan: LoadingStowagePlan(
        doorSide: 'Các kiện hàng dỡ trước hoặc đồ nhỏ gọn cần lấy ngay.',
        middleSection: 'Thùng carton tiêu chuẩn, vật dụng kích thước vừa.',
        cabinSide: 'Hàng nặng đặt sát vách cabin làm trọng tâm cân bằng tải xe.',
        stackingAdvice: 'Xếp đồ nặng sát sàn xe, đồ nhẹ lên trên, chèn lót kỹ các góc cạnh.',
      ),
      recommendedSupplies: const ['Màng quấn PE chống trầy', 'Dây chằng tăng đơ'],
      estimatedHandlingMinutes: 20,
    );
  }
}
