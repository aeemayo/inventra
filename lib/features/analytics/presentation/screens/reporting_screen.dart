import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_sizes.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import 'package:fl_chart/fl_chart.dart';

/// Reporting screen matching Figma:
/// - Revenue header cards ($42,590 and 1,245)
/// - Stock Trends chart
/// - Top Movers horizontal list
/// - Recent Activity log
class ReportingScreen extends ConsumerWidget {
  const ReportingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Reporting')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Revenue Cards
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Revenue', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('\$42,590', style: AppTypography.statMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.trending_up, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('+12.5%', style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Units Sold', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('1,245', style: AppTypography.statMedium),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.trending_up, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text('+8.3%', style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xxl),

            // Stock Trends
            Text('Stock Trends', style: AppTypography.h4),
            const SizedBox(height: AppSizes.md),
            AppCard(
              child: SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    barTouchData: BarTouchData(enabled: true),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                            return Text(days[v.toInt() % 7], style: const TextStyle(fontSize: 10, color: AppColors.textTertiary));
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: false),
                    barGroups: List.generate(7, (i) {
                      final vals = [65, 80, 45, 90, 55, 70, 85];
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: vals[i].toDouble(), color: AppColors.primary, width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                      ]);
                    }),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xxl),

            // Top Movers
            Text('Top Movers', style: AppTypography.h4),
            const SizedBox(height: AppSizes.md),
            SizedBox(
              height: 120,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TopMoverCard(name: 'Wireless Mouse', sold: 48, revenue: 1199.52),
                  _TopMoverCard(name: 'USB-C Cable', sold: 35, revenue: 279.65),
                  _TopMoverCard(name: 'Phone Charger', sold: 28, revenue: 419.72),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xxl),

            // Recent Activity
            Text('Recent Activity', style: AppTypography.h4),
            const SizedBox(height: AppSizes.md),
            _ActivityItem(icon: Icons.shopping_bag, text: 'Sale: Wireless Mouse x2', time: '2h ago', color: AppColors.success),
            _ActivityItem(icon: Icons.inventory, text: 'Restock: USB Cable x50', time: '4h ago', color: AppColors.info),
            _ActivityItem(icon: Icons.edit, text: 'Updated: Phone Charger price', time: 'Yesterday', color: AppColors.warning),
            const SizedBox(height: AppSizes.xxl),
          ],
        ),
      ),
    );
  }
}

class _TopMoverCard extends StatelessWidget {
  final String name;
  final int sold;
  final double revenue;
  const _TopMoverCard({required this.name, required this.sold, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.primarySurface, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.primary)),
            const SizedBox(height: 8),
            Text(name, style: AppTypography.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('$sold sold', style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
            Text(Formatters.currency(revenue), style: AppTypography.labelMedium.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final String time;
  final Color color;
  const _ActivityItem({required this.icon, required this.text, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTypography.bodyMedium)),
          Text(time, style: AppTypography.bodySmall.copyWith(color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
