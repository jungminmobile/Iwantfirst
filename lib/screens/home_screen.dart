import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 기존 위젯 import
import '../widgets/calorie_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 기본값 설정
  double _currentCal = 0;
  double _targetCal = 2000;

  double _currentCarbs = 0;
  double _targetCarbs = 250;

  double _currentProtein = 0;
  double _targetProtein = 120;

  double _currentFat = 0;
  double _targetFat = 60;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTodayData();
  }

  // 🔥 오늘 데이터 가져오기 (새로고침 시 실행될 함수)
  Future<void> _fetchTodayData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. 목표 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('goals')) {
        var goals = userDoc.data()!['goals'];
        if (mounted) {
          setState(() {
            if (goals['target_calories'] != null) {
              _targetCal = (goals['target_calories'] as num).toDouble();
            }
            // 탄단지 목표 - DB에 있으면 가져오고, 없으면 비율로 계산
            _targetCarbs = (_targetCal * 0.5) / 4;
            _targetProtein = (_targetCal * 0.3) / 4;
            _targetFat = (_targetCal * 0.2) / 9;
          });
        }
      }

      // 2. 오늘 식단 가져오기
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mealsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_logs')
          .doc(today)
          .collection('meals')
          .get();

      double tempCal = 0;
      double tempCarbs = 0;
      double tempProtein = 0;
      double tempFat = 0;

      for (var doc in mealsSnapshot.docs) {
        var data = doc.data();
        if (data['foods'] != null && data['foods'] is List) {
          List<dynamic> foods = data['foods'];
          for (var food in foods) {
            double safeParse(dynamic value) {
              if (value == null) return 0.0;
              if (value is num) return value.toDouble();
              if (value is String) return double.tryParse(value) ?? 0.0;
              return 0.0;
            }

            tempCal += safeParse(food['calories']);
            tempCarbs += safeParse(food['carbs']);
            tempProtein += safeParse(food['protein']);
            tempFat += safeParse(food['fat']);
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentCal = tempCal;
          _currentCarbs = tempCarbs;
          _currentProtein = tempProtein;
          _currentFat = tempFat;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("❌ 홈 데이터 불러오기 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 오늘 날짜 표시용 (예: 11월 27일)
    String todayDate = DateFormat('MM월 dd일', 'ko_KR').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100], // 배경색
      // ✨ [핵심 1] AppBar 제거함 (Scaffold에 appBar 속성이 아예 없음)

      // ✨ [핵심 2] SafeArea 적용: 앱바가 없으므로 상태바(배터리,시간)와 겹치지 않게 보호
      body: SafeArea(
        // ✨ [핵심 3] RefreshIndicator: 당겨서 새로고침 기능
        child: RefreshIndicator(
          onRefresh: _fetchTodayData, // 당기면 이 함수 실행
          color: const Color(0xFF33FF00), // 로딩 아이콘 색상 (메인 컬러)
          backgroundColor: Colors.white,

          child: SingleChildScrollView(
            // 내용이 적어도 당길 수 있게 설정 (중요!)
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),

                // ✨ [핵심 4] 앱바 대신 들어간 "오늘의 식단" 타이틀
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          todayDate, // 오늘 날짜 표시
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "오늘의 식단",
                          style: TextStyle(
                            fontSize: 28, // 앱바보다 훨씬 크고 시원하게
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    // (선택사항) 우측에 귀여운 아이콘 하나 둬도 좋음 (프로필 등)
                    // 현재는 비워둠
                  ],
                ),

                const SizedBox(height: 30),

                // 🏝️ 1번 섬: 칼로리 섹션
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "칼로리 현황",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 그라데이션 차트
                      CalorieChart(current: _currentCal, target: _targetCal),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 🏝️ 2번 섬: 영양소 섹션
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "영양소 상세",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 원형 그래프 3개
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMacroCircle(
                            "탄수화물",
                            _currentCarbs,
                            _targetCarbs,
                            Colors.green,
                          ),
                          _buildMacroCircle(
                            "단백질",
                            _currentProtein,
                            _targetProtein,
                            Colors.blue,
                          ),
                          _buildMacroCircle(
                            "지방",
                            _currentFat,
                            _targetFat,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 하단 여백 추가 (스크롤 끝부분 여유)
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("식단 입력 버튼 클릭됨");
        },
        backgroundColor: const Color(0xFF33FF00),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMacroCircle(
    String label,
    double current,
    double target,
    Color color,
  ) {
    double rawPercentage = (target == 0) ? 0 : (current / target * 100);
    bool isOver = rawPercentage > 100;
    double overPercentage = isOver ? rawPercentage - 100 : 0;

    HSLColor hsl = HSLColor.fromColor(color);
    Color darkerColor = hsl
        .withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0))
        .toColor();

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: 270,
                  sectionsSpace: 0,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      value: isOver ? 100 : rawPercentage,
                      color: color,
                      radius: 8,
                      showTitle: false,
                    ),
                    if (!isOver)
                      PieChartSectionData(
                        value: 100 - rawPercentage,
                        color: Colors.grey[200],
                        radius: 8,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              if (isOver)
                PieChart(
                  PieChartData(
                    startDegreeOffset: 270,
                    sectionsSpace: 0,
                    centerSpaceRadius: 30,
                    sections: [
                      PieChartSectionData(
                        value: overPercentage,
                        color: darkerColor,
                        radius: 8,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        value: 100 - overPercentage,
                        color: Colors.transparent,
                        radius: 8,
                        showTitle: false,
                      ),
                    ],
                  ),
                ),
              Center(
                child: Text(
                  "${rawPercentage.toInt()}%",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isOver ? darkerColor : color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          "${current.toInt()} / ${target.toInt()}g",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
