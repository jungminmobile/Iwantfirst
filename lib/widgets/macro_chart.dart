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
      height: 260,
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
                        const SizedBox(height: 4),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
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
    return 120;
  }

  BarChartGroupData _makeBarGroup(
    int x,
    double current,
    double target,
    Color color,
  ) {
    // 1. 퍼센트 계산
    double percentage = (target == 0) ? 0 : (current / target * 100);

    // 2. 높이 제한
    double barHeight = (percentage > 100) ? 100 : percentage;

    // 3. 색상 로직 (빨간색이 아래에서 차오름)
    Gradient? barGradient;

    if (percentage <= 100) {
      // 100% 이하는 단색 (원래 색)
      barGradient = null;
    } else if (percentage >= 200) {
      // 200% 이상은 전체 빨강
      barGradient = const LinearGradient(
        colors: [Colors.red, Colors.red],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      );
    } else {
      // 🔥 100% ~ 200% 구간: 빨간색 게이지가 바닥부터 차오름
      // redRatio: 0.0(100%일 때) ~ 1.0(200%일 때)
      double redRatio = (percentage - 100) / 100;

      barGradient = LinearGradient(
        // 색상 배치: [빨강, 빨강, 원래색, 원래색]
        // 이렇게 같은 색을 반복해서 배치하면 그라데이션 없이 딱 잘린 색이 나옵니다.
        colors: [
          Colors.red, // 바닥
          Colors.red, // 빨간색 끝나는 지점
          color, // 원래색 시작 지점
          color, // 꼭대기
        ],
        stops: [
          0.0,
          redRatio, // 여기까지 빨간색
          redRatio, // 여기서부터 원래 색 (경계선이 칼같이 나뉨)
          1.0,
        ],
        begin: Alignment.bottomCenter, // 아래에서
        end: Alignment.topCenter, // 위로
      );
    }

    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: barHeight,
          // 그라데이션이 있으면 사용, 없으면 단색 사용
          color: barGradient == null ? color : null,
          gradient: barGradient,
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
