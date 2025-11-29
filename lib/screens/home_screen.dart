import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🟢 위젯 및 유틸 임포트 확인
import '../widgets/calorie_chart.dart';
import '../widgets/macro_chart.dart';
import '../widgets/expandable_ai_card.dart';
import '../utils/diet_notifier.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  // 수치 변수들
  double _currentCal = 0;
  double _targetCal = 2000;
  double _currentCarbs = 0;
  double _targetCarbs = 250;
  double _currentProtein = 0;
  double _targetProtein = 120;
  double _currentFat = 0;
  double _targetFat = 60;

  bool _isLoading = true;

  // AI에게 넘길 데이터
  List<Map<String, dynamic>> _todayMealDetails = [];
  Map<String, dynamic> _userDataMap = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetchTodayData();
    DietNotifier.shouldRefresh.addListener(_fetchTodayData);
  }

  @override
  void dispose() {
    DietNotifier.shouldRefresh.removeListener(_fetchTodayData);
    super.dispose();
  }

  Future<void> _fetchTodayData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. 유저 정보 (목표, 프로필 등) 가져오기
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Map<String, dynamic> userDataMap = userDoc.data() ?? {};

      // 목표 설정
      if (userDataMap.containsKey('goals')) {
        final goals = userDataMap['goals'] as Map<String, dynamic>;
        _targetCal = (goals['target_calories'] as num?)?.toDouble() ?? 2000;
        _targetCarbs = (goals['target_carbs'] as num?)?.toDouble() ?? 250;
        _targetProtein = (goals['target_protein'] as num?)?.toDouble() ?? 120;
        _targetFat = (goals['target_fat'] as num?)?.toDouble() ?? 60;

        userDataMap.addAll(goals); // goals 정보를 root에 합쳐서 AI에게 전달 편하게 함
      }

      // 2. 오늘 날짜 (새벽 4시 기준)
      DateTime now = DateTime.now();
      if (now.hour < 4) now = now.subtract(const Duration(days: 1));
      String today = DateFormat('yyyy-MM-dd').format(now);

      // 3. 식단 기록 가져오기
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
      List<Map<String, dynamic>> mealDetails = [];

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

            double cal = safeParse(food['calories']);
            tempCal += cal;
            tempCarbs += safeParse(food['carbs']);
            tempProtein += safeParse(food['protein']);
            tempFat += safeParse(food['fat']);

            if (food['name'] != null) {
              mealDetails.add({'name': food['name'], 'calories': cal});
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _currentCal = tempCal;
          _currentCarbs = tempCarbs;
          _currentProtein = tempProtein;
          _currentFat = tempFat;
          _todayMealDetails = mealDetails;
          _userDataMap = userDataMap;
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
    super.build(context);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
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
                const SizedBox(height: 5),
                // 상단 타이틀
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Text(
                      "오늘의 식단",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.black),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      todayDate,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 🟢 AI 어드바이저 카드 (펼쳐지는 위젯)
                ExpandableAiCard(
                  userData: _userDataMap,
                  mealDetails: _todayMealDetails,
                  totalCalories: _currentCal,
                  totalCarbs: _currentCarbs,
                  totalProtein: _currentProtein,
                  totalFat: _currentFat,
                ),

                const SizedBox(height: 20),

                // 칼로리 차트
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("칼로리 현황", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      CalorieChart(current: _currentCal, target: _targetCal),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 영양소 차트
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("영양소 상세", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
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