import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/auth_service.dart';

class SavedAddressModel {
  final String id;
  final String label; // 'Nhà riêng', 'Công ty', 'Kho hàng', 'Khác'
  final String address;
  final String details;
  final double? latitude;
  final double? longitude;
  final String iconType; // 'home', 'work', 'warehouse', 'location'

  SavedAddressModel({
    required this.id,
    required this.label,
    required this.address,
    this.details = '',
    this.latitude,
    this.longitude,
    this.iconType = 'location',
  });

  LatLng? get latLng => (latitude != null && longitude != null) ? LatLng(latitude!, longitude!) : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'address': address,
        'details': details,
        'latitude': latitude,
        'longitude': longitude,
        'iconType': iconType,
      };

  factory SavedAddressModel.fromJson(Map<String, dynamic> json) => SavedAddressModel(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        address: json['address'] ?? '',
        details: json['details'] ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        iconType: json['iconType'] ?? 'location',
      );
}

class SavedAddressService {
  static const String _key = 'goship_saved_addresses_v1';

  static final List<SavedAddressModel> _defaultAddresses = [
    SavedAddressModel(
      id: 'addr_home',
      label: 'Nhà riêng',
      address: 'Landmark 81, Vinhomes Central Park, Bình Thạnh, TP. HCM',
      details: 'Tòa L81, Tầng 28',
      latitude: 10.7946,
      longitude: 106.7218,
      iconType: 'home',
    ),
    SavedAddressModel(
      id: 'addr_work',
      label: 'Văn phòng / Công ty',
      address: '25 Điện Biên Phủ, Phường Võ Thị Sáu, Quận 3, TP. HCM',
      details: 'Tòa nhà văn phòng GoShip',
      latitude: 10.7925,
      longitude: 106.7020,
      iconType: 'work',
    ),
    SavedAddressModel(
      id: 'addr_warehouse',
      label: 'Kho bãi trung tâm',
      address: 'Khu Công Nghệ Cao, TP. Thủ Đức, TP. HCM',
      details: 'Kho Tổng Số 3',
      latitude: 10.8540,
      longitude: 106.7850,
      iconType: 'warehouse',
    ),
  ];

  static Future<DocumentReference<Map<String, dynamic>>?> _getUserCloudDoc() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) return null;
      final docId = AuthService.getDocIdForUser(user);
      return FirebaseFirestore.instance.collection('users').doc(docId);
    } catch (_) {
      return null;
    }
  }

  static Future<List<SavedAddressModel>> getSavedAddresses() async {
    try {
      // 1. Ưu tiên đọc đồng bộ từ Cloud Firestore `users/{docId}.saved_addresses`
      final docRef = await _getUserCloudDoc();
      if (docRef != null) {
        final snap = await docRef.get();
        final rawList = snap.data()?['saved_addresses'];
        if (rawList is List && rawList.isNotEmpty) {
          final cloudList = rawList
              .whereType<Map>()
              .map((m) => SavedAddressModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
          if (cloudList.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_key, jsonEncode(cloudList.map((a) => a.toJson()).toList()));
            return cloudList;
          }
        }
      }

      // 2. Đọc từ SharedPreferences cục bộ
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        return list.map((item) => SavedAddressModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('>>> [SavedAddressService Error]: $e');
    }
    return List<SavedAddressModel>.from(_defaultAddresses);
  }

  static Future<void> _persistAddresses(List<SavedAddressModel> list) async {
    final jsonMaps = list.map((a) => a.toJson()).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(jsonMaps));

    final docRef = await _getUserCloudDoc();
    if (docRef != null) {
      await docRef.set({
        'saved_addresses': jsonMaps,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    }
  }

  static Future<void> saveAddress(SavedAddressModel newAddress) async {
    try {
      final currentList = await getSavedAddresses();
      final index = currentList.indexWhere((a) => a.id == newAddress.id);
      if (index >= 0) {
        currentList[index] = newAddress;
      } else {
        currentList.add(newAddress);
      }
      await _persistAddresses(currentList);
    } catch (e) {
      debugPrint('>>> [SaveAddress Error]: $e');
    }
  }

  static Future<void> deleteAddress(String id) async {
    try {
      final currentList = await getSavedAddresses();
      currentList.removeWhere((a) => a.id == id);
      await _persistAddresses(currentList);
    } catch (e) {
      debugPrint('>>> [DeleteAddress Error]: $e');
    }
  }
}
