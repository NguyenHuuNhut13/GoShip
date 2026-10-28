import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/app_colors.dart';

class DriverWeeklyRevenueChartCard extends StatelessWidget {
  final List<int> dailyRevenues;
  final List<int> dailyTrips;
  final List<DateTime> weekDays;
  final int weekTotalGross;
  final int weekTotalNet;
  final int weekPlatformFee;
  final int weekTotalTrips;
  final int maxDailyRevenue;
  final int currentWeekday;

  const DriverWeeklyRevenueChartCard({
    super.key,
    required this.dailyRevenues,
    required this.dailyTrips,
    required this.weekDays,
    required this.weekTotalGross,
    required this.weekTotalNet,
    required this.weekPlatformFee,
    required this.weekTotalTrips,
    required this.maxDailyRevenue,
    required this.currentWeekday,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat('#,###', 'vi_VN');
    final dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final weekStartStr =
        '${weekDays.first.day.toString().padLeft(2, '0')}/${weekDays.first.month.toString().padLeft(2, '0')}';
    final weekEndStr =
        '${weekDays.last.day.toString().padLeft(2, '0')}/${weekDays.last.month.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Doanh thu tuần này',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$weekStartStr - $weekEndStr',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '+${currencyFormat.format(weekTotalNet)} đ',
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3 Quick KPI Chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildKpiItem(
                    'Tổng cước',
                    '${currencyFormat.format(weekTotalGross)} đ',
                    AppColors.textPrimary,
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                Expanded(
                  child: _buildKpiItem(
                    'Thực nhận (85%)',
                    '${currencyFormat.format(weekTotalNet)} đ',
                    const Color(0xFF059669),
                  ),
                ),
                Container(width: 1, height: 24, color: const Color(0xFFCBD5E1)),
                Expanded(
                  child: _buildKpiItem(
                    'Số chuyến',
                    '$weekTotalTrips cuốc',
                    const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 7-Day Bar Chart
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = (i + 1) == currentWeekday;
                final rev = dailyRevenues[i];
                final trips = dailyTrips[i];
                final double barRatio =
                    maxDailyRevenue > 0 ? (rev / maxDailyRevenue) : 0.0;
                // Chiều cao thanh cột tối đa 85px, tối thiểu 6px
                final double barHeight = rev > 0 ? (12.0 + barRatio * 73.0) : 6.0;

                final revLabel = rev >= 1000000
                    ? '${(rev / 1000000).toStringAsFixed(1)}M'
                    : (rev > 0 ? '${(rev / 1000).toInt()}k' : '0');

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Label value trên đầu cột
                        Text(
                          revLabel,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday
                                ? AppColors.primary
                                : (rev > 0
                                    ? AppColors.textPrimary
                                    : const Color(0xFF94A3B8)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Thanh cột biểu đồ
                        Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 22,
                              height: 90,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            Container(
                              width: 22,
                              height: barHeight,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isToday
                                      ? [
                                          const Color(0xFF2563EB),
                                          const Color(0xFF60A5FA),
                                        ]
                                      : (rev > 0
                                          ? [
                                              const Color(0xFF059669),
                                              const Color(0xFF34D399),
                                            ]
                                          : [
                                              const Color(0xFFCBD5E1),
                                              const Color(0xFFE2E8F0),
                                            ]),
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isToday && rev > 0
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF2563EB)
                                              .withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Tên ngày (T2, T3, ...)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: isToday
                              ? BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : null,
                          child: Text(
                            dayLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  isToday ? FontWeight.w800 : FontWeight.w600,
                              color:
                                  isToday ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (trips > 0 && !isToday)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '$trips c',
                              style: const TextStyle(
                                fontSize: 8,
                                color: Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else if (isToday)
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'Nay',
                              style: TextStyle(
                                fontSize: 8,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Footnote: Chiết khấu nền tảng
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Text(
                  'Chiết khấu nền tảng GoShip (15%):',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '-${currencyFormat.format(weekPlatformFee)} đ',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String title, String val, Color valColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: valColor,
            ),
          ),
        ),
      ],
    );
  }
}
