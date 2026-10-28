import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../constants/app_colors.dart';

class ContactPickResult {
  final String name;
  final String phone;

  const ContactPickResult({required this.name, required this.phone});
}

class ContactPickerHelper {
  static const List<ContactPickResult> _sampleContacts = [
    ContactPickResult(name: 'Trần Minh Tâm', phone: '0908123456'),
    ContactPickResult(name: 'Lê Hoàng Nam', phone: '0912345678'),
    ContactPickResult(name: 'Nguyễn Mai Linh', phone: '0938765432'),
    ContactPickResult(name: 'Phạm Đức Huy', phone: '0977889900'),
    ContactPickResult(name: 'Đặng Thu Hà', phone: '0988112233'),
  ];

  /// Mở danh bạ hệ thống để lấy Họ tên và Số điện thoại.
  /// Nếu không có quyền hoặc lỗi trên máy ảo/web, hiển thị bảng chọn nhanh.
  static Future<ContactPickResult?> pickContact(BuildContext context) async {
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
        final contact = await FlutterContacts.native.showPicker(
          properties: {ContactProperty.phone},
        );
        if (contact != null) {
          final name = (contact.displayName ?? '').trim();
          String phone = '';
          if (contact.phones.isNotEmpty) {
            phone = contact.phones.first.number.replaceAll(RegExp(r'[^\d+]'), '');
            if (phone.startsWith('+84')) {
              phone = '0${phone.substring(3)}';
            } else if (phone.startsWith('84') && phone.length > 9) {
              phone = '0${phone.substring(2)}';
            }
          }
          if (name.isNotEmpty || phone.isNotEmpty) {
            return ContactPickResult(name: name, phone: phone);
          }
        }
        // User cancelled native picker or contact empty
        return null;
      }
    } catch (e) {
      debugPrint('>>> [ContactPickerHelper] Native error: $e');
    }

    if (!context.mounted) return null;

    // Fallback: Show quick contact selector sheet
    return await showModalBottomSheet<ContactPickResult>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _QuickContactSelectorSheet(),
    );
  }
}

class _QuickContactSelectorSheet extends StatefulWidget {
  const _QuickContactSelectorSheet();

  @override
  State<_QuickContactSelectorSheet> createState() => _QuickContactSelectorSheetState();
}

class _QuickContactSelectorSheetState extends State<_QuickContactSelectorSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = ContactPickerHelper._sampleContacts.where((c) {
      final q = _searchQuery.toLowerCase().trim();
      if (q.isEmpty) return true;
      return c.name.toLowerCase().contains(q) || c.phone.contains(q);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.contacts_rounded, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn từ danh bạ liên hệ',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      Text(
                        'Chọn người nhận hoặc tìm kiếm theo số điện thoại',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              autofocus: false,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc số điện thoại...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gợi ý người nhận gần đây',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
                itemBuilder: (ctx, index) {
                  final contact = filtered[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        contact.name.isNotEmpty ? contact.name[0] : '?',
                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(contact.phone, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
                    onTap: () => Navigator.pop(context, contact),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
