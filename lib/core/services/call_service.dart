import 'package:flutter/material.dart';
import '../constants/agora_config.dart';
import '../services/agora_voice_service.dart';
import '../widgets/in_app_call_screen.dart';

class CallService {
  /// Thực hiện cuộc gọi thoại trực tiếp trong ứng dụng GoShip (100% trong app, không ra ngoài SIM)
  static Future<void> makePhoneCall(
    BuildContext context,
    String rawPhone, {
    String? calleeName,
    String? calleeRole,
    String? avatarUrl,
    String? orderCode,
  }) async {
    String cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      // Khi số điện thoại của đối phương chưa cập nhật hoặc để trống,
      // tự động dùng số hotline/đối tác mặc định để không chặn tính năng đàm thoại VoIP nội bộ trong app
      cleanPhone = '0917795211';
    }

    // Xin quyền Micro trước khi vào màn hình đàm thoại
    if (AgoraConfig.isConfigured) {
      await AgoraVoiceService.ensureMicrophonePermission();
    }

    if (!context.mounted) return;

    final displayName = (calleeName != null && calleeName.isNotEmpty) ? calleeName : 'Đối tác GoShip';

    // Khởi chạy cuộc gọi thoại trong app GoShip ngay lập tức
    InAppCallScreen.show(
      context,
      calleeName: displayName,
      calleePhone: cleanPhone,
      calleeRole: calleeRole ?? 'Người nhận cuộc gọi',
      calleeAvatar: avatarUrl,
      orderCode: orderCode,
    );
  }
}
