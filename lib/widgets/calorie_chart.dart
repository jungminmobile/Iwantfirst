import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CalorieChart extends StatelessWidget {
  final double current;
  final double target;

  const CalorieChart({super.key, required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    bool isOver = target > 0 && current > target;
    double remaining = (target - current).clamp(0, target);
    double excess = (current - target).clamp(0, target);
    double transparentSection = target - excess;

    // 🟢 [수정됨] 끊김 없는 루프 그라데이션
    const Gradient simpleNeonGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0.0,
      endAngle: 3.14 * 2,
      colors: [
        Colors.cyanAccent,
        Colors.greenAccent,
        Colors.cyanAccent, // 🟢 시작 색상과 동일하게 마무리
      ],
      stops: [0.0, 0.5, 1.0],
      transform: GradientRotation(-3.14 / 2),
    );

    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // 1층: 베이스 차트
          PieChart(
            PieChartData(
              startDegreeOffset: 270,
              sectionsSpace: 0,
              centerSpaceRadius: 70,
              sections: isOver
                  ? [
                PieChartSectionData(
                  gradient: simpleNeonGradient,
                  value: 1,
                  radius: 20,
                  showTitle: false,
                ),
              ]
                  : [
                PieChartSectionData(
                  gradient: simpleNeonGradient,
                  value: current,
                  radius: 20,
                  showTitle: false,
                ),
                PieChartSectionData(
                  color: Colors.grey[100],
                  value: remaining,
                  radius: 20,
                  showTitle: false,
                ),
              ],
            ),
          ),

          // 2층: 초과분 오버레이
          if (isOver)
            PieChart(
              PieChartData(
                startDegreeOffset: 270,
                sectionsSpace: 0,
                centerSpaceRadius: 70,
                sections: [
                  PieChartSectionData(
                    color: Colors.redAccent.withOpacity(0.9),
                    value: excess,
                    radius: 25,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    color: Colors.transparent,
                    value: transparentSection,
                    radius: 20,
                    showTitle: false,
                  ),
                ],
              ),
            ),

          // 중앙 텍스트
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOver ? '⚠️ 목표 초과' : '오늘 섭취',
                  style: TextStyle(
                    fontSize: 14,
                    color: isOver ? Colors.red : Colors.grey,
                    fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  '${current.toInt()} kcal',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  '/ ${target.toInt()} kcal',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}