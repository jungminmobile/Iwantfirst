import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CalorieChart extends StatelessWidget {
  final double current;
  final double target;

  const CalorieChart({super.key, required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    double percentage = (target == 0) ? 0 : current / target;

    // [수정 1] 상단 여백 추가: '칼로리 현황' 텍스트와 겹치지 않도록 Padding으로 감쌌습니다.
    return Padding(
      padding: const EdgeInsets.only(top: 30.0),
      child: SizedBox(
        // [수정 2] 높이 증가: 그래프 전체 크기를 키우기 위해 높이를 늘렸습니다. (150 -> 220)
        height: 220,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: 180,
                pieTouchData: PieTouchData(enabled: false),
                // [수정 3] 중앙 공간 조절: 그래프가 두꺼워진 만큼 중앙 빈 공간을 살짝 줄였습니다. (80 -> 70)
                centerSpaceRadius: 70,
                sectionsSpace: 0,
                sections: [
                  // 1. 섭취량 섹션
                  PieChartSectionData(
                    value: _getChartValue(percentage),
                    color: Colors.transparent,
                    // [수정 4] 두께 증가: radius 값을 키워 그래프를 두껍게 만들었습니다. (25 -> 40)
                    radius: 40,
                    showTitle: false,
                    gradient: _getDynamicGradient(percentage),
                  ),
                  // 2. 남은 목표 섹션
                  PieChartSectionData(
                    value: _getRemainingValue(percentage),
                    color: Colors.grey[200],
                    // [수정 4] 두께 증가: (25 -> 40)
                    radius: 40,
                    showTitle: false,
                  ),
                  // 3. 투명 섹션 (반원 만들기용)
                  PieChartSectionData(
                    value: 100,
                    color: Colors.transparent,
                    // [수정 4] 두께 증가: (25 -> 40)
                    radius: 40,
                    showTitle: false,
                  ),
                ],
              ),
            ),

            // 중앙 텍스트
            Padding(
              // [수정 5] 텍스트 위치 조정: 그래프가 커진 만큼 텍스트 위치도 아래로 조정했습니다.
              padding: const EdgeInsets.only(bottom: 35),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '오늘 섭취',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${current.toInt()} kcal',
                    // [수정 6] 폰트 크기 증가: 그래프에 맞춰 글씨도 키웠습니다.
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '/ ${target.toInt()} kcal',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (아래 메서드들은 기존과 동일합니다)
  double _getChartValue(double percentage) {
    if (percentage > 1.0) return 100.0;
    return percentage * 100;
  }

  double _getRemainingValue(double percentage) {
    if (percentage > 1.0) return 0.0;
    return 100 - (percentage * 100);
  }

  Gradient _getDynamicGradient(double percentage) {
    List<Color> colors;
    if (percentage <= 1.0) {
      colors = [const Color(0xFF33CCFF), const Color(0xFF33CC00)];
    } else {
      colors = [const Color(0xFF33CC00), Colors.red];
    }
    return LinearGradient(
      colors: colors,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );
  }
}
