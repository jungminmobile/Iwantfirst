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

  // 🔥 오늘 데이터 가져오기
  Future<void> _fetchTodayData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. 목표 가져오기
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('goals')) {
        var goals = userDoc.data()!['goals'];
        if (mounted) {
          setState(() {
            if (goals['target_calories'] != null) _targetCal = (goals['target_calories'] as num).toDouble();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 식단', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: _fetchTodayData,
              icon: const Icon(Icons.refresh, color: Colors.black)
          ),
          IconButton(
              onPressed: (){},
              icon: const Icon(Icons.calendar_today, color: Colors.black)
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 칼로리 섹션
            const Text("칼로리 현황", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 기존 칼로리 차트
            CalorieChart(
              current: _currentCal,
              target: _targetCal,
            ),

            const SizedBox(height: 40),

            // 2. 탄단지 섹션
            const Text("영양소 상세", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 원형 그래프 3개
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroCircle("탄수화물", _currentCarbs, _targetCarbs, Colors.green),
                _buildMacroCircle("단백질", _currentProtein, _targetProtein, Colors.blue),
                _buildMacroCircle("지방", _currentFat, _targetFat, Colors.orange),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("식단 입력 버튼 클릭됨");
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }

  // 🔥 [수정 완료] 탄단지 원형 그래프 빌더 함수
  Widget _buildMacroCircle(String label, double current, double target, Color color) {
    // 실제 퍼센트 계산
    double rawPercentage = (target == 0) ? 0 : (current / target * 100);
    bool isOver = rawPercentage > 100;

    // 초과한 퍼센트
    double overPercentage = isOver ? rawPercentage - 100 : 0;

    // --- [수정된 부분] 색상 진하게 만들기 ---
    // withLightness 안에는 함수가 아니라 숫자가 들어가야 합니다.
    HSLColor hsl = HSLColor.fromColor(color);
    Color darkerColor = hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
    // ------------------------------------

    return Column(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              // 1층 차트: 기본 베이스
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

              // 2층 차트: 초과분 표시
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

              // 중앙 텍스트
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          "${current.toInt()} / ${target.toInt()}g",
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}