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
      height: 250,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 120, // 100% 기준으로 여유 있게
          // 툴팁: 터치하면 정확한 g수 보여줌
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
                // [수정 1] 두 줄(이름 + %)이 들어가야 하므로 공간을 더 넉넉하게 잡음 (50 -> 60)
                reservedSize: 60,

                // [수정 2] 이름 밑에 퍼센트를 같이 보여주는 로직
                getTitlesWidget: (double value, TitleMeta meta) {
                  String label = '';
                  double current = 0;
                  double target = 1; // 0 나누기 방지용

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
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4), // 간격
                        Text(
                          '$percent%', // 퍼센트 표시 추가!
                          style: TextStyle(
                            color: Colors.grey[600], // 약간 연한 색으로
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
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
            toY: 100, // 목표치 높이 (100%)
            color: Colors.grey[200],
          ),
        ),
      ],
    );
  }
}
