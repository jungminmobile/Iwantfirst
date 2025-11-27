import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CalorieChart extends StatelessWidget {
  final double current;
  final double target;

  const CalorieChart({super.key, required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    // 남은 칼로리 계산 (음수가 되지 않도록 처리)
    final double remaining = (target - current).clamp(0, target);

    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: 270, // 12시 방향부터 시작
              sectionsSpace: 0,
              centerSpaceRadius: 70, // 도넛 모양으로 만들기 위해 중앙 비우기
              sections: [
                // 섭취한 칼로리 (색상 표시)
                PieChartSectionData(
                  //color: Colors.blueAccent,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF33FFFF), // 하늘색 (시작)
                      Color(0xFF33FF99), // 중간
                      Color(0xFF33FF00), // 연두색 (끝)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomRight,
                  ),
                  value: current,
                  title: '',
                  radius: 20,
                  showTitle: false,
                ),
                // 남은 칼로리 (회색 표시)
                PieChartSectionData(
                  color: Colors.grey[200],
                  value: remaining,
                  title: '',
                  radius: 20,
                  showTitle: false,
                ),
              ],
            ),
          ),
          // 그래프 중앙에 텍스트 표시
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '오늘 섭취',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                Text(
                  '${current.toInt()} kcal',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
