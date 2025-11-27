import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MacroChart extends StatelessWidget {
  final double carbs, targetCarbs;
  final double protein, targetProtein;
  final double fat, targetFat;

  const MacroChart({
    super.key,
    required this.carbs,
    required this.targetCarbs,
    required this.protein,
    required this.targetProtein,
    required this.fat,
    required this.targetFat,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260, // [수정] 3줄이 들어가야 하니 높이를 살짝 더 키움 (250 -> 260)
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 120,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => Colors.white,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                double originalValue = 0;
                switch (group.x) {
                  case 0:
                    originalValue = carbs;
                    break;
                  case 1:
                    originalValue = protein;
                    break;
                  case 2:
                    originalValue = fat;
                    break;
                }
                return BarTooltipItem(
                  '${originalValue.toInt()}g',
                  const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,

                // [수정 1] 글씨 3줄(이름, %, g)이 들어가야 해서 공간을 넉넉히 80으로 늘림
                reservedSize: 80,

                getTitlesWidget: (double value, TitleMeta meta) {
                  String label = '';
                  double current = 0;
                  double target = 1;

                  switch (value.toInt()) {
                    case 0:
                      label = '탄수화물';
                      current = carbs;
                      target = targetCarbs;
                      break;
                    case 1:
                      label = '단백질';
                      current = protein;
                      target = targetProtein;
                      break;
                    case 2:
                      label = '지방';
                      current = fat;
                      target = targetFat;
                      break;
                  }

                  // 퍼센트 계산
                  int percent = (target == 0)
                      ? 0
                      : (current / target * 100).toInt();

                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        // 1. 이름
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // 2. 퍼센트 (진한 색으로 강조)
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800, // 두껍게
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // 3. 그램 (연한 색으로 상세정보)
                        Text(
                          '${current.toInt()} / ${target.toInt()}g',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: [
            _makeBarGroup(0, carbs, targetCarbs, Colors.green),
            _makeBarGroup(1, protein, targetProtein, Colors.blue),
            _makeBarGroup(2, fat, targetFat, Colors.orange),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    /* ... 기존 로직 ... */
    return 120;
  }

  BarChartGroupData _makeBarGroup(
    int x,
    double current,
    double target,
    Color color,
  ) {
    double percentage = (target == 0) ? 0 : (current / target * 100);
    if (percentage > 120) percentage = 120;

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: percentage,
          color: color,
          width: 20,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 100,
            color: Colors.grey[200],
          ),
        ),
      ],
    );
  }
}
