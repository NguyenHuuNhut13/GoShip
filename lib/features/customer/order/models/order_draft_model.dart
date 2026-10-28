import 'package:latlong2/latlong.dart';
import '../../../../core/services/pricing_config_service.dart';
import 'simulated_driver_model.dart';

enum OrderVehicleType {
  motorbike(
    keyName: 'motorbike',
    name: 'Xe Bán tải',
    icon: '🛻',
    defaultBaseFee: 35000,
    defaultPerKmFee: 6000,
    maxWeight: 500,
    bedLengthM: 1.5,
    bedWidthM: 1.2,
    bedHeightM: 0.9,
    maxVolumeM3: 1.6,
  ),
  van(
    keyName: 'van',
    name: 'Xe van',
    icon: '🚐',
    defaultBaseFee: 50000,
    defaultPerKmFee: 10000,
    maxWeight: 1000,
    bedLengthM: 2.1,
    bedWidthM: 1.3,
    bedHeightM: 1.3,
    maxVolumeM3: 3.5,
  ),
  truck(
    keyName: 'truck',
    name: 'Xe tải',
    icon: '🚚',
    defaultBaseFee: 120000,
    defaultPerKmFee: 15000,
    maxWeight: 2500,
    bedLengthM: 3.5,
    bedWidthM: 1.8,
    bedHeightM: 1.8,
    maxVolumeM3: 11.3,
  ),
  container(
    keyName: 'container',
    name: 'Container',
    icon: '📦',
    defaultBaseFee: 350000,
    defaultPerKmFee: 25000,
    maxWeight: 10000,
    bedLengthM: 6.0,
    bedWidthM: 2.4,
    bedHeightM: 2.6,
    maxVolumeM3: 37.4,
  );

  final String keyName;
  final String name;
  final String icon;
  final int defaultBaseFee;
  final int defaultPerKmFee;
  final int maxWeight;
  final double bedLengthM;
  final double bedWidthM;
  final double bedHeightM;
  final double maxVolumeM3;

  const OrderVehicleType({
    required this.keyName,
    required this.name,
    required this.icon,
    required this.defaultBaseFee,
    required this.defaultPerKmFee,
    required this.maxWeight,
    required this.bedLengthM,
    required this.bedWidthM,
    required this.bedHeightM,
    required this.maxVolumeM3,
  });

  int get baseFee => PricingConfigService.instance.getRule(keyName).baseFee;
  int get perKmFee => PricingConfigService.instance.getRule(keyName).perKmFee;
  int get minFee => PricingConfigService.instance.getRule(keyName).minFee;
  double get peakMultiplier {
    final rule = PricingConfigService.instance.getRule(keyName);
    return rule.isPeakActive ? rule.peakMultiplier : 1.0;
  }

  String get dimensionSummary => '${bedLengthM}m (Dài) x ${bedWidthM}m (Rộng) x ${bedHeightM}m (Cao)';

  static OrderVehicleType fromName(String? name) {
    if (name == null) return OrderVehicleType.motorbike;
    for (final v in OrderVehicleType.values) {
      if (v.name.toLowerCase() == name.toLowerCase() || name.toLowerCase().contains(v.name.toLowerCase())) {
        return v;
      }
    }
    return OrderVehicleType.motorbike;
  }
}

/// Kết quả phân tích độ vừa vặn của kiện hàng so với thùng xe đang chọn
class CargoFitResult {
  final bool fits;
  final bool lengthExceeded;
  final bool widthExceeded;
  final bool heightExceeded;
  final bool volumeExceeded;
  final String message;
  final List<String> issues;
  final OrderVehicleType? suggestedVehicle;

  const CargoFitResult({
    required this.fits,
    this.lengthExceeded = false,
    this.widthExceeded = false,
    this.heightExceeded = false,
    this.volumeExceeded = false,
    required this.message,
    this.issues = const [],
    this.suggestedVehicle,
  });

