import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/gemini_service.dart';

class ExpandableAiCard extends StatefulWidget {
  final Map<String, dynamic> userData; // 사용자 목표 정보
  final List<Map<String, dynamic>> mealDetails; // 오늘 먹은 음식 리스트
  final double totalCalories;
  final double totalCarbs;
  final double totalProtein;
  final double totalFat;

  const ExpandableAiCard({
    super.key,
    required this.userData,
    required this.mealDetails,
    required this.totalCalories,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
  });

  @override
  State<ExpandableAiCard> createState() => _ExpandableAiCardState();
}

class _ExpandableAiCardState extends State<ExpandableAiCard> {
  bool _isExpanded = false; // 카드가 펼쳐졌는지 여부
  bool _isLoading = false;  // AI 분석 중인지 여부
  String? _aiFeedback;      // AI 응답 내용

  String get _advisorName {
    // 1. 안전하게 데이터 꺼내기
    final profile = widget.userData['profile'] as Map<String, dynamic>?;
    final advisorKey = profile?['advisor'] as String? ?? 'trainer'; // 기본값 트레이너

    // 2. ID를 한글 호칭으로 변환
    switch (advisorKey) {
      case 'mother':
        return '엄마';
      case 'girlfriend':
        return '여자친구';
      case 'boyfriend': //
        return '남자친구';
      case 'trainer':
        return '트레이너';
      case 'doctor':
        return '의사 선생님';
      case 'mad_scientist':
        return '미친 과학자';
      case 'marine':
        return '해병대';
      default:
        return 'AI';
    }
  }

  // AI에게 조언 요청하는 함수
  // 🟢 forceRefresh가 true면 기존 내용을 무시하고 새로 받아옴
  Future<void> _getAdvice({bool forceRefresh = false}) async {
    // 1. 데이터 없음 체크
    if (widget.totalCalories == 0) {
      if (mounted) {
        setState(() {
          _isExpanded = true;
          _aiFeedback = "아직 기록된 식사가 없어요. 식단을 먼저 기록해주세요! 🍽️";
        });
      }
      return;
    }

    // 2. 이미 내용이 있고, 강제 새로고침이 아니면 -> 그냥 펼치기/접기만 함
    if (_aiFeedback != null && !forceRefresh) {
      setState(() {
        _isExpanded = !_isExpanded;
      });
      return;
    }

    // 3. 분석 시작 (로딩 표시)
    setState(() {
      _isExpanded = true; // 분석할 땐 무조건 펼침
      _isLoading = true;
      _aiFeedback = null; // 기존 내용 지움 (새로고침 느낌 나게)
    });

    try {
      String nutritionJson = jsonEncode({
        "total_calories": widget.totalCalories,
        "total_carbs": widget.totalCarbs,
        "total_protein": widget.totalProtein,
        "total_fat": widget.totalFat,
        "meal_details": widget.mealDetails
      });

      final feedback = await GeminiService().generateAdvice(nutritionJson, widget.userData);

      if (mounted) {
        setState(() {
          _aiFeedback = feedback;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiFeedback = "오류가 발생했어요. 잠시 후 다시 시도해주세요.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isExpanded
            ? LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: _isExpanded ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded ? Colors.deepPurple.shade100 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: _isExpanded
                ? Colors.deepPurple.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🟢 헤더 영역
          Row(
            children: [
              // 전체를 감싸는 GestureDetector (펼치기/접기용)
              Expanded(
                child: InkWell(
                  onTap: () => _getAdvice(forceRefresh: false),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _isExpanded ? Colors.white : Colors.deepPurple.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$_advisorName에게 조언 듣기",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 🟢 [신규] 새로고침 버튼 (펼쳐졌을 때만 보임)
              if (_isExpanded)
                IconButton(
                  onPressed: _isLoading
                      ? null // 로딩 중엔 버튼 비활성화
                      : () => _getAdvice(forceRefresh: true), // 강제 새로고침
                  icon: const Icon(Icons.refresh, color: Colors.deepPurpleAccent),
                  tooltip: "새로운 조언 받기",
                ),

              // 접기/펼치기 화살표
              InkWell( // 아이콘 클릭 잘 되게 감쌈
                onTap: () => _getAdvice(forceRefresh: false),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),

          // 내용물 영역
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      CircularProgressIndicator(strokeWidth: 2),
                      SizedBox(height: 10),
                      Text("오늘 식단을 분석하고 있어요...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              Text(
                _aiFeedback ?? "",
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
          ],
        ],
      ),
    );
  }
}