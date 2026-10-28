import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/customer/order/models/order_draft_model.dart';

enum OrderStatus {
  pending('Đang tìm xe', 'Đang tìm tài xế'),
  pendingDirect('Chờ tài xế', 'Chờ tài xế xác nhận'),
  delivering('Đang giao', 'Đang giao'),
  completed('Hoàn thành', 'Đã hoàn thành'),
  cancelled('Đã hủy', 'Đã hủy');

  final String label;
  final String fullLabel;
  const OrderStatus(this.label, this.fullLabel);

  static OrderStatus fromString(String? val) {
    if (val == null) return OrderStatus.delivering;
    for (final s in OrderStatus.values) {
      if (s.name == val || s.label == val || s.fullLabel == val) return s;
    }
    return OrderStatus.delivering;
  }
}

class OrderRecord {
  final String orderCode;
  final DateTime createdAt;
  final OrderStatus status;
  final String pickupAddress;
  final List<String> dropoffAddresses;
  final String vehicleName;
  final String packageCategory;
  final String weightCategory;
  final int totalFee;
  final String senderName;
  final String senderPhone;
  final String recipientName;
  final String recipientPhone;
  final String driverNote;
  final double distanceKm;
  final int durationMinutes;
  final double? pickupLat;
  final double? pickupLng;
  final List<double>? dropoffLats;
  final List<double>? dropoffLngs;
  final List<List<double>>? routeCoords;
  final List<String> epodPhotos;
  final List<DropoffRecipient> dropoffRecipients;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;
  final DateTime? completedAt;
  final int? customerRating;
  final String? customerComment;
  final List<String>? customerTags;
  final int? driverRating;
  final String? driverComment;
  final List<String>? driverTags;
  final String paymentMethod;
  final String? promoCode;
  final int discountAmount;
  final int? originalFee;
  final String? packagePhotoBase64;

  OrderRecord({
    required this.orderCode,
    required this.createdAt,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddresses,
    required this.vehicleName,
    required this.packageCategory,
    required this.weightCategory,
    required this.totalFee,
    required this.senderName,
    required this.senderPhone,
    required this.recipientName,
    required this.recipientPhone,
    required this.driverNote,
    required this.distanceKm,
    required this.durationMinutes,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLats,
    this.dropoffLngs,
    this.routeCoords,
    this.epodPhotos = const [],
    this.dropoffRecipients = const [],
    this.assignedDriverId,
    this.assignedDriverName,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPlate,
    this.completedAt,
    this.customerRating,
    this.customerComment,
    this.customerTags,
    this.driverRating,
    this.driverComment,
    this.driverTags,
    this.paymentMethod = 'Tiền mặt',
    this.promoCode,
    this.discountAmount = 0,
    this.originalFee,
    this.packagePhotoBase64,
  });

  OrderRecord copyWith({
    String? orderCode,
    DateTime? createdAt,
    OrderStatus? status,
    String? pickupAddress,
    List<String>? dropoffAddresses,
    String? vehicleName,
    String? packageCategory,
    String? weightCategory,
    int? totalFee,
    String? senderName,
    String? senderPhone,
    String? recipientName,
    String? recipientPhone,
    String? driverNote,
    double? distanceKm,
    int? durationMinutes,
    double? pickupLat,
    double? pickupLng,
    List<double>? dropoffLats,
    List<double>? dropoffLngs,
    List<List<double>>? routeCoords,
    List<String>? epodPhotos,
    List<DropoffRecipient>? dropoffRecipients,
    String? assignedDriverId,
    String? assignedDriverName,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
    DateTime? completedAt,
    int? customerRating,
    String? customerComment,
    List<String>? customerTags,
    int? driverRating,
    String? driverComment,
    List<String>? driverTags,
    String? paymentMethod,
    String? promoCode,
    int? discountAmount,
    int? originalFee,
    String? packagePhotoBase64,
  }) {
    return OrderRecord(
      orderCode: orderCode ?? this.orderCode,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddresses: dropoffAddresses ?? this.dropoffAddresses,
      vehicleName: vehicleName ?? this.vehicleName,
      packageCategory: packageCategory ?? this.packageCategory,
      weightCategory: weightCategory ?? this.weightCategory,
      totalFee: totalFee ?? this.totalFee,
      senderName: senderName ?? this.senderName,
      senderPhone: senderPhone ?? this.senderPhone,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      driverNote: driverNote ?? this.driverNote,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLats: dropoffLats ?? this.dropoffLats,
      dropoffLngs: dropoffLngs ?? this.dropoffLngs,
      routeCoords: routeCoords ?? this.routeCoords,
      epodPhotos: epodPhotos ?? this.epodPhotos,
      dropoffRecipients: dropoffRecipients ?? this.dropoffRecipients,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverPlate: driverPlate ?? this.driverPlate,
      completedAt: completedAt ?? this.completedAt,
      customerRating: customerRating ?? this.customerRating,
      customerComment: customerComment ?? this.customerComment,
      customerTags: customerTags ?? this.customerTags,
      driverRating: driverRating ?? this.driverRating,
      driverComment: driverComment ?? this.driverComment,
      driverTags: driverTags ?? this.driverTags,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      promoCode: promoCode ?? this.promoCode,
      discountAmount: discountAmount ?? this.discountAmount,
      originalFee: originalFee ?? this.originalFee,
      packagePhotoBase64: packagePhotoBase64 ?? this.packagePhotoBase64,
    );
  }