  static CargoFitResult analyze({
    required OrderVehicleType vehicle,
    required double length,
    required double width,
    required double height,
  }) {
    if (length <= 0 && width <= 0 && height <= 0) {
      return const CargoFitResult(
        fits: true,
        message: 'Nhập kích thước (Dài x Rộng x Cao) để hệ thống kiểm tra độ vừa với thùng xe.',
      );
    }

    final l = length > 0 ? length : 0.1;
    final w = width > 0 ? width : 0.1;
    final h = height > 0 ? height : 0.1;

    final issues = <String>[];
    bool lenExceeded = false;
    bool widExceeded = false;
    bool heiExceeded = false;
    bool volExceeded = false;

    final fitsNormal = l <= vehicle.bedLengthM && w <= vehicle.bedWidthM && h <= vehicle.bedHeightM;
    final fitsRotatedFloor = w <= vehicle.bedLengthM && l <= vehicle.bedWidthM && h <= vehicle.bedHeightM;

    final dims = [l, w, h]..sort();
    final bedDims = [vehicle.bedLengthM, vehicle.bedWidthM, vehicle.bedHeightM]..sort();
    final canFitAnyOrientation = dims[0] <= bedDims[0] && dims[1] <= bedDims[1] && dims[2] <= bedDims[2];

    final cargoVolume = l * w * h;
    if (cargoVolume > vehicle.maxVolumeM3) {
      volExceeded = true;
      issues.add('Thể tích hàng (${cargoVolume.toStringAsFixed(1)}m³) vượt quá dung tích thùng xe (${vehicle.maxVolumeM3.toStringAsFixed(1)}m³)');
    }

    // Đánh giá chiều rộng (ngang) - trường hợp người dùng quan tâm nhất
    if (w > vehicle.bedWidthM && (!fitsRotatedFloor && w > vehicle.bedLengthM)) {
      widExceeded = true;
      issues.add('Chiều ngang hàng (${w.toStringAsFixed(1)}m) vượt quá chiều rộng thùng xe (${vehicle.bedWidthM.toStringAsFixed(1)}m)');
    } else if (w > vehicle.bedWidthM && fitsRotatedFloor) {
      // Có thể xếp dọc theo chiều dài xe
    } else if (w > vehicle.bedWidthM && !canFitAnyOrientation) {
      widExceeded = true;
      issues.add('Chiều ngang hàng (${w.toStringAsFixed(1)}m) vượt quá chiều rộng thùng xe (${vehicle.bedWidthM.toStringAsFixed(1)}m)');
    }

    if (l > vehicle.bedLengthM && (!fitsRotatedFloor || l > vehicle.bedWidthM) && !canFitAnyOrientation) {
      lenExceeded = true;
      issues.add('Chiều dài hàng (${l.toStringAsFixed(1)}m) vượt quá chiều dài thùng xe (${vehicle.bedLengthM.toStringAsFixed(1)}m)');
    }

    if (h > vehicle.bedHeightM && !canFitAnyOrientation) {
      heiExceeded = true;
      issues.add('Chiều cao hàng (${h.toStringAsFixed(1)}m) vượt quá chiều cao thùng xe (${vehicle.bedHeightM.toStringAsFixed(1)}m)');
    }

    final bool overallFits = canFitAnyOrientation && !volExceeded;

    OrderVehicleType? suggested;
    if (!overallFits) {
      for (final v in OrderVehicleType.values) {
        if (v == vehicle) continue;
        final vBedDims = [v.bedLengthM, v.bedWidthM, v.bedHeightM]..sort();
        if (dims[0] <= vBedDims[0] && dims[1] <= vBedDims[1] && dims[2] <= vBedDims[2] && cargoVolume <= v.maxVolumeM3) {
          suggested = v;
          break;
        }
      }
      suggested ??= (vehicle != OrderVehicleType.container ? OrderVehicleType.container : null);
    }

    if (overallFits) {
      String fitNote = 'Kích thước kiện hàng (${l.toStringAsFixed(1)}m x ${w.toStringAsFixed(1)}m x ${h.toStringAsFixed(1)}m) vừa vặn với thùng ${vehicle.name} (${vehicle.dimensionSummary}).';
      if (!fitsNormal && fitsRotatedFloor) {
        fitNote += ' (Khuyên đặt dọc kiện hàng theo chiều dài xe khi bốc xếp)';
      }
      return CargoFitResult(
        fits: true,
        message: fitNote,
      );
    } else {
      final reason = issues.isNotEmpty ? issues.join(' • ') : 'Kích thước kiện hàng vượt quá giới hạn lọt lòng thùng xe.';
      return CargoFitResult(
        fits: false,
        lengthExceeded: lenExceeded,
        widthExceeded: widExceeded,
        heightExceeded: heiExceeded,
        volumeExceeded: volExceeded,
        issues: issues,
        suggestedVehicle: suggested,
        message: reason,
      );
    }
  }

