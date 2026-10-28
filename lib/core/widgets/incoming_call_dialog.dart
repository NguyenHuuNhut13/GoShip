import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/agora_config.dart';
import '../services/agora_voice_service.dart';
import '../services/audio_alert_service.dart';
import '../services/firestore_order_service.dart';
import 'in_app_call_screen.dart';

class IncomingCallDialog extends StatefulWidget {
  final String orderCode;
  final String callerName;
  final String callerRole;
  final String callerPhone;
  final String? callId;

  const IncomingCallDialog({
    super.key,
    required this.orderCode,
    required this.callerName,
    required this.callerRole,
    required this.callerPhone,
    this.callId,
  });

  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required String orderCode,
    required String callerName,
    required String callerRole,
    required String callerPhone,
    String? callId,
  }) async {
    if (_isShowing) return;
    _isShowing = true;

    // Phát chuông cuộc gọi đến
    AudioAlertService.playIncomingCallRingtone();

    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingCallDialog(
        orderCode: orderCode,
        callerName: callerName,
        callerRole: callerRole,
        callerPhone: callerPhone,
        callId: callId,
      ),
    );

    _isShowing = false;
    AudioAlertService.stopIncomingCallRingtone();
  }

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  StreamSubscription<Map<String, dynamic>?>? _callStateSub;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Lắng nghe nếu bên gọi hủy cuộc gọi
    _callStateSub = FirestoreOrderService.streamOrderCallState(widget.orderCode).listen((callState) {
      if (!mounted) return;
      if (callState == null || callState['status'] == 'ended' || callState['status'] == 'rejected') {
        AudioAlertService.stopIncomingCallRingtone();
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _callStateSub?.cancel();
    AudioAlertService.stopIncomingCallRingtone();
    super.dispose();
  }

  void _declineCall() {
    AudioAlertService.stopIncomingCallRingtone();
    FirestoreOrderService.rejectInAppCall(widget.orderCode);
    Navigator.of(context).pop();
  }

  void _answerCall() async {
    AudioAlertService.stopIncomingCallRingtone();
    if (AgoraConfig.isConfigured) {
      await AgoraVoiceService.ensureMicrophonePermission();
    }
    await FirestoreOrderService.answerInAppCall(widget.orderCode);
    if (!mounted) return;
    Navigator.of(context).pop();

    // Mở màn hình cuộc gọi trực tiếp ở trạng thái đã kết nối
    InAppCallScreen.show(
      context,
      calleeName: widget.callerName,
      calleePhone: widget.callerPhone,
      calleeRole: widget.callerRole,
      orderCode: widget.orderCode,
      callId: widget.callId,
      isIncomingAccepted: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Pulsing Call Avatar
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                return Container(
                  padding: EdgeInsets.all(8 + (_pulseCtrl.value * 6)),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15 + (_pulseCtrl.value * 0.15)),
                  ),
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Caller name
            Text(
              widget.callerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Role and Call type
            Text(
              '${widget.callerRole} đang gọi cho bạn...',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Đơn hàng: ${widget.orderCode}',
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 32),

            // Decline / Answer buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Decline Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _declineCall,
                      borderRadius: BorderRadius.circular(36),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x66EF4444), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Từ chối', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),

                // Answer Button
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: _answerCall,
                      borderRadius: BorderRadius.circular(36),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x6622C55E), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.call_rounded, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Trả lời', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