  Map<String, dynamic> toJson() => {
        'orderCode': orderCode,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'pickupAddress': pickupAddress,
        'dropoffAddresses': dropoffAddresses,
        'vehicleName': vehicleName,
        'packageCategory': packageCategory,
        'weightCategory': weightCategory,
        'totalFee': totalFee,
        'senderName': senderName,
        'senderPhone': senderPhone,
        'recipientName': recipientName,
        'recipientPhone': recipientPhone,
        'driverNote': driverNote,
        'distanceKm': distanceKm,
        'durationMinutes': durationMinutes,
        'pickupLat': pickupLat,
        'pickupLng': pickupLng,
        'dropoffLats': dropoffLats,
        'dropoffLngs': dropoffLngs,
        'routeCoords': routeCoords,
        'epodPhotos': epodPhotos,
        'dropoffRecipients': dropoffRecipients.map((r) => r.toJson()).toList(),
        'assignedDriverId': assignedDriverId,
        'assignedDriverName': assignedDriverName,
        'driverId': driverId,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverPlate': driverPlate,
        'completedAt': completedAt?.toIso8601String(),
        'customerRating': customerRating,
        'customerComment': customerComment,
        'customerTags': customerTags,
        'driverRating': driverRating,
        'driverComment': driverComment,
        'driverTags': driverTags,
        'paymentMethod': paymentMethod,
        'promoCode': promoCode,
        'discountAmount': discountAmount,
        'originalFee': originalFee ?? totalFee,
        'packagePhotoBase64': packagePhotoBase64,
      };

  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
        orderCode: json['orderCode'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        status: OrderStatus.fromString(json['status']),
        pickupAddress: json['pickupAddress'] ?? '',
        dropoffAddresses: List<String>.from(json['dropoffAddresses'] ?? []),
        vehicleName: json['vehicleName'] ?? 'Xe Bán tải',
        packageCategory: json['packageCategory'] ?? 'Hàng tiêu chuẩn',
        weightCategory: json['weightCategory'] ?? '<100kg',
        totalFee: (json['totalFee'] as num?)?.toInt() ?? 0,
        senderName: json['senderName'] ?? '',
        senderPhone: json['senderPhone'] ?? '',
        recipientName: json['recipientName'] ?? '',
        recipientPhone: json['recipientPhone'] ?? '',
        driverNote: json['driverNote'] ?? '',
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
        durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
        pickupLat: (json['pickupLat'] as num?)?.toDouble(),
        pickupLng: (json['pickupLng'] as num?)?.toDouble(),
        dropoffLats: (json['dropoffLats'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        dropoffLngs: (json['dropoffLngs'] as List?)?.map((e) => (e as num).toDouble()).toList(),
        routeCoords: (json['routeCoords'] as List?)
            ?.map((e) => (e as List).map((c) => (c as num).toDouble()).toList())
            .toList(),
        epodPhotos: List<String>.from(json['epodPhotos'] ?? []),
        dropoffRecipients: (json['dropoffRecipients'] as List?)
                ?.map((e) => DropoffRecipient.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        assignedDriverId: json['assignedDriverId'],
        assignedDriverName: json['assignedDriverName'],
        driverId: json['driverId'],
        driverName: json['driverName'],
        driverPhone: json['driverPhone'],
        driverPlate: json['driverPlate'],
        completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
        customerRating: (json['customerRating'] as num?)?.toInt(),
        customerComment: json['customerComment'],
        customerTags: json['customerTags'] != null ? List<String>.from(json['customerTags']) : null,
        driverRating: (json['driverRating'] as num?)?.toInt(),
        driverComment: json['driverComment'],
        driverTags: json['driverTags'] != null ? List<String>.from(json['driverTags']) : null,
        paymentMethod: json['paymentMethod'] ?? 'Tiền mặt',
        promoCode: json['promoCode'],
        discountAmount: (json['discountAmount'] as num?)?.toInt() ?? 0,
        originalFee: (json['originalFee'] as num?)?.toInt(),
        packagePhotoBase64: json['packagePhotoBase64'],
      );

  factory OrderRecord.fromDraft({
    required OrderDraftModel draft,
    required String orderCode,
    OrderStatus status = OrderStatus.delivering,
    List<String> epodPhotos = const [],
    String? assignedDriverId,
    String? assignedDriverName,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverPlate,
  }) =>
      OrderRecord(
        orderCode: orderCode,
        createdAt: DateTime.now(),
        status: status,
        pickupAddress: draft.pickupAddress,
        dropoffAddresses: draft.dropoffAddresses,
        vehicleName: draft.vehicleType.name,
        packageCategory: draft.packageCategory,
        weightCategory: draft.weightCategory,
        totalFee: draft.finalTotalFee,
        senderName: draft.senderName,
        senderPhone: draft.senderPhone,
        recipientName: draft.recipientName,
        recipientPhone: draft.recipientPhone,
        driverNote: draft.driverNote,
        distanceKm: draft.distanceKm,
        durationMinutes: draft.durationMinutes,
        pickupLat: draft.pickupLatLng?.latitude,
        pickupLng: draft.pickupLatLng?.longitude,
        dropoffLats: draft.dropoffLatLngs.where((l) => l != null).map((l) => l!.latitude).toList(),
        dropoffLngs: draft.dropoffLatLngs.where((l) => l != null).map((l) => l!.longitude).toList(),
        routeCoords: draft.drivingRoutePoints.map((p) => [p.latitude, p.longitude]).toList(),
        epodPhotos: epodPhotos.isNotEmpty ? epodPhotos : draft.epodPhotos,
        dropoffRecipients: draft.dropoffRecipients.map((r) => r.clone()).toList(),
        assignedDriverId: assignedDriverId,
        assignedDriverName: assignedDriverName,
        driverId: driverId,
        driverName: driverName,
        driverPhone: driverPhone,
        driverPlate: driverPlate,
        paymentMethod: draft.paymentMethod.title,
        promoCode: draft.promoCode.isNotEmpty ? draft.promoCode : null,
        discountAmount: draft.discountAmount.round(),
        originalFee: draft.totalFeeBeforeDiscount,
        packagePhotoBase64: draft.packagePhotoBase64,
      );
}

class OrderRepository {
  static const String _key = 'goship_order_history_v2';

  static final List<OrderRecord> _defaultMockOrders = [
    OrderRecord(
      orderCode: 'GS-8912-VN',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      status: OrderStatus.delivering,
      pickupAddress: 'Landmark 81, Vinhomes Central Park, Bình Thạnh',
      dropoffAddresses: ['25 Điện Biên Phủ, Phường Võ Thị Sáu, Quận 3'],
      vehicleName: 'Xe Bán tải',
      packageCategory: 'Hàng tiêu chuẩn / Thùng carton',
      weightCategory: '<100kg',
      totalFee: 48500,
      senderName: 'Nguyễn Hữu Nhựt',
      senderPhone: '0917795211',
      recipientName: 'Trần Minh Tâm',
      recipientPhone: '0908123456',
      driverNote: 'Hàng dễ vỡ xin nhẹ tay',
      distanceKm: 4.8,
      durationMinutes: 18,
      pickupLat: 10.7946,
      pickupLng: 106.7218,
      dropoffLats: [10.7825],
      dropoffLngs: [106.6905],
    ),
    OrderRecord(
      orderCode: 'GS-7341-VN',
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      status: OrderStatus.completed,
      pickupAddress: '123 Lê Lợi, Phường Bến Thành, Quận 1',
      dropoffAddresses: [
        '78 Võ Văn Tần, Phường 6, Quận 3',
        'Tòa nhà Bitexco, 02 Hải Triều, Quận 1'
      ],
      vehicleName: 'Xe van',
      packageCategory: 'Nội thất / Hàng gia dụng',
      weightCategory: '100-500kg',
      totalFee: 125000,
      senderName: 'Nguyễn Hữu Nhựt',
      senderPhone: '0917795211',
      recipientName: 'Lê Hoàng Yến',
      recipientPhone: '0912345678',
      driverNote: 'Đã giao đủ 2 điểm',
      distanceKm: 8.5,
      durationMinutes: 32,
      pickupLat: 10.7725,
      pickupLng: 106.6980,
      dropoffLats: [10.7780, 10.7716],
      dropoffLngs: [106.6900, 106.7044],
      epodPhotos: [
        'mock_photo_goods',
        'mock_photo_signature',
        'mock_photo_seal',
      ],
    ),
    OrderRecord(
      orderCode: 'GS-6102-VN',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      status: OrderStatus.completed,
      pickupAddress: 'Kho bãi KCN Tân Bình, TP. HCM',
      dropoffAddresses: ['Chợ Bến Thành, Quận 1, TP. HCM'],
      vehicleName: 'Xe tải',
      packageCategory: 'Vật liệu xây dựng / Cơ khí',
      weightCategory: '500-1000kg',
      totalFee: 280000,
      senderName: 'Nguyễn Hữu Nhựt',
      senderPhone: '0917795211',
      recipientName: 'Đặng Tuấn Anh',
      recipientPhone: '0933888999',
      driverNote: 'Cần bốc dỡ tầng trệt',
      distanceKm: 14.2,
      durationMinutes: 45,
      pickupLat: 10.8150,
      pickupLng: 106.6320,
      dropoffLats: [10.7719],
      dropoffLngs: [106.6983],
      epodPhotos: [
        'mock_photo_goods',
        'mock_photo_signature',
      ],
    ),
  ];

  static Future<List<OrderRecord>> getOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        return list.map((item) => OrderRecord.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('>>> [OrderRepository getOrders Error]: $e');
    }
    return _defaultMockOrders;
  }

  static Future<void> saveOrder(OrderRecord order) async {
    try {
      final orders = await getOrders();
      orders.insert(0, order); // Most recent first
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(orders.map((o) => o.toJson()).toList()));
      debugPrint('>>> [OrderRepository]: Order ${order.orderCode} saved successfully.');
    } catch (e) {
      debugPrint('>>> [OrderRepository saveOrder Error]: $e');
    }
  }

  static Future<void> updateOrderStatus(
    String orderCode,
    OrderStatus newStatus, {
    List<String>? epodPhotos,
  }) async {
    try {
      final orders = await getOrders();
      final idx = orders.indexWhere((o) => o.orderCode == orderCode);
      if (idx >= 0) {
        final current = orders[idx];
        orders[idx] = current.copyWith(
          status: newStatus,
          epodPhotos: epodPhotos ?? current.epodPhotos,
          completedAt: newStatus == OrderStatus.completed ? DateTime.now() : current.completedAt,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(orders.map((o) => o.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('>>> [OrderRepository updateOrderStatus Error]: $e');
    }
  }

  static Future<void> updateCustomerRating(
    String orderCode, {
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final orders = await getOrders();
      final idx = orders.indexWhere((o) => o.orderCode == orderCode);
      if (idx >= 0) {
        orders[idx] = orders[idx].copyWith(
          customerRating: rating,
          customerComment: comment,
          customerTags: tags,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(orders.map((o) => o.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('>>> [OrderRepository updateCustomerRating Error]: $e');
    }
  }

  static Future<void> updateDriverRating(
    String orderCode, {
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final orders = await getOrders();
      final idx = orders.indexWhere((o) => o.orderCode == orderCode);
      if (idx >= 0) {
        orders[idx] = orders[idx].copyWith(
          driverRating: rating,
          driverComment: comment,
          driverTags: tags,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_key, jsonEncode(orders.map((o) => o.toJson()).toList()));
      }
    } catch (e) {
      debugPrint('>>> [OrderRepository updateDriverRating Error]: $e');
    }
  }

  static Future<OrderRecord?> getOrderByCode(String orderCode) async {
    try {
      final orders = await getOrders();
      final idx = orders.indexWhere((o) => o.orderCode == orderCode);
      if (idx >= 0) return orders[idx];
    } catch (e) {
      debugPrint('>>> [OrderRepository getOrderByCode Error]: $e');
    }
    return null;
  }
}