  /// Phân tích độ vừa vặn của kiện hàng khi giao đa điểm (từng món giao ở từng điểm)
  static CargoFitResult analyzeMultiDrop({
    required OrderVehicleType vehicle,
    required List<DropoffRecipient> recipients,
    required List<String> dropoffAddresses,
  }) {
    if (recipients.isEmpty || !recipients.any((r) => r.hasDimensions || r.itemsDescription.isNotEmpty)) {
      return const CargoFitResult(
        fits: true,
        message: 'Nhập kích thước hoặc mô tả kiện hàng theo từng điểm giao để hệ thống kiểm tra.',
      );
    }

    final issues = <String>[];
    double totalVolume = 0.0;
    bool anyItemExceeded = false;
    bool lenExceeded = false;
    bool widExceeded = false;
    bool heiExceeded = false;
    bool volExceeded = false;

    for (int i = 0; i < recipients.length; i++) {
      final r = recipients[i];
      final pointLabel = 'Điểm ${i + 1}';
      final itemLabel = r.itemsDescription.isNotEmpty ? '"${r.itemsDescription}" ($pointLabel)' : pointLabel;

      if (r.hasDimensions) {
        final l = (r.lengthM != null && r.lengthM! > 0) ? r.lengthM! : 0.1;
        final w = (r.widthM != null && r.widthM! > 0) ? r.widthM! : 0.1;
        final h = (r.heightM != null && r.heightM! > 0) ? r.heightM! : 0.1;
        final itemVol = l * w * h;
        totalVolume += itemVol;

        final itemDims = [l, w, h]..sort();
        final bedDims = [vehicle.bedLengthM, vehicle.bedWidthM, vehicle.bedHeightM]..sort();
        final canFit = itemDims[0] <= bedDims[0] && itemDims[1] <= bedDims[1] && itemDims[2] <= bedDims[2];

        if (!canFit) {
          anyItemExceeded = true;
          if (w > vehicle.bedWidthM && (w > vehicle.bedLengthM || l > vehicle.bedWidthM)) {
            widExceeded = true;
            issues.add('$itemLabel: Chiều ngang (${w.toStringAsFixed(1)}m) vượt quá chiều rộng thùng xe ${vehicle.bedWidthM}m');
          } else if (l > vehicle.bedLengthM) {
            lenExceeded = true;
            issues.add('$itemLabel: Chiều dài (${l.toStringAsFixed(1)}m) vượt quá chiều dài thùng xe ${vehicle.bedLengthM}m');
          } else if (h > vehicle.bedHeightM) {
            heiExceeded = true;
            issues.add('$itemLabel: Chiều cao (${h.toStringAsFixed(1)}m) vượt quá chiều cao thùng xe ${vehicle.bedHeightM}m');
          } else {
            issues.add('$itemLabel: Kích thước (${l.toStringAsFixed(1)}m x ${w.toStringAsFixed(1)}m x ${h.toStringAsFixed(1)}m) quá khổ lọt lòng xe');
          }
        }
      }
    }

    if (totalVolume > vehicle.maxVolumeM3) {
      volExceeded = true;
      issues.add('Tổng thể tích các món (${totalVolume.toStringAsFixed(1)}m³) vượt quá dung tích thùng xe (${vehicle.maxVolumeM3.toStringAsFixed(1)}m³)');
    }

    final overallFits = !anyItemExceeded && !volExceeded;

    OrderVehicleType? suggested;
    if (!overallFits) {
      for (final v in OrderVehicleType.values) {
        if (v == vehicle) continue;
        final vBedDims = [v.bedLengthM, v.bedWidthM, v.bedHeightM]..sort();
        bool fitsThisV = totalVolume <= v.maxVolumeM3;
        if (fitsThisV) {
          for (final r in recipients) {
            if (r.hasDimensions) {
              final dims = [
                (r.lengthM ?? 0.1) > 0 ? r.lengthM! : 0.1,
                (r.widthM ?? 0.1) > 0 ? r.widthM! : 0.1,
                (r.heightM ?? 0.1) > 0 ? r.heightM! : 0.1,
              ]..sort();
              if (!(dims[0] <= vBedDims[0] && dims[1] <= vBedDims[1] && dims[2] <= vBedDims[2])) {
                fitsThisV = false;
                break;
              }
            }
          }
        }
        if (fitsThisV) {
          suggested = v;
          break;
        }
      }
      suggested ??= (vehicle != OrderVehicleType.container ? OrderVehicleType.container : null);
    }

    if (overallFits) {
      return CargoFitResult(
        fits: true,
        volumeExceeded: false,
        message: 'Tất cả món hàng tại ${recipients.length} điểm giao đều vừa vặn với thùng xe ${vehicle.name} (Tổng thể tích: ${totalVolume > 0 ? "${totalVolume.toStringAsFixed(2)}m³" : "đạt chuẩn"} / ${vehicle.maxVolumeM3}m³).',
      );
    } else {
      return CargoFitResult(
        fits: false,
        lengthExceeded: lenExceeded,
        widthExceeded: widExceeded,
        heightExceeded: heiExceeded,
        volumeExceeded: volExceeded,
        issues: issues,
        suggestedVehicle: suggested,
        message: issues.isNotEmpty ? issues.join(' • ') : 'Một số món hàng vượt quá giới hạn lọt lòng thùng xe.',
      );
    }
  }
}

