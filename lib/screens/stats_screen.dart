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

  // 📊 그래프 필터 상태 (처음엔 모두 true)
  Map<String, bool> _chartVisibility = {
    'cal': true,
    'carbs': true,
    'protein': true,
    'fat': true,
  };

  // 🎯 [중요] 목표 섭취량 (나중에 DB에서 불러오거나 설정값으로 대체하세요)
  final double _goalCal = 2500.0;
  final double _goalCarbs = 300.0;
  final double _goalProtein = 100.0;
  final double _goalFat = 60.0;

  // ⏳ 로딩 상태
  bool _isLoading = true;

  // 💾 날짜별 합계 데이터 저장소
  final Map<String, Map<String, double>> _dailyStats = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchMonthlyData();
  }

  // 🔥 파이어베이스 데이터 가져오기 (기존 로직 유지)
  Future<void> _fetchMonthlyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance.collectionGroup('meals').get();

      Map<String, Map<String, double>> tempStats = {};

      for (var doc in snapshot.docs) {
        if (!doc.reference.path.contains(user.uid)) continue;

        final grandParent = doc.reference.parent.parent;
        if (grandParent == null) continue;
        String dateStr = grandParent.id;

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
            onPressed: _fetchMonthlyData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildChartSection(),
            const SizedBox(height: 20),
            const Divider(thickness: 8, color: Color(0xFFF5F5F5)),
            const SizedBox(height: 10),
            _buildCalendarSection(),
            const SizedBox(height: 20),
            _buildSelectedDayStats(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- 📊 그래프 섹션 수정됨 ---
  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('최근 7일 달성률 (%)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),

          // 1. 4개의 필터 버튼 (Row + Wrap)
          Wrap(
            spacing: 8.0,
            children: [
              _buildFilterButton('칼로리', 'cal', Colors.redAccent),
              _buildFilterButton('탄수화물', 'carbs', Colors.green),
              _buildFilterButton('단백질', 'protein', Colors.blue),
              _buildFilterButton('지방', 'fat', Colors.orange),
            ],
          ),

          const SizedBox(height: 20),

          // 2. 꺾은선 그래프
          SizedBox(
            height: 250,
            child: LineChart(
              _buildLineChartData(), // 통합된 차트 데이터 생성 함수
            ),
          ),
        ],
      ),
    );
  }

  // 필터 버튼 위젯 (토글 방식)
  Widget _buildFilterButton(String label, String key, Color color) {
    bool isActive = _chartVisibility[key]!;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chartVisibility[key] = !isActive; // 토글
        });
      },
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: isActive ? color : Colors.grey[200],
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),
    );
  }

  // --- 📈 통합 그래프 데이터 생성 (백분율 + 툴팁) ---
  LineChartData _buildLineChartData() {
    return LineChartData(
      // 1. 그리드 설정
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 50, // 50% 단위로 줄 긋기
      ),

      // 2. 툴팁 설정 (터치 시 퍼센트 + 실제값 표시)
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          // tooltipBgColor: Colors.blueGrey.withOpacity(0.8), // 구버전
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              // 인덱스로 날짜 찾기 (역순 계산 필요 없음, spots 생성시 처리)
              int dayIndex = 6 - barSpot.x.toInt();
              DateTime date = DateTime.now().subtract(Duration(days: dayIndex));
              String dateKey = _formatDate(date);

              // 어떤 데이터인지 색깔로 판별하거나 barIndex로 판별
              // barSpot.barIndex를 사용해 어떤 영양소인지 찾을 수도 있지만,
              // 여기서는 간단히 현재 spot의 값을 역산하거나 다시 가져옴.

              String label = '';
              double realValue = 0;
              String unit = '';

              // *주의: 보여지는 순서에 따라 매칭해야 함. (복잡하므로 색상으로 매칭 권장)
              // 여기서는 편의상 값을 다시 조회
              var dailyData = _dailyStats[dateKey];
              Color color = barSpot.bar.color ?? Colors.black;

              if (color == Colors.redAccent) {
                label = '칼로리';
                realValue = dailyData?['cal'] ?? 0;
                unit = 'kcal';
              } else if (color == Colors.green) {
                label = '탄수화물';
                realValue = dailyData?['carbs'] ?? 0;
                unit = 'g';
              } else if (color == Colors.blue) {
                label = '단백질';
                realValue = dailyData?['protein'] ?? 0;
                unit = 'g';
              } else if (color == Colors.orange) {
                label = '지방';
                realValue = dailyData?['fat'] ?? 0;
                unit = 'g';
              }

              return LineTooltipItem(
                '$label\n${barSpot.y.toInt()}% (${realValue.toInt()}$unit)',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
      ),

      titlesData: _buildTitles(), // 축 타이틀
      borderData: FlBorderData(show: false),

      // 3. 목표 라인 (100% 점선)
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 100,
            color: Colors.black54,
            strokeWidth: 1,
            dashArray: [5, 5], // 점선 패턴
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
              labelResolver: (line) => 'Goal 100%',
            ),
          ),
        ],
      ),

      // 4. 실제 라인 데이터들
      lineBarsData: [
        if (_chartVisibility['cal']!) _buildLine(Colors.redAccent, 'cal', _goalCal),
        if (_chartVisibility['carbs']!) _buildLine(Colors.green, 'carbs', _goalCarbs),
        if (_chartVisibility['protein']!) _buildLine(Colors.blue, 'protein', _goalProtein),
        if (_chartVisibility['fat']!) _buildLine(Colors.orange, 'fat', _goalFat),
      ],

      // y축 범위 설정 (최소 0, 최대는 데이터에 따라 유동적이지만 최소 120%까지 확보)
      minY: 0,
      maxY: _calcMaxY(),
    );
  }

  double _calcMaxY() {
    // 데이터 중 가장 높은 퍼센트를 찾아서 y축 높이 조절
    double maxP = 120; // 기본 120%
    // (복잡하면 그냥 null로 두면 자동조절됨, 여기선 150으로 고정 추천)
    return 160;
  }

  // 라인 하나 생성하는 함수
  LineChartBarData _buildLine(Color color, String key, double goal) {
    return LineChartBarData(
      spots: _getPercentageSpots(key, goal),
      isCurved: false, // 직선
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) {
        return FlDotCirclePainter(
          radius: 3,
          color: Colors.white,
          strokeWidth: 2,
          strokeColor: color,
        );
      }),
    );
  }

  // 절대값 -> 퍼센트 변환 로직
  List<FlSpot> _getPercentageSpots(String key, double goal) {
    List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      DateTime date = DateTime.now().subtract(Duration(days: i));
      String dateKey = _formatDate(date);
      double value = _dailyStats[dateKey]?[key] ?? 0;

      // 퍼센트 계산 (value / goal * 100)
      double percentage = (goal == 0) ? 0 : (value / goal * 100);

      spots.add(FlSpot((6 - i).toDouble(), percentage));
    }
    return spots;
  }

  FlTitlesData _buildTitles() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: 1,
          getTitlesWidget: (value, meta) {
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
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 50, // 50, 100, 150 ...
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            return Text('${value.toInt()}%', style: const TextStyle(color: Colors.grey, fontSize: 10));
          },
        ),
      ),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // --- 나머지 위젯들 (캘린더 등) ---

  Widget _buildCalendarSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TableCalendar(
        locale: 'ko_KR',
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
        eventLoader: (day) {
          String key = _formatDate(day);
          return _dailyStats.containsKey(key) ? ['data'] : [];
        },
      ),
    );
  }

  Widget _buildSelectedDayStats() {
    String dateKey = _formatDate(_selectedDay ?? DateTime.now());
    var data = _dailyStats[dateKey];

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
}