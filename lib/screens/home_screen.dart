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
    // isLoading을 다시 true로 설정하여 새로고침 효과를 줍니다.
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('goals')) {
        // 'goals' 맵을 안전하게 가져옵니다.
        final goals = userDoc.data()!['goals'] as Map<String, dynamic>;

        // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
        // ★★★ 여기가 핵심 수정 사항입니다: Firestore에서 직접 목표치 가져오기 ★★★
        // ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

        // num 타입으로 안전하게 가져온 후 double로 변환하고, null일 경우 기본값을 사용합니다.
        _targetCal = (goals['target_calories'] as num?)?.toDouble() ?? _targetCal;
        _targetCarbs = (goals['target_carbs'] as num?)?.toDouble() ?? _targetCarbs;
        _targetProtein = (goals['target_protein'] as num?)?.toDouble() ?? _targetProtein;
        _targetFat = (goals['target_fat'] as num?)?.toDouble() ?? _targetFat;
      }

      // 2. 오늘 섭취 기록 가져오기 (기존 코드와 동일)
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
            // 다양한 숫자 타입을 안전하게 double로 변환하는 헬퍼 함수
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

      // 3. 모든 데이터가 준비되면 한 번에 setState 호출
      if (mounted) {
        setState(() {
          _currentCal = tempCal;
          _currentCarbs = tempCarbs;
          _currentProtein = tempProtein;
          _currentFat = tempFat;
          _isLoading = false; // 데이터 로딩 완료
        });
      }

    } catch (e) {
      print("❌ 홈 데이터 불러오기 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI를 구성하는 build 함수 및 _buildMacroCircle 함수는 변경할 필요가 없습니다. ---
  // --- 따라서 기존 코드를 그대로 사용하시면 됩니다. ---
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
          : RefreshIndicator( // 화면을 아래로 당겨서 새로고침하는 기능 추가
        onRefresh: _fetchTodayData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // 스크롤이 짧아도 항상 당길 수 있도록 설정
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

  Widget _buildMacroCircle(String label, double current, double target, Color color) {
    double rawPercentage = (target == 0) ? 0 : (current / target * 100);
    bool isOver = rawPercentage > 100;
    double overPercentage = isOver ? rawPercentage - 100 : 0;
    HSLColor hsl = HSLColor.fromColor(color);
    Color darkerColor = hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();

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
