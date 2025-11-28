import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class CalorieChart extends StatelessWidget {
  final double current;
  final double target;

  const CalorieChart({super.key, required this.current, required this.target});

  @override
  Widget build(BuildContext context) {
    double percentage = (target == 0) ? 0 : current / target;

    return Padding(
      padding: const EdgeInsets.only(top: 30.0),
      child: SizedBox(
        height: 220,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: 180,
                pieTouchData: PieTouchData(enabled: false),
                centerSpaceRadius: 70,
                sectionsSpace: 0,
                sections: [
                  // 1. 데이터 섹션
                  PieChartSectionData(
                    value: _getChartValue(percentage),
                    color: Colors.transparent,
                    radius: 40,
                    showTitle: false,
                    gradient: _getDynamicGradient(percentage), // 🔥 여기가 핵심
                  ),
                  // 2. 남은 목표 섹션
                  PieChartSectionData(
                    value: _getRemainingValue(percentage),
                    color: Colors.grey[200],
                    radius: 40,
                    showTitle: false,
                  ),
                  // 3. 투명 섹션
                  PieChartSectionData(
                    value: 100,
                    color: Colors.transparent,
                    radius: 40,
                    showTitle: false,
                  ),
                ],
              ),
            ),

            // 중앙 텍스트
            Padding(
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

  double _getChartValue(double percentage) {
    if (percentage > 1.0) return 100.0;
    return percentage * 100;
  }

  double _getRemainingValue(double percentage) {
    if (percentage > 1.0) return 0.0;
    return 100 - (percentage * 100);
  }

  // 🔥 [최종] 3단계 그라데이션 로직
  Gradient _getDynamicGradient(double percentage) {
    // ✅ 1단계: 0% ~ 80% (원하시던 파랑->초록 그라데이션 유지)
    if (percentage < 0.8) {
      return const LinearGradient(
        colors: [Color(0xFF33CCFF), Color(0xFF33CC00)], // 파랑 -> 초록
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }
    // ✅ 2단계: 80% ~ 100% (오른쪽에서 초록색 덩어리가 밀고 들어옴)
    else if (percentage <= 1.0) {
      double progress = (percentage - 0.8) / 0.2; // 0.0 ~ 1.0 진행률
      double splitPoint = 1.0 - progress; // 오른쪽에서 왼쪽으로 이동

      return LinearGradient(
        colors: const [
          Color(0xFF33CCFF), // 왼쪽: 파랑 (기존 그라데이션 시작)
          Color(0xFF33CC00), // 중간: 초록 (기존 그라데이션 끝)
          Color(0xFF33CC00), // 중간: 단색 초록 시작
          Color(0xFF33CC00), // 오른쪽: 단색 초록
        ],
        stops: [
          0.0,
          (splitPoint - 0.1).clamp(0.0, 1.0), // 기존 그라데이션이 밀려나는 지점
          (splitPoint + 0.1).clamp(0.0, 1.0), // 단색 초록이 시작되는 지점
          1.0,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }
    // ✅ 3단계: 200% 이상 (완전 빨강)
    else if (percentage >= 2.0) {
      return const LinearGradient(
        colors: [Colors.red, Colors.red],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }
    // ✅ 4단계: 100% ~ 200% (오른쪽에서 빨간색 덩어리가 밀고 들어옴)
    else {
      double progress = percentage - 1.0;
      double splitPoint = 1.0 - progress;

      return LinearGradient(
        colors: const [
          Color(0xFF33CC00), // 왼쪽: 초록
          Color(0xFF33CC00), // 중간: 초록
          Colors.red, // 중간: 빨강
          Colors.red, // 오른쪽: 빨강
        ],
        stops: [
          0.0,
          (splitPoint - 0.15).clamp(0.0, 1.0), // 부드러운 경계선
          (splitPoint + 0.15).clamp(0.0, 1.0),
          1.0,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );
    }
  }
}
