import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/space_models.dart';

class PayloadComparisonChart extends StatelessWidget {
  final List<LaunchVehicleModel> vehicles;

  const PayloadComparisonChart({
    super.key,
    required this.vehicles,
  });

  static const _targetSlugs = ['lvm3', 'pslv', 'vikram-1', 'agnibaan'];

  @override
  Widget build(BuildContext context) {
    final ordered = <LaunchVehicleModel>[];
    for (final slug in _targetSlugs) {
      final match = vehicles.where((v) => v.slug == slug);
      if (match.isNotEmpty) {
        ordered.add(match.first);
      }
    }
    final chartVehicles = ordered.isNotEmpty ? ordered : vehicles.take(4).toList();

    if (chartVehicles.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxPayload = chartVehicles.fold<double>(
      1000,
      (prev, v) => max(
        prev,
        max(
          (v.leoPayloadKg ?? 0).toDouble(),
          (v.gtoPayloadKg ?? 0).toDouble(),
        ),
      ),
    );
    final maxY = ((maxPayload / 2000).ceil() * 2000).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payload Capacity Comparison (kg)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Wrap(
              spacing: 16,
              children: [
                _LegendDot(color: AppTheme.orbitalCyan, label: 'LEO Capacity'),
                _LegendDot(color: AppTheme.saffronAccent, label: 'GTO Capacity'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 230,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppTheme.borderSubtle,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceElevated,
                      getTooltipItem: (group, _, rod, rodIndex) {
                        final vehicle = chartVehicles[group.x.toInt()];
                        final orbit = rodIndex == 0 ? 'LEO' : 'GTO';
                        return BarTooltipItem(
                          '${vehicle.name}\n$orbit: ${rod.toY.toInt()} kg',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: maxY / 5,
                        getTitlesWidget: (value, _) {
                          if (value == 0) {
                            return const Text(
                              '0',
                              style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                            );
                          }
                          final label = '${(value / 1000).toStringAsFixed(0)}t';
                          return Text(
                            label,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= chartVehicles.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              chartVehicles[idx].name,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(chartVehicles.length, (index) {
                    final v = chartVehicles[index];
                    return BarChartGroupData(
                      x: index,
                      barsSpace: 6,
                      barRods: [
                        BarChartRodData(
                          toY: (v.leoPayloadKg ?? 0).toDouble(),
                          color: AppTheme.orbitalCyan,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                        BarChartRodData(
                          toY: (v.gtoPayloadKg ?? 0).toDouble(),
                          color: AppTheme.saffronAccent,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
        ),
      ],
    );
  }
}