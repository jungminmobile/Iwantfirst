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

  // 🎯 목표 섭취량 (기본값 설정해두고, 서버에서 가져와서 덮어씀)
  double _goalCal = 2000.0;
  double _goalCarbs = 250.0;
  double _goalProtein = 100.0;
  double _goalFat = 60.0;

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

  // 🔥 파이어베이스 데이터 가져오기 (목표 + 식단)
  Future<void> _fetchMonthlyData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. [추가됨] 사용자의 '목표(Goals)' 먼저 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('goals')) {
        var goals = userDoc.data()!['goals'];
        if (mounted) {
          setState(() {
            // DB에 있는 값으로 목표 변수 업데이트 (없으면 기본값 유지)
            if (goals['target_calories'] != null)
              _goalCal = (goals['target_calories'] as num).toDouble();

            // 탄단지 목표가 DB에 따로 없으면 칼로리 기반으로 자동 계산 (비율 예시: 5:3:2)
            // 만약 DB에 저장하고 있다면 아래처럼 가져오면 됩니다.
            // if (goals['target_carbs'] != null) _goalCarbs = (goals['target_carbs'] as num).toDouble();

            // (임시) 칼로리 기반 자동 계산 (필요 없으면 지우세요)
            _goalCarbs = (_goalCal * 0.5) / 4; // 50%
            _goalProtein = (_goalCal * 0.3) / 4; // 30%
            _goalFat = (_goalCal * 0.2) / 9; // 20%
          });
        }
      }

      // 2. 식단 데이터 가져오기 (collectionGroup)
      // *주의: 파이어베이스 콘솔에서 '보안 규칙'이 설정되어 있어야 에러가 안 납니다.
      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('meals')
          .get();

      Map<String, Map<String, double>> tempStats = {};

      for (var doc in snapshot.docs) {
        // 내 데이터인지 확인
        if (!doc.reference.path.contains(user.uid)) continue;

        // 날짜 확인
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
          tempStats[dateStr]!['carbs'] =
              tempStats[dateStr]!['carbs']! + totalCarbs;
          tempStats[dateStr]!['protein'] =
              tempStats[dateStr]!['protein']! + totalProtein;
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
          ),
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

  // --- 📊 그래프 섹션 ---
  Widget _buildChartSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '최근 7일 달성률 (%)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '목표: ${_goalCal.toInt()} kcal',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 15),

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

          SizedBox(height: 250, child: LineChart(_buildLineChartData())),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String key, Color color) {
    bool isActive = _chartVisibility[key]!;
    return GestureDetector(
      onTap: () {
        setState(() {
          _chartVisibility[key] = !isActive;
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

  // --- 📈 통합 그래프 데이터 생성 ---
  LineChartData _buildLineChartData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 50,
      ),

      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              int dayIndex = 6 - barSpot.x.toInt();
              DateTime date = DateTime.now().subtract(Duration(days: dayIndex));
              String dateKey = _formatDate(date);

              String label = '';
              double realValue = 0;
              String unit = '';

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
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),

      titlesData: _buildTitles(),
      borderData: FlBorderData(show: false),

      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: 100,
            color: Colors.black54,
            strokeWidth: 1,
            dashArray: [5, 5],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 5, bottom: 5),
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              labelResolver: (line) => 'Goal 100%',
            ),
          ),
        ],
      ),

      lineBarsData: [
        if (_chartVisibility['cal']!)
          _buildLine(Colors.redAccent, 'cal', _goalCal),
        if (_chartVisibility['carbs']!)
          _buildLine(Colors.green, 'carbs', _goalCarbs),
        if (_chartVisibility['protein']!)
          _buildLine(Colors.blue, 'protein', _goalProtein),
        if (_chartVisibility['fat']!)
          _buildLine(Colors.orange, 'fat', _goalFat),
      ],

      minY: 0,
      maxY: 160,
    );
  }

  LineChartBarData _buildLine(Color color, String key, double goal) {
    return LineChartBarData(
      spots: _getPercentageSpots(key, goal),
      isCurved: false,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3,
            color: Colors.white,
            strokeWidth: 2,
            strokeColor: color,
          );
        },
      ),
    );
  }

  List<FlSpot> _getPercentageSpots(String key, double goal) {
    List<FlSpot> spots = [];
    for (int i = 6; i >= 0; i--) {
      DateTime date = DateTime.now().subtract(Duration(days: i));
      String dateKey = _formatDate(date);
      double value = _dailyStats[dateKey]?[key] ?? 0;

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
            final date = DateTime.now().subtract(
              Duration(days: 6 - value.toInt()),
            );
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
          interval: 50,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const SizedBox.shrink();
            return Text(
              '${value.toInt()}%',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            );
          },
        ),
      ),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  // --- 📅 캘린더 등 나머지 위젯 ---

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
          todayDecoration: BoxDecoration(
            color: const Color(0xFF33CC80),
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: const Color(0xFF33CCFF),
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.orange,
            shape: BoxShape.circle,
          ),
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
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(
              DateFormat(
                'M월 d일 (E)',
                'ko_KR',
              ).format(_selectedDay ?? DateTime.now()),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            if (data != null) ...[
              _buildStatRow(
                '총 섭취 칼로리',
                '${data['cal']!.toInt()} kcal',
                Colors.black,
                true,
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroItem(
                    '탄수화물',
                    '${data['carbs']!.toInt()}g',
                    Colors.green,
                  ),
                  _buildMacroItem(
                    '단백질',
                    '${data['protein']!.toInt()}g',
                    Colors.blue,
                  ),
                  _buildMacroItem(
                    '지방',
                    '${data['fat']!.toInt()}g',
                    Colors.orange,
                  ),
                ],
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '기록된 식단이 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
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
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
