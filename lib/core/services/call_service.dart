import 'package:flutter/material.dart';
import '../constants/agora_config.dart';
import '../constants/app_colors.dart';
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
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Số điện thoại không hợp lệ.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
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
