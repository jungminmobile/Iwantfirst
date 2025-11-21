import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MacroChart extends StatelessWidget {
  final double carbs, targetCarbs;
  final double protein, targetProtein;
  final double fat, targetFat;

  const MacroChart({
    super.key,
    required this.carbs, required this.targetCarbs,
    required this.protein, required this.targetProtein,
    required this.fat, required this.targetFat,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _calculateMaxY(), // 그래프 최대 높이 자동 계산
          barTouchData: BarTouchData(enabled: false), // 터치 효과 끄기
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  const style = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14);
                  switch (value.toInt()) {
                    case 0: return const Text('탄수화물', style: style);
                    case 1: return const Text('단백질', style: style);
                    case 2: return const Text('지방', style: style);
                    default: return const Text('');
                  }
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // 왼쪽 수치 숨김
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barGroups: [
            _makeBarGroup(0, carbs, targetCarbs, Colors.green), // 탄수화물
            _makeBarGroup(1, protein, targetProtein, Colors.orange), // 단백질
            _makeBarGroup(2, fat, targetFat, Colors.redAccent), // 지방
          ],
        ),
      ),
    );
  }

  // 그래프의 최대 Y축 값을 목표치 중 가장 큰 값 + 20% 여유분으로 설정
  double _calculateMaxY() {
    double maxVal = targetCarbs;
    if (targetProtein > maxVal) maxVal = targetProtein;
    if (targetFat > maxVal) maxVal = targetFat;
    return maxVal * 1.2;
  }

  // 개별 막대 생성 함수
  BarChartGroupData _makeBarGroup(int x, double current, double target, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: current, // 현재 섭취량
          color: color,
          width: 20,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: target, // 목표량 (회색 배경으로 표시)
            color: Colors.grey[200],
          ),
        ),
      ],
    );
  }
}