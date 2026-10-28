import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/call_service.dart';
import '../services/firestore_order_service.dart';

class InTripChatSheet extends StatefulWidget {
  final String orderCode;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole; // 'customer' or 'driver'
  final String otherPartyName;
  final String otherPartyPhone;
  final String otherPartyRole; // 'Tài xế' or 'Khách hàng'

  const InTripChatSheet({
    super.key,
    required this.orderCode,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.otherPartyName,
    required this.otherPartyPhone,
    required this.otherPartyRole,
  });

  static Future<void> show(
    BuildContext context, {
    required String orderCode,
    required String currentUserId,
    required String currentUserName,
    required String currentUserRole,
    required String otherPartyName,
    required String otherPartyPhone,
    required String otherPartyRole,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InTripChatSheet(
        orderCode: orderCode,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserRole: currentUserRole,
        otherPartyName: otherPartyName,
        otherPartyPhone: otherPartyPhone,
        otherPartyRole: otherPartyRole,
      ),
    );
  }

  @override
  State<InTripChatSheet> createState() => _InTripChatSheetState();
}

class _InTripChatSheetState extends State<InTripChatSheet> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isSending = false;

  List<String> get _quickSuggestions {
    if (widget.currentUserRole == 'customer') {
      return [
        'Bác tài tới đâu rồi ạ?',
        'Em đang đợi ở trước cổng/sảnh',
        'Hàng dễ vỡ, bác tài đi cẩn thận giúp em',
        'Có người nhận ra đón rồi ạ',
      ];
    } else {
      return [
        'Tôi đang trên đường đến điểm lấy hàng',
        'Tôi đã đến nơi, đang đợi ở trước cổng',
        'Hàng cồng kềnh, bạn phụ một tay nhé',
        'Tôi đã giao hàng xong cho người nhận',
      ];
    }
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _isSending) return;

    _msgCtrl.clear();
    setState(() => _isSending = true);

    await FirestoreOrderService.sendChatMessage(
      orderCode: widget.orderCode,
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      senderRole: widget.currentUserRole,
      text: clean,
    );

    if (mounted) {
      setState(() => _isSending = false);
      Future.delayed(const Duration(milliseconds: 150), () {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Column(
        children: [
          // Header Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    widget.otherPartyName.isNotEmpty ? widget.otherPartyName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.otherPartyName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.currentUserRole == 'customer' ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.otherPartyRole,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: widget.currentUserRole == 'customer' ? AppColors.primary : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đơn #${widget.orderCode}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Direct Phone Call Button
                if (widget.otherPartyPhone.isNotEmpty)
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0FDF4),
                      foregroundColor: AppColors.success,
                    ),
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    tooltip: 'Gọi điện',
                    onPressed: () => CallService.makePhoneCall(
                      context,
                      widget.otherPartyPhone,
                      calleeName: widget.otherPartyName,
                      calleeRole: widget.otherPartyRole,
                      orderCode: widget.orderCode,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Live Chat Messages Stream
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreOrderService.streamOrderChatMessages(widget.orderCode),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          const Text(
                            'Chưa có tin nhắn nào',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Nhấn vào câu gợi ý bên dưới hoặc nhập tin nhắn để trao đổi nhanh.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final reversedMessages = messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: reversedMessages.length,
                  itemBuilder: (ctx, idx) {
                    final msg = reversedMessages[idx];
                    final isMe = msg['senderRole'] != null
                        ? msg['senderRole'] == widget.currentUserRole
                        : msg['senderId'] == widget.currentUserId;
                    final text = msg['text'] ?? '';
                    final timeStr = msg['timestamp'] != null
                        ? DateTime.tryParse(msg['timestamp']) != null
                            ? '${DateTime.parse(msg['timestamp']).hour.toString().padLeft(2, '0')}:${DateTime.parse(msg['timestamp']).minute.toString().padLeft(2, '0')}'
                            : ''
                        : '';

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                            bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: isMe ? Colors.white : AppColors.textPrimary,
                                fontSize: 14,
                                height: 1.35,
                              ),
                            ),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Quick Suggestion Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickSuggestions.map((suggestion) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      label: Text(
                        suggestion,
                        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () => _sendMessage(suggestion),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn trao đổi...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (val) => _sendMessage(val),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                  onPressed: () => _sendMessage(_msgCtrl.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