enum PaymentMethod {
  cash(title: 'Tiền mặt', desc: 'Thanh toán khi lấy/giao hàng', iconName: 'cash'),
  momo(title: 'Ví MoMo', desc: 'Liên kết ví siêu tiện lợi', iconName: 'momo'),
  zalopay(title: 'ZaloPay', desc: 'Quét mã thanh toán tức thì', iconName: 'zalopay');

  final String title;
  final String desc;
  final String iconName;

  const PaymentMethod({
    required this.title,
    required this.desc,
    required this.iconName,
  });

  static PaymentMethod fromName(String? name) {
    if (name == null || name.trim().isEmpty) return PaymentMethod.cash;
    final lower = name.toLowerCase().trim();
    if (lower.contains('momo')) return PaymentMethod.momo;
    if (lower.contains('zalo')) return PaymentMethod.zalopay;
    if (lower.contains('tiền mặt') || lower.contains('tien mat') || lower.contains('cash') || lower.contains('cod')) {
      return PaymentMethod.cash;
    }
    for (final p in PaymentMethod.values) {
      if (p.name.toLowerCase() == lower || p.title.toLowerCase() == lower) {
        return p;
      }
    }
    return PaymentMethod.cash;
  }
}

class DropoffRecipient {
  String name;
  String phone;
  String note;
  String itemsDescription;
  double? lengthM;
  double? widthM;
  double? heightM;

  DropoffRecipient({
    this.name = '',
    this.phone = '',
    this.note = '',
    this.itemsDescription = '',
    this.lengthM,
    this.widthM,
    this.heightM,
  });

  double get volumeM3 => ((lengthM ?? 0) * (widthM ?? 0) * (heightM ?? 0));

  bool get hasDimensions =>
      (lengthM != null && lengthM! > 0) ||
      (widthM != null && widthM! > 0) ||
      (heightM != null && heightM! > 0);

  String get dimensionSummary {
    if (!hasDimensions) return '';
    final l = lengthM != null && lengthM! > 0 ? '${lengthM!.toStringAsFixed(1)}m' : '-';
    final w = widthM != null && widthM! > 0 ? '${widthM!.toStringAsFixed(1)}m' : '-';
    final h = heightM != null && heightM! > 0 ? '${heightM!.toStringAsFixed(1)}m' : '-';
    return '$l x $w x $h';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'note': note,
    'itemsDescription': itemsDescription,
    'lengthM': lengthM,
    'widthM': widthM,
    'heightM': heightM,
  };

  factory DropoffRecipient.fromJson(Map<String, dynamic> json) => DropoffRecipient(
    name: json['name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    note: json['note']?.toString() ?? '',
    itemsDescription: json['itemsDescription']?.toString() ?? '',
    lengthM: (json['lengthM'] as num?)?.toDouble(),
    widthM: (json['widthM'] as num?)?.toDouble(),
    heightM: (json['heightM'] as num?)?.toDouble(),
  );

  DropoffRecipient clone() => DropoffRecipient(
    name: name,
    phone: phone,
    note: note,
    itemsDescription: itemsDescription,
    lengthM: lengthM,
    widthM: widthM,
    heightM: heightM,
  );
}

class OrderDraftModel {
  String pickupAddress;
  List<String> dropoffAddresses;
  List<DropoffRecipient> dropoffRecipients;
  
  LatLng? pickupLatLng;
  List<LatLng?> dropoffLatLngs;
  List<LatLng> drivingRoutePoints;

  double distanceKm;
  int durationMinutes;

  String weightCategory; // '<100kg', '100-500kg', '500-1000kg', '>1000kg'
  String packageCategory; // 'Hàng tiêu chuẩn / Thùng carton', 'Hàng cồng kềnh / Quá khổ', 'Hàng dễ vỡ / Điện tử', 'Nội thất / Hàng gia dụng', 'Vật liệu xây dựng / Cơ khí', 'Nông sản / Thực phẩm'
  String senderName;
  String senderPhone;
  String driverNote;

