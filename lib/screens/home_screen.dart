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
  // 화면에 표시될 변수들의 기본값 설정
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

  // 🔥 오늘 데이터 가져오기 (수정된 버전)
  Future<void> _fetchTodayData() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. 목표 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('goals')) {
        final goals = userDoc.data()!['goals'] as Map<String, dynamic>;

        _targetCal =
            (goals['target_calories'] as num?)?.toDouble() ?? _targetCal;
        _targetCarbs =
            (goals['target_carbs'] as num?)?.toDouble() ?? _targetCarbs;
        _targetProtein =
            (goals['target_protein'] as num?)?.toDouble() ?? _targetProtein;
        _targetFat = (goals['target_fat'] as num?)?.toDouble() ?? _targetFat;
      }

      // 2. 오늘 섭취 기록 가져오기
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
    // 📅 [추가됨] 오늘 날짜 가져오기 (예: 11월 28일)
    // 'ko_KR'이 설정 안 되어 있어도 숫자와 한글은 잘 나옵니다.
    String todayDate = DateFormat('MM월 dd일').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // ✅ SafeArea: 상태바(배터리, 시간) 영역 침범 방지
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchTodayData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(
                    20.0,
                  ), // 여백을 16 -> 20으로 살짝 키움 (더 시원하게)
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10), // 상단 여백
                      // 👋 [타이틀 영역 수정] 날짜 + 제목
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            todayDate, // 1. 날짜 (작고 회색)
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 5), // 날짜와 제목 사이 간격
                          const Text(
                            "오늘의 식단", // 2. 메인 제목 (크고 검은색)
                            style: TextStyle(
                              fontSize: 28, // 폰트 사이즈 키움 (24 -> 28)
                              fontWeight: FontWeight.w800, // 더 두껍게
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30), // 제목과 카드 사이 간격 넓힘
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
                            CalorieChart(
                              current: _currentCal,
                              target: _targetCal,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16), // 카드 사이 간격
                      // 🏝️ 2번 섬: 탄단지 섹션
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

                      // 스크롤 끝부분 여유 공간
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // 📦 [추가됨] 섹션을 카드 형태로 만들어주는 함수
  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // 둥근 모서리
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1), // 연한 그림자
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 3), // 그림자 위치
          ),
        ],
      ),
      child: child,
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
}
