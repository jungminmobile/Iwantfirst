import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 위젯 import
import '../widgets/calorie_chart.dart';
import '../widgets/macro_chart.dart'; // 👈 새로 만든 막대그래프 파일 import

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

  // 오늘 데이터 가져오기
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
    // 상태바 투명하게 설정
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    String todayDate = DateFormat('MM월 dd일').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchTodayData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5), // 상단 여백
                      // 타이틀 영역
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          const Text(
                            "오늘의 식단",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8,),
                          Text(
                            todayDate,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 1번 섬: 칼로리 섹션
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

                      const SizedBox(height: 16),

                      // 2번 섬: 영양소 상세
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

                            // [변경] 기존 Row 삭제하고 MacroChart 사용
                            MacroChart(
                              carbs: _currentCarbs,
                              targetCarbs: _targetCarbs,
                              protein: _currentProtein,
                              targetProtein: _targetProtein,
                              fat: _currentFat,
                              targetFat: _targetFat,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // 카드 UI 위젯
  Widget _buildSectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
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