  // Thông số kích thước kiện hàng (Dài x Rộng x Cao tính theo mét)
  double? packageLengthM;
  double? packageWidthM;
  double? packageHeightM;
  String packageDimensionDescription;

  OrderVehicleType vehicleType;
  PaymentMethod paymentMethod;
  String promoCode;
  double discountAmount;
  List<String> epodPhotos;
  String? packagePhotoBase64;
  SimulatedDriver? selectedDriver;

  OrderDraftModel({
    this.pickupAddress = '',
    List<String>? dropoffAddresses,
    List<DropoffRecipient>? dropoffRecipients,
    this.pickupLatLng,
    List<LatLng?>? dropoffLatLngs,
    List<LatLng>? drivingRoutePoints,
    this.distanceKm = 0.0,
    this.durationMinutes = 0,
    this.weightCategory = '<100kg',
    this.packageCategory = 'Hàng tiêu chuẩn / Thùng carton',
    this.senderName = '',
    this.senderPhone = '',
    String recipientName = '',
    String recipientPhone = '',
    this.driverNote = '',
    this.packageLengthM,
    this.packageWidthM,
    this.packageHeightM,
    this.packageDimensionDescription = '',
    this.vehicleType = OrderVehicleType.motorbike,
    this.paymentMethod = PaymentMethod.cash,
    this.promoCode = '',
    this.discountAmount = 0.0,
    List<String>? epodPhotos,
    this.packagePhotoBase64,
    this.selectedDriver,
  })  : dropoffAddresses = dropoffAddresses ?? [''],
        dropoffRecipients = dropoffRecipients ?? [
          DropoffRecipient(name: recipientName, phone: recipientPhone)
        ],
        dropoffLatLngs = dropoffLatLngs ?? [null],
        drivingRoutePoints = drivingRoutePoints ?? [],
        epodPhotos = epodPhotos ?? [] {
          syncRecipientsWithDropoffs();
        }

  void syncRecipientsWithDropoffs() {
    while (dropoffRecipients.length < dropoffAddresses.length) {
      dropoffRecipients.add(DropoffRecipient());
    }
    if (dropoffRecipients.length > dropoffAddresses.length && dropoffAddresses.isNotEmpty) {
      dropoffRecipients = dropoffRecipients.sublist(0, dropoffAddresses.length);
    }
  }

  String get recipientName {
    syncRecipientsWithDropoffs();
    return dropoffRecipients.isNotEmpty ? dropoffRecipients.first.name : '';
  }

  set recipientName(String val) {
    syncRecipientsWithDropoffs();
    if (dropoffRecipients.isNotEmpty) {
      dropoffRecipients.first.name = val;
    }
  }

  String get recipientPhone {
    syncRecipientsWithDropoffs();
    return dropoffRecipients.isNotEmpty ? dropoffRecipients.first.phone : '';
  }

  set recipientPhone(String val) {
    syncRecipientsWithDropoffs();
    if (dropoffRecipients.isNotEmpty) {
      dropoffRecipients.first.phone = val;
    }
  }

  String get dropoffAddress => dropoffAddresses.isNotEmpty ? dropoffAddresses.first : '';
  set dropoffAddress(String val) {
    if (dropoffAddresses.isEmpty) {
      dropoffAddresses.add(val);
    } else {
      dropoffAddresses[0] = val;
    }
  }

  int get stopCount => dropoffAddresses.length;

  int get multiStopSurcharge {
    if (dropoffAddresses.length > 1) {
      return (dropoffAddresses.length - 1) * 10000;
    }
    return 0;
  }

  int get baseDeliveryFee {
    final effectiveDist = distanceKm > 0 ? distanceKm : 3.0;
    final raw = (vehicleType.baseFee + (effectiveDist * vehicleType.perKmFee)) * vehicleType.peakMultiplier;
    final rounded = raw.round();
    return rounded < vehicleType.minFee ? vehicleType.minFee : rounded;
  }

  int get weightSurcharge {
    switch (weightCategory) {
      case '100-500kg':
        return 15000;
      case '500-1000kg':
        return 35000;
      case '>1000kg':
        return 70000;
      case '15-30kg':
        return 10000;
      case '>30kg':
        return 25000;
      default:
        return 0;
    }
  }

