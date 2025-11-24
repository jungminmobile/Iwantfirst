import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  // 📅 캘린더 설정
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 📊 그래프 모드 (0: 칼로리, 1: 탄단지)
  int _chartIndex = 0;

  // ⏳ 로딩 상태
  bool _isLoading = true;

  // 💾 날짜별 합계 데이터 저장소
  // 구조: {'2024-05-24': {'cal': 2100, 'carbs': 300, ...}}
  final Map<String, Map<String, double>> _dailyStats = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchMonthlyData(); // 화면 켜지면 데이터 불러오기
  }

  // 🔥 파이어베이스에서 데이터 가져오기

  Future<void> _fetchMonthlyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    print("🔍 데이터 탐색 시작 (collectionGroup 방식)");

    try {
      // 1. 'meals'라는 이름을 가진 모든 컬렉션을 찾습니다. (경로 무시하고 전체 검색)
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('meals')
          .get();

      print("📦 전체 meals 문서 발견: ${snapshot.docs.length}개");

      Map<String, Map<String, double>> tempStats = {};

      for (var doc in snapshot.docs) {
        // 2. [중요] 내 데이터인지 확인 (문서 경로에 내 UID가 포함되어 있는지 체크)
        // 경로 예시: users/내UID/daily_logs/2025-11-24/meals/아침
        if (!doc.reference.path.contains(user.uid)) {
          continue; // 내 꺼 아니면 건너뜀
        }

        // 3. 경로에서 '날짜' 추출 (meals 컬렉션의 부모 문서 ID가 곧 날짜)
        // doc.reference.parent => 'meals' 컬렉션
        // doc.reference.parent.parent => '2025-11-24' 문서 (유령 문서라도 ID는 가져올 수 있음)
        final grandParent = doc.reference.parent.parent;
        if (grandParent == null) continue;

        String dateStr = grandParent.id; // "2025-11-24"

        // 4. 데이터 합산 로직 (기존과 동일)
        var data = doc.data();
        double totalCal = 0;
        double totalCarbs = 0;
        double totalProtein = 0;
        double totalFat = 0;

        if (data['foods'] != null && data['foods'] is List) {
          List<dynamic> foods = data['foods'];
          for (var food in foods) {
            double safeParse(dynamic value) {
              if (value == null) return 0.0;
              if (value is num) return value.toDouble();
              if (value is String) return double.tryParse(value) ?? 0.0;
              return 0.0;
            }
            totalCal += safeParse(food['calories']);
            totalCarbs += safeParse(food['carbs']);
            totalProtein += safeParse(food['protein']);
            totalFat += safeParse(food['fat']);
          }
        }

        // 5. 날짜별로 누적
        if (tempStats.containsKey(dateStr)) {
          tempStats[dateStr]!['cal'] = tempStats[dateStr]!['cal']! + totalCal;
          tempStats[dateStr]!['carbs'] = tempStats[dateStr]!['carbs']! + totalCarbs;
          tempStats[dateStr]!['protein'] = tempStats[dateStr]!['protein']! + totalProtein;
          tempStats[dateStr]!['fat'] = tempStats[dateStr]!['fat']! + totalFat;
        } else {
          tempStats[dateStr] = {
            'cal': totalCal,
            'carbs': totalCarbs,
            'protein': totalProtein,
            'fat': totalFat,
          };
        }
      }

      print("✅ 최종 집계 완료: ${tempStats.keys}");

      if (mounted) {
        setState(() {
          _dailyStats.clear();
          _dailyStats.addAll(tempStats);
          _isLoading = false;
        });
      }

    } catch (e) {
      print('❌ 에러 발생: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 날짜 포맷 헬퍼
  static String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('식단 통계'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMonthlyData, // 새로고침
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. 상단 그래프 영역
            _buildChartSection(),

            const SizedBox(height: 20),
            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
            const SizedBox(height: 10),

            // 2. 캘린더 영역
            _buildCalendarSection(),

            const SizedBox(height: 20),

            // 3. 선택한 날짜 상세 정보
            _buildSelectedDayStats(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 위젯 구현 ---

  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('최근 7일 추세', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _buildChartTab('칼로리', 0),
                  const SizedBox(width: 8),
                  _buildChartTab('탄단지', 1),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: LineChart(
              _chartIndex == 0 ? _mainDataCalories() : _mainDataMacros(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab(String text, int index) {
    bool isSelected = _chartIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _chartIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TableCalendar(
        locale: 'ko_KR', // main.dart에서 초기화 필요 (없으면 en_US로 나옴)
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        calendarStyle: const CalendarStyle(
          todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
          selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
          markerDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        // 데이터가 있는 날짜에 작은 점 찍기
        eventLoader: (day) {
          String key = _formatDate(day);
          return _dailyStats.containsKey(key) ? ['data'] : [];
        },
      ),
    );
  }

  Widget _buildSelectedDayStats() {
    String dateKey = _formatDate(_selectedDay ?? DateTime.now());
    var data = _dailyStats[dateKey]; // 해당 날짜의 데이터 가져오기

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              DateFormat('M월 d일 (E)', 'ko_KR').format(_selectedDay ?? DateTime.now()),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            if (data != null) ...[
              _buildStatRow('총 섭취 칼로리', '${data['cal']!.toInt()} kcal', Colors.black, true),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroItem('탄수화물', '${data['carbs']!.toInt()}g', Colors.green),
                  _buildMacroItem('단백질', '${data['protein']!.toInt()}g', Colors.blue),
                  _buildMacroItem('지방', '${data['fat']!.toInt()}g', Colors.orange),
                ],
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('기록된 식단이 없습니다.', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            color: color,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  // --- 그래프 데이터 설정 ---

  LineChartData _mainDataCalories() {
    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: _buildTitles(),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: _getSpots('cal'),
          isCurved: false,
          color: Colors.redAccent,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: Colors.redAccent.withOpacity(0.1)),
        ),
      ],
    );
  }

  LineChartData _mainDataMacros() {
    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false),
      titlesData: _buildTitles(),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(spots: _getSpots('carbs'), isCurved: false, color: Colors.green, barWidth: 3),
        LineChartBarData(spots: _getSpots('protein'), isCurved: false, color: Colors.blue, barWidth: 3),
        LineChartBarData(spots: _getSpots('fat'), isCurved: false, color: Colors.orange, barWidth: 3),
      ],
    );
  }

  FlTitlesData _buildTitles() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: (value, meta) {
            // 최근 7일 날짜 라벨
            final date = DateTime.now().subtract(Duration(days: 6 - value.toInt()));
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                DateFormat('M/d').format(date),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // 그래프용 좌표 데이터 변환 (최근 7일)
  List<FlSpot> _getSpots(String key) {
    List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      DateTime date = DateTime.now().subtract(Duration(days: i));
      String dateKey = _formatDate(date);
      double value = _dailyStats[dateKey]?[key] ?? 0;
      spots.add(FlSpot((6 - i).toDouble(), value));
    }
    return spots;
  }
}
