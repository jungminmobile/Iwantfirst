import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert'; // jsonEncode 사용을 위해 추가

import '../widgets/calorie_chart.dart';
import '../widgets/macro_chart.dart';
import '../services/gemini_service.dart';
import '../utils/diet_notifier.dart';

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
  String _aiFeedback = "오늘의 식단을 분석하고 있어요... 🤖"; // 초기 멘트

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

  // 🔥 데이터 가져오기 및 AI 조언 요청
  Future<void> _fetchTodayData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Firestore에서 사용자 정보(목표, 프로필 등) 가져오기
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      Map<String, dynamic> userDataMap = userDoc.data() ?? {};

      // 목표치 설정 (값이 없으면 기본값 사용)
      // * 참고: DB 구조가 goals/{target...} 인지 root에 바로 있는지에 따라 경로가 다를 수 있습니다.
      // * 여기서는 userDataMap에서 직접 찾거나 goals 맵 안에서 찾도록 유연하게 처리합니다.
      if (userDataMap.containsKey('goals')) {
        final goals = userDataMap['goals'] as Map<String, dynamic>;
        _targetCal = (goals['target_calories'] as num?)?.toDouble() ?? 2000;
        _targetCarbs = (goals['target_carbs'] as num?)?.toDouble() ?? 250;
        _targetProtein = (goals['target_protein'] as num?)?.toDouble() ?? 120;
        _targetFat = (goals['target_fat'] as num?)?.toDouble() ?? 60;

        // AI에게 넘길 userDataMap에 goals 내용 병합 (편의상)
        userDataMap.addAll(goals);
      }

      // 2. 오늘 식단 기록 가져오기
      DateTime now = DateTime.now();
      if (now.hour < 4) now = now.subtract(const Duration(days: 1)); // 새벽 4시 로직
      String today = DateFormat('yyyy-MM-dd').format(now);

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

      // AI에게 보낼 오늘 섭취 데이터 요약
      List<Map<String, dynamic>> mealDetails = [];

      for (var doc in mealsSnapshot.docs) {
        var data = doc.data();
        if (data['foods'] != null && data['foods'] is List) {
          List<dynamic> foods = data['foods'];
          for (var food in foods) {
            double cal = (food['calories'] as num?)?.toDouble() ?? 0.0;
            double car = (food['carbs'] as num?)?.toDouble() ?? 0.0;
            double pro = (food['protein'] as num?)?.toDouble() ?? 0.0;
            double fat = (food['fat'] as num?)?.toDouble() ?? 0.0;

            tempCal += cal;
            tempCarbs += car;
            tempProtein += pro;
            tempFat += fat;

            // 상세 정보 수집 (음식 이름 등)
            mealDetails.add({
              'name': food['name'],
              'calories': cal,
            });
          }
        }
      }

      // 3. UI 업데이트 (그래프용 수치)
      if (mounted) {
        setState(() {
          _currentCal = tempCal;
          _currentCarbs = tempCarbs;
          _currentProtein = tempProtein;
          _currentFat = tempFat;
          _isLoading = false;
        });
      }

      // 4. Gemini AI에게 조언 요청 (비동기)
      // 데이터가 조금이라도 있을 때만 요청
      if (tempCal > 0) {
        // AI에게 넘겨줄 JSON 문자열 생성
        String nutritionAnalysisJson = jsonEncode({
          "total_calories": tempCal,
          "total_carbs": tempCarbs,
          "total_protein": tempProtein,
          "total_fat": tempFat,
          "meal_details": mealDetails // 어떤 음식을 먹었는지도 알면 더 좋은 조언 가능
        });

        // 🟢 [핵심] GeminiService의 generateAdvice 호출
        GeminiService().generateAdvice(nutritionAnalysisJson, userDataMap).then((advice) {
          if (mounted && advice != null) {
            setState(() {
              _aiFeedback = advice;
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _aiFeedback = "아직 기록된 식사가 없어요. 첫 끼니를 기록해보세요! 🍽️";
          });
        }
      }

    } catch (e) {
      print("❌ 홈 데이터 불러오기 실패: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                // 👋 상단 타이틀
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
                    const SizedBox(width: 8),
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

                const SizedBox(height: 20),

                // 🤖 AI 조언 카드 (페르소나 적용됨!)
                _buildAiFeedbackCard(),

                const SizedBox(height: 20),

                // 🍩 1번 섬: 칼로리 섹션
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

                // 📊 2번 섬: 영양소 상세
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

  // 📦 기본 섹션 카드
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

  // ✨ AI 조언 카드 디자인
  Widget _buildAiFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // 배경: 은은한 보라빛 그라데이션
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurple.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아이콘
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.deepPurpleAccent, size: 24),
          ),
          const SizedBox(width: 16),
          // 텍스트 내용
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI 어드바이저",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _aiFeedback,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}