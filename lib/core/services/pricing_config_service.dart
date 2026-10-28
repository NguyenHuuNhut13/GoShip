import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class VehiclePricingRule {
  final String key;
  final String name;
  final String icon;
  final int baseFee;
  final int perKmFee;
  final double peakMultiplier;
  final int waitFee;
  final int minFee;
  final bool isPeakActive;

  const VehiclePricingRule({
    required this.key,
    required this.name,
    required this.icon,
    required this.baseFee,
    required this.perKmFee,
    this.peakMultiplier = 1.0,
    this.waitFee = 2000,
    required this.minFee,
    this.isPeakActive = false,
  });

  factory VehiclePricingRule.fromMap(String key, Map<String, dynamic> map, VehiclePricingRule fallback) {
    return VehiclePricingRule(
      key: key,
      name: map['name']?.toString() ?? fallback.name,
      icon: map['icon']?.toString() ?? fallback.icon,
      baseFee: (map['base'] as num?)?.toInt() ?? (map['baseFee'] as num?)?.toInt() ?? fallback.baseFee,
      perKmFee: (map['perKm'] as num?)?.toInt() ?? (map['perKmFee'] as num?)?.toInt() ?? fallback.perKmFee,
      peakMultiplier: (map['peak'] as num?)?.toDouble() ?? (map['peakMultiplier'] as num?)?.toDouble() ?? fallback.peakMultiplier,
      waitFee: (map['wait'] as num?)?.toInt() ?? (map['waitFee'] as num?)?.toInt() ?? fallback.waitFee,
      minFee: (map['min'] as num?)?.toInt() ?? (map['minFee'] as num?)?.toInt() ?? fallback.minFee,
      isPeakActive: map['isPeakActive'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'name': name,
      'icon': icon,
      'base': baseFee,
      'perKm': perKmFee,
      'peak': peakMultiplier,
      'wait': waitFee,
      'min': minFee,
      'isPeakActive': isPeakActive,
    };
  }

  VehiclePricingRule copyWith({
    int? baseFee,
    int? perKmFee,
    double? peakMultiplier,
    int? waitFee,
    int? minFee,
    bool? isPeakActive,
  }) {
    return VehiclePricingRule(
      key: key,
      name: name,
      icon: icon,
      baseFee: baseFee ?? this.baseFee,
      perKmFee: perKmFee ?? this.perKmFee,
      peakMultiplier: peakMultiplier ?? this.peakMultiplier,
      waitFee: waitFee ?? this.waitFee,
      minFee: minFee ?? this.minFee,
      isPeakActive: isPeakActive ?? this.isPeakActive,
    );
  }
}

/// Dịch vụ đồng bộ Bảng giá cước vận chuyển thời gian thực từ Cloud Firestore (`pricing_config/default`).
/// Cho phép Admin thay đổi giá cước trên Web hoặc Mobile và áp dụng ngay lập tức cho App Khách hàng.
class PricingConfigService extends ChangeNotifier {
  static final PricingConfigService instance = PricingConfigService._internal();
  PricingConfigService._internal();

  static const Map<String, VehiclePricingRule> defaultRules = {
    'motorbike': VehiclePricingRule(
      key: 'motorbike',
      name: 'Xe Bán tải',
      icon: '🛻',
      baseFee: 35000,
      perKmFee: 6000,
      peakMultiplier: 1.2,
      waitFee: 2000,
      minFee: 35000,
    ),
    'van': VehiclePricingRule(
      key: 'van',
      name: 'Xe van',
      icon: '🚐',
      baseFee: 50000,
      perKmFee: 10000,
      peakMultiplier: 1.2,
      waitFee: 3000,
      minFee: 50000,
    ),
    'truck': VehiclePricingRule(
      key: 'truck',
      name: 'Xe tải',
      icon: '🚚',
      baseFee: 120000,
      perKmFee: 15000,
      peakMultiplier: 1.3,
      waitFee: 5000,
      minFee: 120000,
    ),
    'container': VehiclePricingRule(
      key: 'container',
      name: 'Container',
      icon: '📦',
      baseFee: 350000,
      perKmFee: 25000,
      peakMultiplier: 1.3,
      waitFee: 10000,
      minFee: 350000,
    ),
  };

  Map<String, VehiclePricingRule> _rules = Map<String, VehiclePricingRule>.from(defaultRules);
  bool _initialized = false;

  Map<String, VehiclePricingRule> get rules => _rules;

  VehiclePricingRule getRule(String vehicleKey) {
    return _rules[vehicleKey] ?? defaultRules[vehicleKey] ?? defaultRules['motorbike']!;
  }

  void startListening() {
    if (_initialized) return;
    _initialized = true;
    try {
      final docRef = FirebaseFirestore.instance.collection('pricing_config').doc('default');
      docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          // Khởi tạo bảng giá mặc định lên Cloud nếu chưa có
          saveRulesToCloud(defaultRules);
          return;
        }
        final data = snapshot.data()!;
        final updated = <String, VehiclePricingRule>{};
        for (final entry in defaultRules.entries) {
          final raw = data[entry.key];
          if (raw is Map<String, dynamic>) {
            updated[entry.key] = VehiclePricingRule.fromMap(entry.key, raw, entry.value);
          } else {
            updated[entry.key] = entry.value;
          }
        }
        _rules = updated;
        notifyListeners();
      }, onError: (e) {
        debugPrint('>>> [PricingConfigService Stream Warning]: $e');
      });
    } catch (e) {
      debugPrint('>>> [PricingConfigService Init Error]: $e');
    }
  }

  Future<bool> saveRulesToCloud(Map<String, VehiclePricingRule> newRules) async {
    try {
      _rules = Map<String, VehiclePricingRule>.from(newRules);
      notifyListeners();

      final payload = <String, dynamic>{
        'updated_at': FieldValue.serverTimestamp(),
      };
      for (final entry in newRules.entries) {
        payload[entry.key] = entry.value.toMap();
      }
      await FirebaseFirestore.instance
          .collection('pricing_config')
          .doc('default')
          .set(payload, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('>>> [PricingConfigService Save Error]: $e');
      return false;
    }
  }

  Future<bool> resetToDefault() async {
    return saveRulesToCloud(defaultRules);
  }
}