  int get totalFeeBeforeDiscount {
    return baseDeliveryFee + weightSurcharge + multiStopSurcharge;
  }

  int get finalTotalFee {
    final total = totalFeeBeforeDiscount - discountAmount.round();
    return total > 0 ? total : 0;
  }

  void reorderDropoffs(int oldIndex, int newIndex) {
    syncRecipientsWithDropoffs();
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = dropoffAddresses.removeAt(oldIndex);
    dropoffAddresses.insert(newIndex, item);

    if (oldIndex < dropoffLatLngs.length && newIndex <= dropoffLatLngs.length) {
      final LatLng? coord = dropoffLatLngs.removeAt(oldIndex);
      dropoffLatLngs.insert(newIndex, coord);
    }

    if (oldIndex < dropoffRecipients.length && newIndex <= dropoffRecipients.length) {
      final DropoffRecipient rec = dropoffRecipients.removeAt(oldIndex);
      dropoffRecipients.insert(newIndex, rec);
    }
  }

  double get totalCargoVolumeM3 {
    syncRecipientsWithDropoffs();
    if (dropoffAddresses.length > 1) {
      return dropoffRecipients.fold<double>(0.0, (sum, r) => sum + r.volumeM3);
    }
    return ((packageLengthM ?? 0) * (packageWidthM ?? 0) * (packageHeightM ?? 0));
  }

  double get maxCargoLengthM {
    syncRecipientsWithDropoffs();
    if (dropoffAddresses.length > 1) {
      double maxL = 0.0;
      for (final r in dropoffRecipients) {
        if ((r.lengthM ?? 0) > maxL) maxL = r.lengthM!;
      }
      return maxL > 0 ? maxL : (packageLengthM ?? 0.0);
    }
    return packageLengthM ?? 0.0;
  }

  double get maxCargoWidthM {
    syncRecipientsWithDropoffs();
    if (dropoffAddresses.length > 1) {
      double maxW = 0.0;
      for (final r in dropoffRecipients) {
        if ((r.widthM ?? 0) > maxW) maxW = r.widthM!;
      }
      return maxW > 0 ? maxW : (packageWidthM ?? 0.0);
    }
    return packageWidthM ?? 0.0;
  }

  double get maxCargoHeightM {
    syncRecipientsWithDropoffs();
    if (dropoffAddresses.length > 1) {
      double maxH = 0.0;
      for (final r in dropoffRecipients) {
        if ((r.heightM ?? 0) > maxH) maxH = r.heightM!;
      }
      return maxH > 0 ? maxH : (packageHeightM ?? 0.0);
    }
    return packageHeightM ?? 0.0;
  }

  String generateLifoStowageSummary() {
    syncRecipientsWithDropoffs();
    if (dropoffAddresses.length <= 1) {
      final item = (dropoffRecipients.isNotEmpty && dropoffRecipients.first.itemsDescription.isNotEmpty)
          ? dropoffRecipients.first.itemsDescription
          : (packageDimensionDescription.isNotEmpty ? packageDimensionDescription : 'Kiện hàng');
      return '[Sơ đồ xếp xe LIFO]: Cửa sau (dỡ điểm nhận): $item';
    }

    final steps = <String>[];
    for (int i = 0; i < dropoffAddresses.length; i++) {
      final r = i < dropoffRecipients.length ? dropoffRecipients[i] : null;
      final itemName = (r != null && r.itemsDescription.isNotEmpty)
          ? r.itemsDescription
          : 'Hàng điểm ${i + 1}';
      if (i == 0) {
        steps.add('Cửa sau (dỡ đầu tiên tại Điểm 1): $itemName');
      } else if (i == dropoffAddresses.length - 1) {
        steps.add('Sát cabin (dỡ sau cùng tại Điểm ${i + 1}): $itemName');
      } else {
        steps.add('Giữa thùng xe (dỡ tại Điểm ${i + 1}): $itemName');
      }
    }
    return '[Sơ đồ xếp xe LIFO]: ${steps.join(" • ")}';
  }

  CargoFitResult checkCargoFit() {
    if (dropoffAddresses.length > 1) {
      return CargoFitResult.analyzeMultiDrop(
        vehicle: vehicleType,
        recipients: dropoffRecipients,
        dropoffAddresses: dropoffAddresses,
      );
    }
    return CargoFitResult.analyze(
      vehicle: vehicleType,
      length: packageLengthM ?? 0.0,
      width: packageWidthM ?? 0.0,
      height: packageHeightM ?? 0.0,
    );
  }
}
