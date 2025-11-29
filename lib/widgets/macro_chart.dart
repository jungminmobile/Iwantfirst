import 'package:flutter/material.dart';

class MacroChart extends StatelessWidget {
  final double carbs, targetCarbs;
  final double protein, targetProtein;
  final double fat, targetFat;

  // 🟢 [신규] 초과 시 적용할 강렬한 빨간색 정의
  final Color warningColor = Colors.redAccent[700]!;

  MacroChart({
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
    return Column(
      children: [
        // 각 영양소별로 바 생성 (기본 색상 전달)
        _buildHorizontalBar("탄수화물", carbs, targetCarbs, Color(0x66DB6A)),
        const SizedBox(height: 20),
        _buildHorizontalBar("단백질", protein, targetProtein, Color(0xFF7043)),
        const SizedBox(height: 20),
        _buildHorizontalBar("지방", fat, targetFat, Color(0xFDA935)),
      ],
    );
  }

  Widget _buildHorizontalBar(String label, double current, double target, Color baseColor) {
    // 퍼센트 계산 및 초과 여부 확인
    double percentage = target > 0 ? current / target : 0;
    bool isOver = percentage > 1.2;

    // 초과 여부에 따라 최종 표시 색상 결정
    Color finalColor = isOver ? warningColor : baseColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 라벨 및 수치 텍스트
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 12),
                children: [
                  TextSpan(
                    text: '${current.toInt()}g',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      // 🟢 초과 시 글자 색상을 빨갛게 변경
                      // (초과 안 했을 땐 검은색 유지)
                      color: isOver ? finalColor : Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${target.toInt()}g',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2. 가로 그래프 영역
        SizedBox(
          height: 12,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final targetPosition = totalWidth * 0.75; // 목표선 위치 (75% 지점)

              double barWidth = targetPosition * percentage;
              if (barWidth > totalWidth) barWidth = totalWidth;

              return Stack(
                children: [
                  // A. 배경 트랙
                  Container(
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),

                  // B. 실제 섭취량 막대
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutExpo,
                    width: barWidth,
                    decoration: BoxDecoration(
                      // 🟢 초과 시 그래프 바 색상을 빨갛게 변경
                      // 초과하면 불투명하게(1.0), 아니면 약간 투명하게(0.7)
                      color: finalColor.withOpacity(isOver ? 1.0 : 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),

                  // C. 목표 기준선 (점선)
                  Positioned(
                    left: targetPosition,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: Colors.black12,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}