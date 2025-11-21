import 'package:flutter/material.dart';
import '../models/nutrient_data.dart';
import '../widgets/calorie_chart.dart';
import '../widgets/macro_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 나중에는 이 데이터를 Firebase에서 불러올 것입니다.
  final NutrientData dummyData = NutrientData(
    currentCalories: 1500,
    targetCalories: 2000,
    currentCarbs: 180,
    targetCarbs: 250,
    currentProtein: 80,
    targetProtein: 120,
    currentFat: 40,
    targetFat: 60,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 식단', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: (){}, icon: const Icon(Icons.calendar_today, color: Colors.black)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 섹션 제목
            const Text("칼로리 현황", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 2. 원형 그래프 위젯
            CalorieChart(
              current: dummyData.currentCalories,
              target: dummyData.targetCalories,
            ),

            const SizedBox(height: 40),

            // 3. 섹션 제목
            const Text("영양소 상세 (목표 대비)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 4. 막대 그래프 위젯
            MacroChart(
              carbs: dummyData.currentCarbs,
              targetCarbs: dummyData.targetCarbs,
              protein: dummyData.currentProtein,
              targetProtein: dummyData.targetProtein,
              fat: dummyData.currentFat,
              targetFat: dummyData.targetFat,
            ),
          ],
        ),
      ),
      // 다음 단계 예고: 여기에 식단 입력 버튼(FAB)을 추가할 예정입니다.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 식단 입력 화면으로 이동
          print("식단 입력 버튼 클릭됨");
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ),
    );
  }
}