import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/services/ai_cargo_advisor_service.dart';

/// Interactive AI Cargo & Vehicle Advisor Widget.
/// Placed at the top of Step 2 (Package Details) in Order Creation Flow.
class AiCargoAdvisorWidget extends StatefulWidget {
  final ValueChanged<CargoRecommendation> onApplyRecommendation;
  final String? initialDescription;
  final int dropoffCount;

  const AiCargoAdvisorWidget({
    super.key,
    required this.onApplyRecommendation,
    this.initialDescription,
    this.dropoffCount = 1,
  });

  @override
  State<AiCargoAdvisorWidget> createState() => _AiCargoAdvisorWidgetState();
}

class _AiCargoAdvisorWidgetState extends State<AiCargoAdvisorWidget> {
  late final TextEditingController _inputController;
  bool _isLoading = false;
  CargoRecommendation? _recommendation;
  String? _errorMessage;

  final List<Map<String, String>> _presets = [
    {
      'label': 'Dọn phòng trọ',
      'text': 'Tôi dọn phòng trọ gồm: 1 tủ lạnh đứng 180L, 1 máy giặt 8kg, 1 đệm gấp và 4 thùng carton đồ đạc.',
    },
    {
      'label': 'Chuyển căn hộ 1PN',
      'text': 'Dọn căn hộ 1 phòng ngủ: 1 sofa góc dài 2m2, 1 giường ngủ 1m8, 1 tủ quần áo 3 cánh và 6 thùng carton.',
    },
    {
      'label': 'Chuyển văn phòng',
      'text': 'Chuyển văn phòng nhỏ: 3 bàn làm việc, 3 ghế xoay công thái học, 1 tủ hồ sơ tài liệu và 5 thùng hồ sơ.',
    },
    {
      'label': 'Giao 10 thùng carton',
      'text': 'Giao 10 thùng carton tiêu chuẩn kích thước 60x40x40cm, tổng cân nặng khoảng 150kg.',
    },
    {
      'label': 'Tủ lạnh & Máy giặt',
      'text': 'Vận chuyển 1 tủ lạnh 250L cần chở đứng để bảo vệ block máy và 1 máy giặt cửa ngang 9kg.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _inputController = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _analyzeCargo() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập danh sách đồ đạc hoặc chọn mẫu gợi ý!'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rec = await AiCargoAdvisorService.analyzeCargo(
        text,
        dropoffCount: widget.dropoffCount,
      );
      if (mounted) {
        setState(() {
          _recommendation = rec;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể phân tích: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _recommendation != null ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFEFF6FF),
                  Colors.white.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Trợ lý Chọn xe & Hàng hóa',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Phân tích đồ đạc, tự động đề xuất loại xe chuẩn xác',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Preset Chips Row
                const Text(
                  'Chọn mẫu nhanh hoặc tự nhập đồ đạc:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _presets.map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(
                            p['label']!,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          onPressed: () {
                            setState(() {
                              _inputController.text = p['text']!;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 10),

                // Free-text Input
                TextField(
                  controller: _inputController,
                  maxLines: 2,
                  minLines: 1,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ví dụ: 1 tủ lạnh 180L chở đứng, 1 máy giặt, 4 thùng đồ...',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    fillColor: AppColors.background,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    suffixIcon: _inputController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              setState(() {
                                _inputController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() {}),
                ),

                const SizedBox(height: 10),

                // Analyze Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isLoading ? null : _analyzeCargo,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 16),
                    label: Text(
                      _isLoading ? 'Đang phân tích đồ đạc...' : 'AI Phân tích & Gợi ý xe',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],

                // Result Card
                if (_recommendation != null) ...[
                  const SizedBox(height: 14),
                  _buildRecommendationCard(_recommendation!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(CargoRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Recommended Badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  rec.vehicleType.icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            rec.vehicleName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.primaryDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Khuyên dùng',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tải trọng tối đa: ${rec.vehicleType.maxWeight}kg',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 10),

          // Estimated Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.scale_rounded,
                  label: 'Ước tính tải',
                  value: '~${rec.estimatedWeightKg} kg',
                  color: AppColors.primary,
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.view_in_ar_rounded,
                  label: 'Thể tích ước tính',
                  value: '~${rec.estimatedVolumeM3.toStringAsFixed(1)} m³',
                  color: AppColors.accent,
                ),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.category_rounded,
                  label: 'Nhóm phân loại',
                  value: rec.weightCategoryChip,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),

          // Feature Badges (Standing, Fragile, Tailgate, Porter)
          if (rec.requiresStanding ||
              rec.isFragile ||
              rec.requiresTailgate ||
              rec.requiresPorter ||
              rec.hasLongDimensions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (rec.requiresStanding)
                  _buildFeatureChip(
                    icon: Icons.vertical_align_top_rounded,
                    label: 'Cần chở đứng (Tủ lạnh)',
                    bgColor: const Color(0xFFFEF2F2),
                    textColor: const Color(0xFFDC2626),
                  ),
                if (rec.isFragile)
                  _buildFeatureChip(
                    icon: Icons.shield_outlined,
                    label: 'Hàng dễ vỡ / Điện tử',
                    bgColor: const Color(0xFFFFFBEB),
                    textColor: const Color(0xFFD97706),
                  ),
                if (rec.requiresTailgate)
                  _buildFeatureChip(
                    icon: Icons.elevator_rounded,
                    label: 'Khuyên dùng bửng nâng',
                    bgColor: const Color(0xFFF3E8FF),
                    textColor: const Color(0xFF7E22CE),
                  ),
                if (rec.requiresPorter)
                  _buildFeatureChip(
                    icon: Icons.front_hand_rounded,
                    label: 'Khuyên đặt bốc xếp',
                    bgColor: const Color(0xFFEFF6FF),
                    textColor: const Color(0xFF2563EB),
                  ),
                if (rec.hasLongDimensions)
                  _buildFeatureChip(
                    icon: Icons.straighten_rounded,
                    label: 'Đồ dài >2m',
                    bgColor: const Color(0xFFF0FDF4),
                    textColor: const Color(0xFF16A34A),
                  ),
              ],
            ),
          ],

          // Reasoning Text
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 14, color: Color(0xFFD97706)),
                    SizedBox(width: 4),
                    Text(
                      'Lý do AI đề xuất:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rec.reasoning,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
                if (rec.driverNoteAdvice.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Lưu ý tài xế: "${rec.driverNoteAdvice}"',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Stowage Plan Card (Sơ đồ xếp thùng xe thông minh LIFO)
          const SizedBox(height: 10),
          _buildStowagePlanCard(rec),

          // Apply Button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => widget.onApplyRecommendation(rec),
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text(
                'Áp dụng đề xuất này vào đơn',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStowagePlanCard(CargoRecommendation rec) {
    final plan = rec.stowagePlan;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with LIFO Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.view_in_ar_rounded, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Sơ đồ xếp thùng xe thông minh',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Text(
                  'Chuẩn LIFO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 3-Zone Compartment Layout
          // Zone 1: Cửa sau (Dỡ trước / Điểm 1)
          _buildCompartmentZone(
            icon: Icons.meeting_room_outlined,
            tag: 'CỬA SAU • DỠ TRƯỚC (ĐIỂM 1)',
            content: plan.doorSide,
            bgColor: const Color(0xFFF0FDF4),
            borderColor: const Color(0xFFBBF7D0),
            tagColor: const Color(0xFF16A34A),
          ),
          const SizedBox(height: 6),

          // Zone 2: Giữa thùng
          _buildCompartmentZone(
            icon: Icons.inventory_2_outlined,
            tag: 'GIỮA THÙNG • HÀNG VỪA & CHÈN LÓT',
            content: plan.middleSection,
            bgColor: const Color(0xFFFFFBEB),
            borderColor: const Color(0xFFFDE68A),
            tagColor: const Color(0xFFD97706),
          ),
          const SizedBox(height: 6),

          // Zone 3: Sát Cabin (Dỡ sau cùng / Trọng tâm)
          _buildCompartmentZone(
            icon: Icons.local_shipping_outlined,
            tag: 'SÁT CABIN • DỠ SAU (TRỌNG TÂM)',
            content: plan.cabinSide,
            bgColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFBFDBFE),
            tagColor: const Color(0xFF2563EB),
          ),

          // Stacking & Safety Advice
          if (plan.stackingAdvice.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.tips_and_updates_rounded, size: 14, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      plan.stackingAdvice,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Recommended Supplies
          if (rec.recommendedSupplies.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Vật tư đóng gói & bọc lót đề xuất:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: rec.recommendedSupplies.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          s,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],

          // Handling Time Estimate
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dự kiến thời gian bốc xếp: ~${rec.estimatedHandlingMinutes} phút',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompartmentZone({
    required IconData icon,
    required String tag,
    required String content,
    required Color bgColor,
    required Color borderColor,
    required Color tagColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: tagColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: tagColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
