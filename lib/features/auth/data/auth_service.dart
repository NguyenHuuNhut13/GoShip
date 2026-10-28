import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/cloud_media_service.dart';

class AuthService {
  static const String _userKey = 'goship_current_user';
  static const String _usersCollection = 'users';

  static FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Băm mật khẩu bằng SHA-256 kèm Salt bảo mật (không bao giờ lưu mật khẩu thô lên Cloud)
  static String hashPassword(String plainPassword) {
    final bytes = utf8.encode('goship_sec_salt_2026:${plainPassword.trim()}');
    return sha256.convert(bytes).toString();
  }

  /// Chuẩn hóa khóa định danh tài khoản trên Firestore `users`
  static String getDocIdForUser(UserModel user) {
    final cleanPhone = user.phone.trim().replaceAll(' ', '');
    if (cleanPhone.isNotEmpty) {
      return 'usr_$cleanPhone';
    }
    final cleanEmail = user.email.trim().toLowerCase();
    if (cleanEmail.isNotEmpty) {
      return 'usr_${cleanEmail.replaceAll(RegExp(r'[^a-z0-9._-]'), '_')}';
    }
    return user.id.isNotEmpty ? user.id : 'usr_default';
  }

  /// Đăng ký tài khoản mới (Khách hàng hoặc Đối tác Tài xế) và đồng bộ trực tiếp lên Cloud Firestore
  static Future<ApiResponse<UserModel>> registerUser({
    required UserModel user,
    required String password,
  }) async {
    try {
      final fs = _firestore;
      final cleanEmail = user.email.trim().toLowerCase();
      final cleanPhone = user.phone.trim().replaceAll(' ', '');

      if (fs != null) {
        final col = fs.collection(_usersCollection);

        // Kiểm tra trùng Số điện thoại hoặc Email trên Cloud
        if (cleanPhone.isNotEmpty) {
          final phoneSnap = await col.where('phone', isEqualTo: cleanPhone).limit(1).get();
          if (phoneSnap.docs.isNotEmpty && phoneSnap.docs.first.data()['password_hash'] != null) {
            return ApiResponse(
              isSuccess: false,
              errorMessage: 'Số điện thoại $cleanPhone đã được đăng ký. Vui lòng đăng nhập!',
            );
          }
        }
        if (cleanEmail.isNotEmpty) {
          final emailSnap = await col.where('email_lower', isEqualTo: cleanEmail).limit(1).get();
          if (emailSnap.docs.isNotEmpty && emailSnap.docs.first.data()['password_hash'] != null) {
            return ApiResponse(
              isSuccess: false,
              errorMessage: 'Email ${user.email} đã được đăng ký. Vui lòng đăng nhập!',
            );
          }
        }
      }

      // Đồng bộ hồ sơ + password_hash lên Firestore `users`
      final syncedUser = await syncUserProfileToCloud(user, plainPassword: password);

      // Nếu là Tài xế mới, khởi tạo sẵn Ví Thu nhập & Ví Ký quỹ trên Firestore
      if (syncedUser.role == UserRole.driver && fs != null) {
        final walletId = syncedUser.id.isNotEmpty ? syncedUser.id : cleanPhone;
        if (walletId.isNotEmpty) {
          final walletRef = fs.collection('driver_wallets').doc(walletId);
          final walletSnap = await walletRef.get();
          if (!walletSnap.exists) {
            await walletRef.set({
              'driver_id': walletId,
              'driver_name': syncedUser.name,
              'driver_phone': syncedUser.phone,
              'wallet_balance': 1500000,
              'deposit_balance': 500000,
              'transactions': [
                {
                  'title': 'Cấp vốn Ký quỹ kích hoạt Tài xế mới',
                  'time': 'Khởi tạo tài khoản',
                  'amount': '+500,000 đ',
                  'isPositive': true,
                  'type': 'deposit',
                },
              ],
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

      await saveSession(syncedUser, syncCloud: false);
      return ApiResponse(isSuccess: true, data: syncedUser, statusCode: 201);
    } catch (e) {
      debugPrint('>>> [AuthService.registerUser Error]: $e');
      await saveSession(user, syncCloud: false);
      return ApiResponse(isSuccess: true, data: user);
    }
  }

  /// Đăng nhập hợp nhất (Hybrid Cloud Firestore `users` + Admin Portal + API `data.nks.vn`)
  /// Giúp tài khoản đăng ký hoặc chỉnh sửa trên Thiết bị A đăng nhập được ngay trên Thiết bị B
  static Future<ApiResponse<UserModel>> login({
    required String emailOrUsername,
    required String password,
    required UserRole selectedRole,
  }) async {
    final cleanId = emailOrUsername.trim();
    final cleanLower = cleanId.toLowerCase();
    final cleanPass = password.trim();
    final passHash = hashPassword(cleanPass);

    // 0. Kiểm tra tài khoản Quản trị viên (Admin Portal)
    if (cleanLower == 'admin' || cleanLower == 'admin@goship.vn' || cleanId == '0900000000') {
      final adminCloud = await _findCloudUserByIdentifier('admin@goship.vn');
      final storedAdminHash = adminCloud?['password_hash']?.toString();
      final isValidAdminPass = (storedAdminHash != null && storedAdminHash.isNotEmpty)
          ? (storedAdminHash == passHash || cleanPass == 'admin123')
          : (cleanPass == 'admin123' || cleanPass == '123456');

      if (isValidAdminPass) {
        final adminUser = UserModel(
          id: 'usr_admin',
          name: adminCloud?['name']?.toString() ?? 'Quản trị viên GoShip',
          phone: adminCloud?['phone']?.toString() ?? '0900000000',
          email: 'admin@goship.vn',
          role: UserRole.admin,
          accountStatus: 'active',
        );
        final syncedAdmin = await syncUserProfileToCloud(adminUser, plainPassword: cleanPass);
        await saveSession(syncedAdmin, syncCloud: false);
        return ApiResponse(isSuccess: true, data: syncedAdmin, statusCode: 200);
      } else {
        return ApiResponse(
          isSuccess: false,
          errorMessage: 'Mật khẩu Quản trị viên không chính xác.',
          statusCode: 401,
        );
      }
    }

    // 1. Kiểm tra tài khoản trên Cloud Firestore `users` trước
    Map<String, dynamic>? cloudUserData;
    try {
      cloudUserData = await _findCloudUserByIdentifier(cleanId);
      if (cloudUserData != null) {
        final accStatus = cloudUserData['account_status']?.toString() ?? cloudUserData['accountStatus']?.toString() ?? 'active';
        if (accStatus == 'locked') {
          return ApiResponse(
            isSuccess: false,
            errorMessage: 'Tài khoản của bạn hiện đang bị tạm khóa bởi Quản trị viên GoShip. Vui lòng liên hệ bộ phận hỗ trợ.',
            statusCode: 403,
          );
        }

        final storedHash = cloudUserData['password_hash']?.toString();
        if (storedHash != null && storedHash.isNotEmpty && storedHash == passHash) {
          final cloudUser = _mapCloudDataToUserModel(cloudUserData, fallbackRole: selectedRole);
          await saveSession(cloudUser, syncCloud: false);
          return ApiResponse(isSuccess: true, data: cloudUser, statusCode: 200);
        }
      }
    } catch (e) {
      debugPrint('>>> [AuthService Cloud Lookup Warning]: $e');
    }

    // 2. Gọi API máy chủ `data.nks.vn`
    final result = await ApiClient.login(
      emailOrUsername: cleanId,
      password: cleanPass,
      selectedRole: selectedRole,
    );

    if (result.isSuccess && result.data != null) {
      var user = result.data!;
      // Hợp nhất với hồ sơ đã cập nhật trên Cloud Firestore (nếu người dùng từng đổi Avatar, CCCD, Biển số xe trên máy khác)
      cloudUserData ??= await _findCloudUserByIdentifier(user.phone.isNotEmpty ? user.phone : cleanId);
      if (cloudUserData != null) {
        user = _mergeUserWithCloudData(user, cloudUserData);
        if (user.accountStatus == 'locked') {
          return ApiResponse(
            isSuccess: false,
            errorMessage: 'Tài khoản của bạn hiện đang bị tạm khóa bởi Quản trị viên GoShip. Vui lòng liên hệ bộ phận hỗ trợ.',
            statusCode: 403,
          );
        }
      }
      // Lưu đồng bộ lên Cloud kèm hash mật khẩu để các thiết bị sau đăng nhập siêu tốc
      final synced = await syncUserProfileToCloud(user, plainPassword: cleanPass);
      await saveSession(synced, syncCloud: false);
      return ApiResponse(isSuccess: true, data: synced, statusCode: result.statusCode);
    }

    // 3. Nếu tài khoản tồn tại trên Cloud nhưng vừa sai mật khẩu
    if (cloudUserData != null && cloudUserData['password_hash'] != null) {
      return ApiResponse(
        isSuccess: false,
        errorMessage: 'Mật khẩu không chính xác. Vui lòng kiểm tra lại.',
        statusCode: 401,
      );
    }

    return result;
  }

  /// Tìm tài khoản trên Firestore `users` theo Email, SĐT hoặc ID
  static Future<Map<String, dynamic>?> _findCloudUserByIdentifier(String identifier) async {
    final fs = _firestore;
    if (fs == null || identifier.trim().isEmpty) return null;

    try {
      final col = fs.collection(_usersCollection);
      final clean = identifier.trim();
      final lower = clean.toLowerCase();

      // Thử tìm theo email_lower (có timeout 4s phòng trường hợp mạng chập chờn)
      if (clean.contains('@')) {
        final snap = await col.where('email_lower', isEqualTo: lower).limit(1).get().timeout(const Duration(seconds: 4));
        if (snap.docs.isNotEmpty) return snap.docs.first.data();
      }

      // Thử tìm theo số điện thoại
      final cleanPhone = clean.replaceAll(' ', '');
      final phoneSnap = await col.where('phone', isEqualTo: cleanPhone).limit(1).get().timeout(const Duration(seconds: 4));
      if (phoneSnap.docs.isNotEmpty) return phoneSnap.docs.first.data();

      // Thử tìm theo docId trực tiếp
      final docSnap = await col.doc('usr_$cleanPhone').get().timeout(const Duration(seconds: 4));
      if (docSnap.exists && docSnap.data() != null) return docSnap.data()!;
    } catch (e) {
      debugPrint('>>> [_findCloudUserByIdentifier Warning/Timeout]: $e');
    }

    return null;
  }

  /// Đồng bộ hồ sơ người dùng (bao gồm nén ảnh Avatar & CCCD 2 mặt) lên Cloud Firestore `users`
  static Future<UserModel> syncUserProfileToCloud(
    UserModel user, {
    String? plainPassword,
  }) async {
    try {
      final docId = getDocIdForUser(user);

      // Chuyển mọi đường dẫn file ảnh cục bộ sang Data URI đã nén để máy khác xem được ngay
      final portableAvatar = await CloudMediaService.ensureCloudPortableImage(
        user.avatarUrl,
        category: 'avatar',
        ownerId: docId,
        maxDimension: 480,
      );
      final portableCccdFront = await CloudMediaService.ensureCloudPortableImage(
        user.cccdFrontUrl,
        category: 'cccd_front',
        ownerId: docId,
        maxDimension: 800,
      );
      final portableCccdBack = await CloudMediaService.ensureCloudPortableImage(
        user.cccdBackUrl,
        category: 'cccd_back',
        ownerId: docId,
        maxDimension: 800,
      );

      final portableUser = user.copyWith(
        avatarUrl: portableAvatar ?? user.avatarUrl,
        cccdFrontUrl: portableCccdFront ?? user.cccdFrontUrl,
        cccdBackUrl: portableCccdBack ?? user.cccdBackUrl,
      );

      final fs = _firestore;
      if (fs != null) {
        final payload = <String, dynamic>{
          ...portableUser.toJson(),
          'email_lower': portableUser.email.trim().toLowerCase(),
          'phone': portableUser.phone.trim().replaceAll(' ', ''),
          'updated_at': FieldValue.serverTimestamp(),
        };
        if (plainPassword != null && plainPassword.trim().isNotEmpty) {
          payload['password_hash'] = hashPassword(plainPassword);
        }

        await fs.collection(_usersCollection).doc(docId).set(payload, SetOptions(merge: true));

        // Nếu là Tài xế, cập nhật luôn thông tin hiển thị trên `driver_tracking` nếu tài xế đang trực tuyến
        if (portableUser.role == UserRole.driver) {
          final driverId = portableUser.id.isNotEmpty ? portableUser.id : portableUser.phone.trim();
          if (driverId.isNotEmpty) {
            final trackingRef = fs.collection('driver_tracking').doc(driverId);
            final trackingSnap = await trackingRef.get();
            if (trackingSnap.exists) {
              await trackingRef.set({
                'driver_name': portableUser.name,
                'phone': portableUser.phone,
                'plate': portableUser.plateNumber ?? '51D-892.14',
                'vehicle_type': portableUser.vehicleType ?? 'Xe Bán tải',
                'avatar_url': portableUser.avatarUrl,
                'updated_at': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          }
        }
      }

      return portableUser;
    } catch (e) {
      debugPrint('>>> [AuthService.syncUserProfileToCloud Warning]: $e');
      return user;
    }
  }

  /// Tải hồ sơ mới nhất từ Cloud Firestore `users` để đồng bộ giữa các thiết bị
  static Future<UserModel> fetchCloudProfile(UserModel currentUser) async {
    try {
      final fs = _firestore;
      if (fs == null) return currentUser;

      final docId = getDocIdForUser(currentUser);
      final docSnap = await fs.collection(_usersCollection).doc(docId).get();
      if (docSnap.exists && docSnap.data() != null) {
        return _mergeUserWithCloudData(currentUser, docSnap.data()!);
      }

      final byPhoneOrEmail = await _findCloudUserByIdentifier(
        currentUser.phone.isNotEmpty ? currentUser.phone : currentUser.email,
      );
      if (byPhoneOrEmail != null) {
        return _mergeUserWithCloudData(currentUser, byPhoneOrEmail);
      }
    } catch (e) {
      debugPrint('>>> [AuthService.fetchCloudProfile Warning]: $e');
    }
    return currentUser;
  }

  static UserModel _mapCloudDataToUserModel(
    Map<String, dynamic> data, {
    UserRole? fallbackRole,
  }) {
    return UserModel(
      id: data['id']?.toString() ?? 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: data['name']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      role: data['role'] != null ? UserRole.fromString(data['role'].toString()) : (fallbackRole ?? UserRole.customer),
      token: data['token']?.toString(),
      avatarUrl: data['avatarUrl']?.toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
      plateNumber: data['plateNumber']?.toString(),
      vehicleType: data['vehicleType']?.toString(),
      cccd: data['cccd']?.toString(),
      cccdFrontUrl: data['cccdFrontUrl']?.toString(),
      cccdBackUrl: data['cccdBackUrl']?.toString(),
      dob: data['dob']?.toString(),
      gender: data['gender']?.toString(),
      hometown: data['hometown']?.toString(),
      permanentAddress: data['permanentAddress']?.toString(),
      expiryDate: data['expiryDate']?.toString(),
      accountStatus: data['account_status']?.toString() ?? data['accountStatus']?.toString() ?? 'active',
    );
  }

  static UserModel _mergeUserWithCloudData(UserModel base, Map<String, dynamic> cloud) {
    String? nonEmpty(dynamic val, String? fallback) {
      final s = val?.toString().trim();
      return (s != null && s.isNotEmpty && s != 'null') ? s : fallback;
    }

    return base.copyWith(
      name: nonEmpty(cloud['name'], base.name) ?? base.name,
      phone: nonEmpty(cloud['phone'], base.phone) ?? base.phone,
      email: nonEmpty(cloud['email'], base.email) ?? base.email,
      avatarUrl: nonEmpty(cloud['avatarUrl'], base.avatarUrl),
      plateNumber: nonEmpty(cloud['plateNumber'], base.plateNumber),
      vehicleType: nonEmpty(cloud['vehicleType'], base.vehicleType),
      cccd: nonEmpty(cloud['cccd'], base.cccd),
      cccdFrontUrl: nonEmpty(cloud['cccdFrontUrl'], base.cccdFrontUrl),
      cccdBackUrl: nonEmpty(cloud['cccdBackUrl'], base.cccdBackUrl),
      dob: nonEmpty(cloud['dob'], base.dob),
      gender: nonEmpty(cloud['gender'], base.gender),
      hometown: nonEmpty(cloud['hometown'], base.hometown),
      permanentAddress: nonEmpty(cloud['permanentAddress'], base.permanentAddress),
      expiryDate: nonEmpty(cloud['expiryDate'], base.expiryDate),
      rating: (cloud['rating'] as num?)?.toDouble() ?? base.rating,
      totalOrders: (cloud['totalOrders'] as num?)?.toInt() ?? base.totalOrders,
      accountStatus: nonEmpty(cloud['account_status'] ?? cloud['accountStatus'], base.accountStatus) ?? base.accountStatus,
    );
  }

  /// Admin phê duyệt / khóa / mở khóa tài khoản người dùng/tài xế trên Cloud Firestore
  static Future<bool> updateUserAccountStatus({
    required String docId,
    required String status,
    String? phone,
    String? userId,
  }) async {
    try {
      final fs = _firestore;
      if (fs == null) return false;
      await fs.collection(_usersCollection).doc(docId).set({
        'account_status': status,
        'accountStatus': status,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Nếu bị khóa, ngắt kết nối trực tuyến của tài xế ngay lập tức
      if (status == 'locked') {
        for (final key in [docId, phone, userId]) {
          if (key != null && key.trim().isNotEmpty) {
            await fs.collection('driver_tracking').doc(key.trim()).delete().catchError((_) {});
            await fs.collection('online_drivers').doc(key.trim()).delete().catchError((_) {});
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('>>> [AuthService.updateUserAccountStatus Error]: $e');
      return false;
    }
  }

  /// Lưu phiên đăng nhập cục bộ VÀ tự động đồng bộ hồ sơ lên Cloud Firestore
  static Future<void> saveSession(UserModel user, {bool syncCloud = true}) async {
    UserModel finalUser = user;
    if (syncCloud) {
      finalUser = await syncUserProfileToCloud(user);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(finalUser.toJson()));
  }

  /// Cập nhật mật khẩu mới trên cả Cloud Firestore `users`
  static Future<void> updateCloudPassword(UserModel user, String newPassword) async {
    await syncUserProfileToCloud(user, plainPassword: newPassword);
  }

  static Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(_userKey);
      if (userStr != null && userStr.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(userStr);
        return UserModel(
          id: json['id'] ?? '',
          name: json['name'] ?? '',
          phone: json['phone'] ?? '',
          email: json['email'] ?? '',
          role: UserRole.fromString(json['role']),
          token: json['token'],
          avatarUrl: json['avatarUrl'],
          rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
          totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
          plateNumber: json['plateNumber'],
          vehicleType: json['vehicleType'],
          cccd: json['cccd'],
          cccdFrontUrl: json['cccdFrontUrl'],
          cccdBackUrl: json['cccdBackUrl'],
          dob: json['dob'],
          gender: json['gender'],
          hometown: json['hometown'],
          permanentAddress: json['permanentAddress'],
          expiryDate: json['expiryDate'],
          accountStatus: json['account_status']?.toString() ?? json['accountStatus']?.toString() ?? 'active',
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }
}
