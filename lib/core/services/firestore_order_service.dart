import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../../features/customer/order/models/order_draft_model.dart';
import 'cloud_media_service.dart';
import 'order_repository.dart';

class FirestoreOrderService {
  static FirebaseFirestore? _customFirestore;

  @visibleForTesting
  static void setFirestoreInstance(FirebaseFirestore? firestore) {
    _customFirestore = firestore;
  }

  static FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>>? get _ordersCol {
    final fs = _firestore;
    if (fs == null) return null;
    try {
      return fs.collection('orders');
    } catch (_) {
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>>? get _driversCol {
    final fs = _firestore;
    if (fs == null) return null;
    try {
      return fs.collection('driver_tracking');
    } catch (_) {
      return null;
    }
  }

  static CollectionReference<Map<String, dynamic>>? get _walletsCol {
    final fs = _firestore;
    if (fs == null) return null;
    try {
      return fs.collection('driver_wallets');
    } catch (_) {
      return null;
    }
  }

  static const Distance _geoDistance = Distance();

  // ==================== 1. CUSTOMER: TẠO ĐƠN & THEO DÕI ====================

  /// Tạo đơn hàng mới lên Firestore
  /// [assignedDriverId]: Nếu khách hàng chọn đích danh 1 tài xế lân cận
  /// [directTimeoutSeconds]: Thời gian ưu tiên cho tài xế chỉ định (mặc định 45s)
  static Future<bool> createOrder({
    required OrderRecord order,
    String? assignedDriverId,
    String? assignedDriverName,
    int directTimeoutSeconds = 45,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) {
        debugPrint('>>> [FirestoreOrderService]: Firestore not initialized, saving local.');
        await OrderRepository.saveOrder(order);
        return true;
      }
      final isDirect = assignedDriverId != null && assignedDriverId.isNotEmpty;
      final now = DateTime.now();
      final directExpiresAt = isDirect
          ? now.add(Duration(seconds: directTimeoutSeconds))
          : null;

      final optimizedPackagePhoto = await CloudMediaService.ensureCloudPortableImage(
        order.packagePhotoBase64,
        category: 'cargo',
        ownerId: order.orderCode,
        maxDimension: 720,
      );

      final data = {
        'order_id': order.orderCode,
        'orderCode': order.orderCode,
        'createdAt': FieldValue.serverTimestamp(),
        'created_at_millis': now.millisecondsSinceEpoch,
        'status': isDirect ? 'pendingDirect' : 'pending',
        'dispatch_type': isDirect ? 'DIRECT' : 'OPEN_MARKET',
        'assigned_driver_id': assignedDriverId,
        'assigned_driver_name': assignedDriverName,
        'direct_expires_at': directExpiresAt?.millisecondsSinceEpoch,
        'driver_id': null,
        'driver_name': null,
        'driver_phone': null,
        'driver_plate': null,
        'driver_vehicle': null,
        'pickup_address': order.pickupAddress,
        'pickup_lat': order.pickupLat ?? 10.7725,
        'pickup_lng': order.pickupLng ?? 106.6980,
        'sender_name': order.senderName,
        'sender_phone': order.senderPhone,
        'dropoff_addresses': order.dropoffAddresses,
        'dropoff_lats': order.dropoffLats,
        'dropoff_lngs': order.dropoffLngs,
        'recipient_name': order.recipientName,
        'recipient_phone': order.recipientPhone,
        'vehicle_name': order.vehicleName,
        'package_category': order.packageCategory,
        'weight_category': order.weightCategory,
        'total_fee': order.totalFee,
        'original_fee': order.originalFee ?? order.totalFee,
        'discount_amount': order.discountAmount,
        'promo_code': order.promoCode,
        'payment_method': order.paymentMethod,
        'package_photo_base64': optimizedPackagePhoto,
        'driver_note': order.driverNote,
        'distance_km': order.distanceKm,
        'duration_minutes': order.durationMinutes,
        'route_coords': order.routeCoords?.map((c) => {'lat': c[0], 'lng': c[1]}).toList(),
        'epod_photos': order.epodPhotos,
        'dropoff_recipients': order.dropoffRecipients.map((r) => r.toJson()).toList(),
      };

      await col.doc(order.orderCode).set(data);
      // Lưu bản sao cục bộ để fallback
      await OrderRepository.saveOrder(order);
      debugPrint('>>> [FirestoreOrderService]: Created order ${order.orderCode} successfully in Firestore!');
      return true;
    } catch (e, st) {
      debugPrint('>>> [FirestoreOrderService createOrder FAILED]: $e\n$st');
      // Fallback lưu local nếu mất mạng
      await OrderRepository.saveOrder(order);
      return false;
    }
  }

  /// Stream danh sách đơn hàng của khách hàng theo số điện thoại hoặc mã khách
  static Stream<List<OrderRecord>> streamCustomerOrders(String customerPhone) {
    try {
      final col = _ordersCol;
      if (col == null) return const Stream.empty();
      return col
          .where('sender_phone', isEqualTo: customerPhone)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          return _mapFirestoreToOrderRecord(data);
        }).toList();

        // Sort latest first
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamCustomerOrders Error]: $e');
      return const Stream.empty();
    }
  }

  /// Stream đơn hàng chi tiết theo mã vận đơn
  static Stream<OrderRecord?> streamOrderDetail(String orderCode) {
    try {
      final col = _ordersCol;
      if (col == null) return const Stream.empty();
      return col.doc(orderCode).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return _mapFirestoreToOrderRecord(doc.data()!);
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamOrderDetail Error]: $e');
      return const Stream.empty();
    }
  }

  // ==================== 2. DRIVER: NHẬN ĐƠN & ĐIỀU HƯỚNG ====================

  /// Stream danh sách đơn hàng khả dụng cho tài xế:
  /// - Đơn thị trường mở (status == 'pending')
  /// - HOẶC đơn chỉ định đích danh cho tài xế này (status == 'pendingDirect' && assigned_driver_id == driverId)
  /// - Tự động fallback: Nếu đơn chỉ định đã hết hạn 45s, tự chuyển sang thị trường mở
  static Stream<List<Map<String, dynamic>>> streamAvailableOrdersForDriver({
    required String driverId,
    LatLng? driverLocation,
  }) {
    try {
      final col = _ordersCol;
      if (col == null) return const Stream.empty();
      return col
          .where('status', whereIn: ['pending', 'pendingDirect'])
          .snapshots()
          .map((snapshot) {
        final List<Map<String, dynamic>> results = [];
        final int nowMillis = DateTime.now().millisecondsSinceEpoch;

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final String status = data['status'] ?? 'pending';
          final String? assignedDriverId = data['assigned_driver_id'];
          final int? directExpiresAt = data['direct_expires_at'];

          // Ẩn đơn hàng nếu tài xế này đã từng từ chối / hủy cuốc trước đó
          final rejectedIds = List<String>.from(data['rejected_by_driver_ids'] ?? []);
          if (rejectedIds.contains(driverId)) {
            continue;
          }

          bool isEligible = false;
          bool isDirectToMe = false;

          if (status == 'pending') {
            // Đơn mở tự do: Mọi tài xế đều nhận được
            isEligible = true;
          } else if (status == 'pendingDirect') {
            if (assignedDriverId == driverId) {
              // Đúng tài xế được chỉ định
              if (directExpiresAt != null && nowMillis > directExpiresAt) {
                // Đã hết 45s mà chưa nhận -> Chuyển thành đơn mở
                isEligible = true;
                unawaited(_fallbackToOpenMarket(doc.id));
              } else {
                isEligible = true;
                isDirectToMe = true;
              }
            } else {
              // Tài xế khác chỉ định, kiểm tra xem đã quá hạn 45s chưa
              if (directExpiresAt != null && nowMillis > directExpiresAt) {
                isEligible = true;
                unawaited(_fallbackToOpenMarket(doc.id));
              }
            }
          }

          if (isEligible) {
            final double pLat = (data['pickup_lat'] as num?)?.toDouble() ?? 10.7725;
            final double pLng = (data['pickup_lng'] as num?)?.toDouble() ?? 106.6980;
            final dropLats = data['dropoff_lats'] as List?;
            final dropLngs = data['dropoff_lngs'] as List?;
            final double dLat = (dropLats != null && dropLats.isNotEmpty) ? (dropLats.first as num).toDouble() : 10.7850;
            final double dLng = (dropLngs != null && dropLngs.isNotEmpty) ? (dropLngs.first as num).toDouble() : 106.7450;

            final List<LatLng> dropoffCoords = [];
            if (dropLats != null && dropLngs != null) {
              for (int i = 0; i < dropLats.length && i < dropLngs.length; i++) {
                final lat = (dropLats[i] as num).toDouble();
                final lng = (dropLngs[i] as num).toDouble();
                dropoffCoords.add(LatLng(lat, lng));
              }
            }
            if (dropoffCoords.isEmpty) {
              dropoffCoords.add(LatLng(dLat, dLng));
            }

            final dropAddresses = List<String>.from(data['dropoff_addresses'] ?? []);
            final dropStr = dropAddresses.isNotEmpty ? dropAddresses.join(' -> ') : 'Chưa rõ điểm giao';

            // Trích xuất chi tiết hàng hóa từ dropoff_recipients
            final rawDropoffs = data['dropoff_recipients'] as List?;
            final List<String> itemDescriptions = [];
            final List<String> itemDims = [];
            if (rawDropoffs != null && rawDropoffs.isNotEmpty) {
              for (final item in rawDropoffs) {
                if (item is Map) {
                  final desc = item['itemsDescription']?.toString() ?? '';
                  if (desc.trim().isNotEmpty) itemDescriptions.add(desc.trim());

                  final l = (item['lengthM'] as num?)?.toDouble();
                  final w = (item['widthM'] as num?)?.toDouble();
                  final h = (item['heightM'] as num?)?.toDouble();
                  if ((l != null && l > 0) || (w != null && w > 0) || (h != null && h > 0)) {
                    final ls = l != null && l > 0 ? '${l.toStringAsFixed(1)}m' : '-';
                    final ws = w != null && w > 0 ? '${w.toStringAsFixed(1)}m' : '-';
                    final hs = h != null && h > 0 ? '${h.toStringAsFixed(1)}m' : '-';
                    itemDims.add('$ls x $ws x $hs');
                  }
                }
              }
            }

            final String vehicleName = data['vehicle_name'] ?? 'Xe Bán tải';
            final String packageCategory = data['package_category'] ?? 'Hàng tiêu chuẩn';
            final String weightCategory = data['weight_category'] ?? '<100kg';
            final String driverNote = data['driver_note'] ?? '';
            final String itemsDetail = itemDescriptions.isNotEmpty ? itemDescriptions.join(', ') : '';
            final String dimensions = itemDims.isNotEmpty ? itemDims.join(', ') : '';

            final LatLng pickupCoord = LatLng(pLat, pLng);
            final double distanceToPickupKm = driverLocation != null
                ? double.parse(
                    (_geoDistance.as(LengthUnit.Meter, driverLocation, pickupCoord) / 1000.0)
                        .toStringAsFixed(1),
                  )
                : 0.0;

            results.add({
              'id': data['order_id'] ?? doc.id,
              'orderCode': data['order_id'] ?? doc.id,
              'pickup': data['pickup_address'] ?? '',
              'dropoff': dropStr,
              'dropoffAddresses': dropAddresses,
              'pickupCoord': pickupCoord,
              'dropoffCoord': LatLng(dLat, dLng),
              'dropoffCoords': dropoffCoords,
              'fee': '${(data['total_fee'] ?? 0).toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} đ',
              'rawFee': data['total_fee'] ?? 0,
              'originalFee': (data['original_fee'] as num?)?.toInt() ?? (data['total_fee'] as num?)?.toInt() ?? 0,
              'discountAmount': (data['discount_amount'] as num?)?.toInt() ?? 0,
              'promoCode': data['promo_code'] ?? data['promoCode'],
              'paymentMethod': data['payment_method'] ?? data['paymentMethod'] ?? 'Tiền mặt',
              'packagePhotoBase64': data['package_photo_base64'] ?? data['packagePhotoBase64'],
              'distance': '${data['distance_km'] ?? 0.0} km',
              'distanceToPickupKm': distanceToPickupKm,
              'customer': data['sender_name'] ?? 'Khách hàng GoShip',
              'phone': data['sender_phone'] ?? '',
              'recipientName': data['recipient_name'] ?? '',
              'recipientPhone': data['recipient_phone'] ?? '',
              'package': '$packageCategory ($weightCategory)',
              'packageCategory': packageCategory,
              'weightCategory': weightCategory,
              'vehicleName': vehicleName,
              'driverNote': driverNote,
              'itemsDetail': itemsDetail,
              'dimensions': dimensions,
              'dropoffRecipients': rawDropoffs ?? [],
              'isDirect': isDirectToMe,
              'directExpiresAt': directExpiresAt,
              'routeCoords': data['route_coords'],
            });
          }
        }

        // Sắp xếp ưu tiên: Đơn chỉ định đích danh (isDirect) lên đầu, sau đó tới khoảng cách lấy hàng gần nhất
        results.sort((a, b) {
          final bool dirA = a['isDirect'] == true;
          final bool dirB = b['isDirect'] == true;
          if (dirA != dirB) return dirA ? -1 : 1;
          final double distA = (a['distanceToPickupKm'] as num?)?.toDouble() ?? 0.0;
          final double distB = (b['distanceToPickupKm'] as num?)?.toDouble() ?? 0.0;
          return distA.compareTo(distB);
        });

        return results;
      }).handleError((e) {
        debugPrint('>>> [FirestoreOrderService streamAvailableOrdersForDriver Error]: $e');
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamAvailableOrdersForDriver Error]: $e');
      return const Stream.empty();
    }
  }

  /// Tự động chuyển đơn chỉ định thành đơn thị trường mở khi hết 45s
  static Future<void> _fallbackToOpenMarket(String orderId) async {
    try {
      final col = _ordersCol;
      if (col == null) return;
      await col.doc(orderId).update({
        'status': 'pending',
        'dispatch_type': 'OPEN_MARKET',
        'assigned_driver_id': null,
      });
      debugPrint('>>> [FirestoreOrderService]: Order $orderId timed out direct dispatch -> converted to OPEN_MARKET.');
    } catch (_) {}
  }

  /// Tài xế nhận cuốc trên Sàn chung hoặc Chỉ định (Dùng Firestore Transaction nguyên tử để chống race condition)
  static Future<bool> acceptOrder({
    required String orderCode,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String plateNumber,
    required String vehicleName,
  }) async {
    try {
      final fs = _firestore;
      final col = _ordersCol;
      if (fs == null || col == null) {
        // Fallback local memory & repository khi offline hoặc chưa kết nối Firestore
        final localOrder = await OrderRepository.getOrderByCode(orderCode);
        if (localOrder != null) {
          if (localOrder.status != OrderStatus.pending && localOrder.status != OrderStatus.pendingDirect) {
            return false;
          }
          await OrderRepository.updateOrderStatus(orderCode, OrderStatus.delivering);
        }
        return true;
      }

      final docRef = col.doc(orderCode);
      final result = await fs.runTransaction<bool>((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) return false;

        final data = snapshot.data();
        final currentStatus = data?['status'] as String?;

        // 1. Chỉ chấp nhận khi đơn còn ở trạng thái mở hoặc chờ tài xế
        if (currentStatus != 'pending' && currentStatus != 'pendingDirect') {
          return false; // Đã có tài xế khác nhận trước hoặc đơn đã bị hủy
        }

        // 2. Nếu là đơn chỉ định đích danh, kiểm tra xem có đúng tài xế được chỉ định không hoặc đã hết hạn 45s chưa
        final assignedDriverId = data?['assigned_driver_id'] as String?;
        final int? directExpiresAt = data?['direct_expires_at'] as int?;
        final int nowMillis = DateTime.now().millisecondsSinceEpoch;

        if (currentStatus == 'pendingDirect') {
          final bool isExpired = directExpiresAt != null && nowMillis > directExpiresAt;
          if (!isExpired && assignedDriverId != null && assignedDriverId.isNotEmpty && assignedDriverId != driverId) {
            return false; // Đơn chỉ định cho tài xế khác và vẫn trong 45s chờ
          }
        }

        // 3. Thực hiện cập nhật nguyên tử (Atomic Update)
        tx.update(docRef, {
          'status': 'delivering',
          'dispatch_type': 'ACCEPTED',
          'driver_id': driverId,
          'driver_name': driverName.trim().isNotEmpty ? driverName.trim() : 'Tài xế GoShip',
          'driver_phone': driverPhone.trim().isNotEmpty ? driverPhone.trim() : '0917795211',
          'driver_plate': plateNumber.trim().isNotEmpty ? plateNumber.trim() : '59P1-987.65',
          'driver_vehicle': vehicleName,
          'accepted_at': FieldValue.serverTimestamp(),
        });

        return true;
      });

      if (result) {
        await OrderRepository.updateOrderStatus(orderCode, OrderStatus.delivering);
        debugPrint('>>> [FirestoreOrderService]: Driver $driverId successfully accepted order $orderCode via atomic transaction.');
      } else {
        debugPrint('>>> [FirestoreOrderService]: Race condition prevented! Order $orderCode already taken by another driver.');
      }

      return result;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService acceptOrder Error]: $e');
      return false;
    }
  }

  /// Cập nhật trạng thái đơn hàng (Đang giao, Hoàn thành, Hủy) và nộp ảnh e-POD
  static Future<void> updateOrderStatus({
    required String orderCode,
    required OrderStatus newStatus,
    List<String>? epodPhotos,
  }) async {
    try {
      final col = _ordersCol;
      final Map<String, dynamic> updates = {
        'status': newStatus.name,
      };
      if (newStatus == OrderStatus.completed) {
        updates['completed_at'] = FieldValue.serverTimestamp();
      }
      List<String>? optimizedEpodPhotos;
      if (epodPhotos != null && epodPhotos.isNotEmpty) {
        optimizedEpodPhotos = [];
        for (int i = 0; i < epodPhotos.length; i++) {
          final processed = await CloudMediaService.ensureCloudPortableImage(
            epodPhotos[i],
            category: 'epod',
            ownerId: '${orderCode}_$i',
            maxDimension: 720,
          );
          if (processed != null && processed.isNotEmpty) {
            optimizedEpodPhotos.add(processed);
          }
        }
        updates['epod_photos'] = optimizedEpodPhotos;
      }
      if (col != null) {
        await col.doc(orderCode).update(updates);
      }
      await OrderRepository.updateOrderStatus(orderCode, newStatus, epodPhotos: optimizedEpodPhotos ?? epodPhotos);
      debugPrint('>>> [FirestoreOrderService]: Order $orderCode updated to ${newStatus.name}');
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService updateOrderStatus Error]: $e');
    }
  }

  /// Stream danh sách lịch sử cuốc xe của tài xế theo driverId (bao gồm các đơn đã nhận, đang giao và đã hoàn thành)
  static Stream<List<OrderRecord>> streamDriverOrderHistory(String driverId) {
    try {
      final col = _ordersCol;
      if (col == null) return const Stream.empty();
      return col
          .where('driver_id', isEqualTo: driverId)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          return _mapFirestoreToOrderRecord(data);
        }).toList();

        // Sắp xếp cuốc mới nhất lên đầu
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      }).handleError((e) {
        debugPrint('>>> [FirestoreOrderService streamDriverOrderHistory Error]: $e');
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamDriverOrderHistory Error]: $e');
      return const Stream.empty();
    }
  }

  /// Lưu đánh giá của tài xế dành cho khách hàng lên Firestore
  static Future<bool> submitDriverRatingForCustomer({
    required String orderCode,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).update({
        'driver_rating': rating,
        'driver_comment': comment,
        'driver_tags': tags,
        'driver_rated_at': FieldValue.serverTimestamp(),
      });
      debugPrint('>>> [FirestoreOrderService]: Driver rating submitted for order $orderCode ($rating ⭐)');
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService submitDriverRatingForCustomer Error]: $e');
      return false;
    }
  }

  /// Lưu đánh giá của khách hàng dành cho tài xế lên Firestore
  static Future<bool> submitCustomerRatingForDriver({
    required String orderCode,
    required int rating,
    required String comment,
    required List<String> tags,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).update({
        'customer_rating': rating,
        'customer_comment': comment,
        'customer_tags': tags,
        'customer_rated_at': FieldValue.serverTimestamp(),
      });
      debugPrint('>>> [FirestoreOrderService]: Customer rating submitted for order $orderCode ($rating ⭐)');
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService submitCustomerRatingForDriver Error]: $e');
      return false;
    }
  }

  // ==================== IN-TRIP CHAT & MESSAGING ====================

  /// Gửi tin nhắn nhanh trong chuyến đi giữa Khách hàng và Tài xế
  static Future<bool> sendChatMessage({
    required String orderCode,
    required String senderId,
    required String senderName,
    required String senderRole, // 'customer' or 'driver'
    required String text,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      final msg = {
        'id': '${DateTime.now().millisecondsSinceEpoch}_$senderId',
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await col.doc(orderCode).update({
        'chat_messages': FieldValue.arrayUnion([msg]),
      });
      debugPrint('>>> [FirestoreOrderService]: Sent chat message from $senderName in order $orderCode');
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService sendChatMessage Error]: $e');
      return false;
    }
  }

  /// Stream tin nhắn trao đổi trong chuyến đi theo thời gian thực
  static Stream<List<Map<String, dynamic>>> streamOrderChatMessages(String orderCode) {
    try {
      final col = _ordersCol;
      if (col == null) return const Stream.empty();
      return col.doc(orderCode).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return [];
        final data = doc.data()!;
        final rawList = data['chat_messages'] as List?;
        if (rawList == null) return [];
        return rawList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamOrderChatMessages Error]: $e');
      return const Stream.empty();
    }
  }

  // ==================== IN-TRIP CALL SIGNALING ====================

  /// Bắt đầu một phiên gọi thoại trong chuyến đi (báo chuông sang thiết bị đối phương)
  static Future<bool> startInAppCall({
    required String orderCode,
    required String callerId,
    required String callerName,
    required String callerRole,
    required String calleePhone,
    String? callId,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).set({
        'active_call': {
          'id': callId ?? '${DateTime.now().millisecondsSinceEpoch}_call',
          'caller_id': callerId,
          'caller_name': callerName,
          'caller_role': callerRole,
          'callee_phone': calleePhone,
          'status': 'ringing',
          'started_at': DateTime.now().toIso8601String(),
        },
      }, SetOptions(merge: true));
      debugPrint('>>> [FirestoreOrderService]: Started in-app call for order $orderCode by $callerName');
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService startInAppCall Error]: $e');
      return false;
    }
  }

  /// Trả lời cuộc gọi (chuyển sang trạng thái kết nối đàm thoại)
  static Future<bool> answerInAppCall(String orderCode) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).set({
        'active_call': {
          'status': 'connected',
          'connected_at': DateTime.now().toIso8601String(),
        },
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService answerInAppCall Error]: $e');
      return false;
    }
  }

  /// Từ chối cuộc gọi
  static Future<bool> rejectInAppCall(String orderCode) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).set({
        'active_call': {
          'status': 'rejected',
          'ended_at': DateTime.now().toIso8601String(),
        },
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService rejectInAppCall Error]: $e');
      return false;
    }
  }

  /// Kết thúc cuộc gọi
  static Future<bool> endInAppCall(String orderCode) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).set({
        'active_call': {
          'status': 'ended',
          'ended_at': DateTime.now().toIso8601String(),
        },
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService endInAppCall Error]: $e');
      return false;
    }
  }

  /// Stream trạng thái cuộc gọi theo thời gian thực
  static Stream<Map<String, dynamic>?> streamOrderCallState(String orderCode) {
    try {
      final col = _ordersCol;
      if (col == null) return const Stream.empty();
      return col.doc(orderCode).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        final data = doc.data()!;
        final rawCall = data['active_call'] as Map?;
        if (rawCall == null) return null;
        return Map<String, dynamic>.from(rawCall);
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamOrderCallState Error]: $e');
      return const Stream.empty();
    }
  }

  // ==================== CANCELLATION FLOW ====================

  /// Khách hàng hủy đơn hàng (khi đang tìm xe hoặc trước khi giao)
  static Future<bool> cancelOrderByCustomer({
    required String orderCode,
    required String reason,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;
      await col.doc(orderCode).update({
        'status': OrderStatus.cancelled.name,
        'cancelled_by': 'customer',
        'cancel_reason': reason,
        'cancelled_at': FieldValue.serverTimestamp(),
      });
      await OrderRepository.updateOrderStatus(orderCode, OrderStatus.cancelled);
      debugPrint('>>> [FirestoreOrderService]: Order $orderCode cancelled by customer (Reason: $reason)');
      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService cancelOrderByCustomer Error]: $e');
      return false;
    }
  }

  /// Tài xế từ chối hoặc hủy cuốc (tự động hoàn đơn về thị trường mở để tài xế khác nhận)
  static Future<bool> cancelOrderByDriver({
    required String orderCode,
    required String driverId,
    required String reason,
    bool returnToMarket = true,
  }) async {
    try {
      final col = _ordersCol;
      if (col == null) return false;

      if (returnToMarket) {
        await col.doc(orderCode).update({
          'status': 'pending',
          'dispatch_type': 'OPEN_MARKET',
          'driver_id': null,
          'driver_name': null,
          'driver_phone': null,
          'driver_plate': null,
          'rejected_by_driver_ids': FieldValue.arrayUnion([driverId]),
          'last_driver_cancel_reason': reason,
          'last_driver_cancelled_at': FieldValue.serverTimestamp(),
        });
        debugPrint('>>> [FirestoreOrderService]: Driver $driverId cancelled order $orderCode -> Reverted to OPEN_MARKET.');
      } else {
        await col.doc(orderCode).update({
          'status': OrderStatus.cancelled.name,
          'cancelled_by': 'driver',
          'cancel_reason': reason,
          'cancelled_at': FieldValue.serverTimestamp(),
        });
        await OrderRepository.updateOrderStatus(orderCode, OrderStatus.cancelled);
        debugPrint('>>> [FirestoreOrderService]: Driver $driverId terminated order $orderCode completely.');
      }

      // Xóa active_order_id trong hồ sơ tracking của tài xế
      final driversCol = _driversCol;
      if (driversCol != null) {
        await driversCol.doc(driverId).update({
          'active_order_id': null,
        });
      }

      return true;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService cancelOrderByDriver Error]: $e');
      return false;
    }
  }

  /// Cập nhật tọa độ GPS trực tiếp của tài xế lên bảng `driver_tracking`
  static Future<void> updateDriverLocation({
    required String driverId,
    required String driverName,
    required String phone,
    required String plateNumber,
    required String vehicleType,
    required String vehicleName,
    required LatLng location,
    required double bearing,
    required bool isOnline,
    String? activeOrderId,
  }) async {
    try {
      final col = _driversCol;
      if (col == null) return;
      await col.doc(driverId).set({
        'driver_id': driverId,
        'driver_name': driverName,
        'phone': phone,
        'plate_number': plateNumber,
        'vehicle_type': vehicleType,
        'vehicle_name': vehicleName,
        'lat': location.latitude,
        'lng': location.longitude,
        'bearing': bearing,
        'is_online': isOnline,
        'active_order_id': activeOrderId,
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService updateDriverLocation Error]: $e');
    }
  }

  /// Stream vị trí trực tuyến của 1 tài xế cụ thể (dành cho màn hình theo dõi của khách)
  static Stream<Map<String, dynamic>?> streamDriverLocation(String driverId) {
    try {
      final col = _driversCol;
      if (col == null) return const Stream.empty();
      return col.doc(driverId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return doc.data();
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamDriverLocation Error]: $e');
      return const Stream.empty();
    }
  }

  /// Stream danh sách tất cả tài xế đang Online (để khách hàng xem và chọn tài xế Nearby)
  static Stream<List<Map<String, dynamic>>> streamOnlineDrivers() {
    try {
      final col = _driversCol;
      if (col == null) return const Stream.empty();
      return col
          .where('is_online', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'driver_id': doc.id,
            'name': data['driver_name'] ?? 'Bác tài GoShip',
            'phone': data['phone'] ?? '',
            'plate': data['plate_number'] ?? '',
            'vehicleType': data['vehicle_type'] ?? 'van',
            'vehicleName': data['vehicle_name'] ?? 'Xe Bán tải',
            'lat': (data['lat'] as num?)?.toDouble() ?? 10.7750,
            'lng': (data['lng'] as num?)?.toDouble() ?? 106.6980,
            'bearing': (data['bearing'] as num?)?.toDouble() ?? 0.0,
            'rating': 4.9,
            'trips': 350,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamOnlineDrivers Error]: $e');
      return const Stream.empty();
    }
  }

  // ==================== DRIVER WALLET, DEPOSIT & BANK CLOUD SYNC ====================

  /// Đọc thông tin Ví thu nhập, Tiền ký quỹ và Tài khoản ngân hàng của tài xế trên Cloud Firestore
  static Future<Map<String, dynamic>?> getDriverWallet(String driverId) async {
    try {
      final col = _walletsCol;
      if (col == null) return null;
      final doc = await col.doc(driverId).get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data();
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService getDriverWallet Error]: $e');
      return null;
    }
  }

  /// Stream theo dõi thời gian thực Ví thu nhập, Ký quỹ & Ngân hàng của tài xế
  static Stream<Map<String, dynamic>?> streamDriverWallet(String driverId) {
    try {
      final col = _walletsCol;
      if (col == null) return const Stream.empty();
      return col.doc(driverId).snapshots().map((doc) {
        if (!doc.exists || doc.data() == null) return null;
        return doc.data();
      });
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService streamDriverWallet Error]: $e');
      return const Stream.empty();
    }
  }

  /// Đồng bộ Ví thu nhập, Ký quỹ, Tài khoản ngân hàng hoặc Lịch sử giao dịch của tài xế lên Cloud Firestore
  static Future<void> saveDriverWallet({
    required String driverId,
    int? walletBalance,
    int? depositBalance,
    String? bankName,
    String? accountNo,
    String? holderName,
    String? branch,
    Map<String, dynamic>? transactionEntry,
  }) async {
    try {
      final col = _walletsCol;
      if (col == null) return;
      final Map<String, dynamic> payload = {
        'driver_id': driverId,
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (walletBalance != null) payload['wallet_balance'] = walletBalance;
      if (depositBalance != null) payload['deposit_balance'] = depositBalance;
      if (bankName != null) payload['bank_name'] = bankName;
      if (accountNo != null) {
        payload['account_no'] = accountNo;
        payload['bank_account_no'] = accountNo;
      }
      if (holderName != null) {
        payload['holder_name'] = holderName;
        payload['bank_holder'] = holderName;
      }
      if (branch != null) {
        payload['branch'] = branch;
        payload['bank_branch'] = branch;
      }
      if (transactionEntry != null) {
        payload['transactions'] = FieldValue.arrayUnion([transactionEntry]);
      }

      await col.doc(driverId).set(payload, SetOptions(merge: true));
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService saveDriverWallet Error]: $e');
    }
  }

  /// Tự động cộng tiền thu nhập ròng (85% cước gốc chuyến xe) vào Ví tài xế và khấu trừ 15% phí nền tảng từ Ví ký quỹ khi hoàn thành đơn
  static Future<int?> creditDriverOrderEarnings({
    required String driverId,
    required String orderCode,
    required int grossFee,
  }) async {
    final int netEarnings = (grossFee * 0.85).round();
    final int platformFee = grossFee - netEarnings;
    if (netEarnings <= 0) return null;
    try {
      final fs = _firestore;
      final col = _walletsCol;
      if (fs == null || col == null) return netEarnings;

      final docRef = col.doc(driverId);
      final int? updatedBalance = await fs.runTransaction<int?>((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? {};
        final List<String> creditedOrders = List<String>.from(data['credited_order_ids'] ?? []);
        if (creditedOrders.contains(orderCode)) {
          return (data['wallet_balance'] as num?)?.toInt();
        }
        final int currentBalance = (data['wallet_balance'] as num?)?.toInt() ?? 1500000;
        final int currentDeposit = (data['deposit_balance'] as num?)?.toInt() ?? 500000;
        final int newBalance = currentBalance + netEarnings;
        final int newDeposit = (currentDeposit - platformFee) > 0 ? (currentDeposit - platformFee) : 0;
        final nowIso = DateTime.now().toIso8601String();
        final txEntry = {
          'id': 'tx_order_${orderCode}_${DateTime.now().millisecondsSinceEpoch}',
          'type': 'earning',
          'title': 'Cộng thu nhập đơn #$orderCode',
          'subtitle': 'Thực nhận 85% • Khấu trừ ký quỹ 15% (-$platformFeeđ)',
          'amount': netEarnings,
          'isPositive': true,
          'orderCode': orderCode,
          'createdAt': nowIso,
        };
        tx.set(
          docRef,
          {
            'driver_id': driverId,
            'wallet_balance': newBalance,
            'deposit_balance': newDeposit,
            'credited_order_ids': FieldValue.arrayUnion([orderCode]),
            'transactions': FieldValue.arrayUnion([txEntry]),
            'last_earning_order': orderCode,
            'last_earning_amount': netEarnings,
            'updated_at': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        return newBalance;
      });
      return updatedBalance;
    } catch (e) {
      debugPrint('>>> [FirestoreOrderService creditDriverOrderEarnings Error]: $e');
      return netEarnings;
    }
  }

  // ==================== HELPER MAPPERS ====================

  static OrderRecord _mapFirestoreToOrderRecord(Map<String, dynamic> data) {
    DateTime createdAt = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['created_at_millis'] is num) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(data['created_at_millis']);
    }

    final dropLats = (data['dropoff_lats'] as List?)?.map((e) => (e as num).toDouble()).toList();
    final dropLngs = (data['dropoff_lngs'] as List?)?.map((e) => (e as num).toDouble()).toList();
    final List<List<double>>? routeCoords = (data['route_coords'] as List?)?.map((e) {
      if (e is Map) {
        return [
          (e['lat'] as num?)?.toDouble() ?? 0.0,
          (e['lng'] as num?)?.toDouble() ?? 0.0,
        ];
      } else if (e is List) {
        return (e).map((c) => (c as num).toDouble()).toList();
      }
      return <double>[];
    }).toList();

    DateTime? completedAt;
    if (data['completed_at'] is Timestamp) {
      completedAt = (data['completed_at'] as Timestamp).toDate();
    } else if (data['completedAt'] is Timestamp) {
      completedAt = (data['completedAt'] as Timestamp).toDate();
    } else if (data['completed_at_millis'] is num) {
      completedAt = DateTime.fromMillisecondsSinceEpoch(data['completed_at_millis']);
    } else if (data['completedAt'] is String) {
      completedAt = DateTime.tryParse(data['completedAt']);
    }

    final int totalFee = (data['total_fee'] as num?)?.toInt() ?? (data['totalFee'] as num?)?.toInt() ?? 0;

    return OrderRecord(
      orderCode: data['order_id'] ?? data['orderCode'] ?? '',
      createdAt: createdAt,
      status: OrderStatus.fromString(data['status']),
      pickupAddress: data['pickup_address'] ?? data['pickupAddress'] ?? '',
      dropoffAddresses: List<String>.from(data['dropoff_addresses'] ?? data['dropoffAddresses'] ?? []),
      vehicleName: data['vehicle_name'] ?? data['vehicleName'] ?? 'Xe Bán tải',
      packageCategory: data['package_category'] ?? data['packageCategory'] ?? 'Hàng tiêu chuẩn',
      weightCategory: data['weight_category'] ?? data['weightCategory'] ?? '<100kg',
      totalFee: totalFee,
      senderName: data['sender_name'] ?? data['senderName'] ?? '',
      senderPhone: data['sender_phone'] ?? data['senderPhone'] ?? '',
      recipientName: data['recipient_name'] ?? data['recipientName'] ?? '',
      recipientPhone: data['recipient_phone'] ?? data['recipientPhone'] ?? '',
      driverNote: data['driver_note'] ?? data['driverNote'] ?? '',
      distanceKm: (data['distance_km'] as num?)?.toDouble() ?? (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (data['duration_minutes'] as num?)?.toInt() ?? (data['durationMinutes'] as num?)?.toInt() ?? 0,
      pickupLat: (data['pickup_lat'] as num?)?.toDouble() ?? (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickup_lng'] as num?)?.toDouble() ?? (data['pickupLng'] as num?)?.toDouble(),
      dropoffLats: dropLats,
      dropoffLngs: dropLngs,
      routeCoords: routeCoords,
      epodPhotos: List<String>.from(data['epod_photos'] ?? data['epodPhotos'] ?? []),
      dropoffRecipients: (data['dropoff_recipients'] as List?)
              ?.map((e) => DropoffRecipient.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      assignedDriverId: data['assigned_driver_id'] ?? data['assignedDriverId'],
      assignedDriverName: data['assigned_driver_name'] ?? data['assignedDriverName'],
      driverId: data['driver_id'] ?? data['driverId'] ?? data['assigned_driver_id'] ?? data['assignedDriverId'],
      driverName: data['driver_name'] ?? data['driverName'] ?? data['assigned_driver_name'] ?? data['assignedDriverName'],
      driverPhone: data['driver_phone'] ?? data['driverPhone'] ?? data['assigned_driver_phone'] ?? data['assignedDriverPhone'],
      driverPlate: data['driver_plate'] ?? data['driverPlate'] ?? data['assigned_driver_plate'] ?? data['assignedDriverPlate'],
      completedAt: completedAt,
      customerRating: (data['customer_rating'] as num?)?.toInt() ?? (data['customerRating'] as num?)?.toInt(),
      customerComment: data['customer_comment'] ?? data['customerComment'],
      customerTags: (data['customer_tags'] as List?)?.map((e) => e.toString()).toList() ??
          (data['customerTags'] as List?)?.map((e) => e.toString()).toList(),
      driverRating: (data['driver_rating'] as num?)?.toInt() ?? (data['driverRating'] as num?)?.toInt(),
      driverComment: data['driver_comment'] ?? data['driverComment'],
      driverTags: (data['driver_tags'] as List?)?.map((e) => e.toString()).toList() ??
          (data['driverTags'] as List?)?.map((e) => e.toString()).toList(),
      paymentMethod: data['payment_method'] ?? data['paymentMethod'] ?? 'Tiền mặt',
      promoCode: data['promo_code'] ?? data['promoCode'],
      discountAmount: (data['discount_amount'] as num?)?.toInt() ?? (data['discountAmount'] as num?)?.toInt() ?? 0,
      originalFee: (data['original_fee'] as num?)?.toInt() ?? (data['originalFee'] as num?)?.toInt() ?? totalFee,
      packagePhotoBase64: data['package_photo_base64'] ?? data['packagePhotoBase64'],
    );
  }
}
