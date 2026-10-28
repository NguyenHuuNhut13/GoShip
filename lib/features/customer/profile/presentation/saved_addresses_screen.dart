import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/saved_address_service.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  List<SavedAddressModel> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    final list = await SavedAddressService.getSavedAddresses();
    if (!mounted) return;
    setState(() {
      _addresses = list;
      _isLoading = false;
    });
  }

  void _showAddEditModal([SavedAddressModel? existing]) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final detailsCtrl = TextEditingController(text: existing?.details ?? '');
    String iconType = existing?.iconType ?? 'home';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                existing != null ? 'Chỉnh sửa địa chỉ' : 'Thêm địa chỉ mới',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // Type selector chips
              Row(
                children: [
                  _buildTypeChip('home', 'Nhà riêng', Icons.home_rounded, iconType, (val) => setModalState(() => iconType = val)),
                  const SizedBox(width: 8),
                  _buildTypeChip('work', 'Công ty', Icons.business_rounded, iconType, (val) => setModalState(() => iconType = val)),
                  const SizedBox(width: 8),
                  _buildTypeChip('warehouse', 'Kho hàng', Icons.warehouse_rounded, iconType, (val) => setModalState(() => iconType = val)),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tên gợi nhớ (VD: Nhà riêng, Kho tổng...)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrCtrl,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ chi tiết (Đường, Phường, Quận...)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detailsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm (Số nhà, Số tầng, Tòa nhà...)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    if (labelCtrl.text.trim().isEmpty || addrCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Vui lòng điền tên gợi nhớ và địa chỉ')),
                      );
                      return;
                    }

                    final model = SavedAddressModel(
                      id: existing?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
                      label: labelCtrl.text.trim(),
                      address: addrCtrl.text.trim(),
                      details: detailsCtrl.text.trim(),
                      iconType: iconType,
                      latitude: existing?.latitude ?? 10.7946,
                      longitude: existing?.longitude ?? 106.7218,
                    );

                    await SavedAddressService.saveAddress(model);
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadAddresses();
                  },
                  child: const Text('Lưu địa chỉ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String title, IconData icon, String current, Function(String) onSelect) {
    final isSelected = type == current;
    return InkWell(
      onTap: () => onSelect(type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Địa chỉ đã lưu',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
            onPressed: () => _showAddEditModal(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off_outlined, size: 60, color: AppColors.textMuted),
                      const SizedBox(height: 14),
                      const Text('Chưa có địa chỉ nào được lưu', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Lưu các địa chỉ thường xuyên giao nhận để đặt đơn nhanh hơn', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        onPressed: () => _showAddEditModal(),
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Thêm địa chỉ ngay', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final item = _addresses[idx];
                    IconData iconData = Icons.location_on_rounded;
                    Color iconColor = AppColors.primary;

                    if (item.iconType == 'home') {
                      iconData = Icons.home_rounded;
                      iconColor = const Color(0xFF2563EB);
                    } else if (item.iconType == 'work') {
                      iconData = Icons.business_rounded;
                      iconColor = const Color(0xFF0284C7);
                    } else if (item.iconType == 'warehouse') {
                      iconData = Icons.warehouse_rounded;
                      iconColor = const Color(0xFFD97706);
                    }

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(iconData, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.address,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.3),
                                ),
                                if (item.details.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.details,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                _showAddEditModal(item);
                              } else if (val == 'delete') {
                                await SavedAddressService.deleteAddress(item.id);
                                _loadAddresses();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                              const PopupMenuItem(value: 'delete', child: Text('Xóa địa chỉ', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
