import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late final ScrollController _scrollController;

  // 캘린더 설정
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 그래프 필터 상태
  Map<String, bool> _chartVisibility = {
    'cal': true,
    'carbs': true,
    'protein': true,
    'fat': true,
  };

  // 목표 섭취량
  double _goalCal = 2000.0;
  double _goalCarbs = 250.0;
  double _goalProtein = 100.0;
  double _goalFat = 60.0;

  bool _isLoading = true;
  final Map<String, Map<String, double>> _dailyStats = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _selectedDay = _focusedDay;
    _fetchMonthlyData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMonthlyData() async {
    if (!_isLoading) setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data()!.containsKey('goals')) {
        final goals = userDoc.data()!['goals'] as Map<String, dynamic>;
        _goalCal = (goals['target_calories'] as num?)?.toDouble() ?? _goalCal;
        _goalCarbs = (goals['target_carbs'] as num?)?.toDouble() ?? _goalCarbs;
        _goalProtein =
            (goals['target_protein'] as num?)?.toDouble() ?? _goalProtein;
        _goalFat = (goals['target_fat'] as num?)?.toDouble() ?? _goalFat;
      }

      final snapshot = await FirebaseFirestore.instance
          .collectionGroup('meals')
          .where(
            FieldPath.documentId,
            isGreaterThanOrEqualTo: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .path,
          )
          .get();

      Map<String, Map<String, double>> tempStats = {};

      for (var doc in snapshot.docs) {
        if (!doc.reference.path.contains(user.uid)) continue;

        final grandParent = doc.reference.parent.parent;
        if (grandParent == null) continue;
        String dateStr = grandParent.id;

        var data = doc.data();
        double totalCal = 0, totalCarbs = 0, totalProtein = 0, totalFat = 0;

        if (data['foods'] != null && data['foods'] is List) {
          for (var food in (data['foods'] as List)) {
            double safeParse(dynamic v) => (v is num)
                ? v.toDouble()
                : (double.tryParse(v.toString()) ?? 0.0);
            totalCal += safeParse(food['calories']);
            totalCarbs += safeParse(food['carbs']);
            totalProtein += safeParse(food['protein']);
            totalFat += safeParse(food['fat']);
          }
        }

        tempStats.update(
          dateStr,
          (value) {
            value['cal'] = (value['cal'] ?? 0) + totalCal;
            value['carbs'] = (value['carbs'] ?? 0) + totalCarbs;
            value['protein'] = (value['protein'] ?? 0) + totalProtein;
            value['fat'] = (value['fat'] ?? 0) + totalFat;
            return value;
          },
          ifAbsent: () => {
            'cal': totalCal,
            'carbs': totalCarbs,
            'protein': totalProtein,
            'fat': totalFat,
          },
        );
      }

      if (mounted) {
        setState(() {
          _dailyStats.clear();
          _dailyStats.addAll(tempStats);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ 통계 데이터 불러오기 에러: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static String _formatDate(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _fetchMonthlyData,
                color: const Color(0xFF33FF00),
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      const Text(
                        "식단 통계",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _buildChartSection(),
                      const SizedBox(height: 16),
                      _buildCalendarAndStatsCard(),
                      const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(20),
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

  Widget _buildChartSection() {
    return _buildSectionCard(
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

  Widget _buildCalendarAndStatsCard() {
    final dateKey = _formatDate(_selectedDay ?? DateTime.now());
    final data = _dailyStats[dateKey];

    return _buildSectionCard(
      child: Column(
        children: [
          Listener(
            onPointerMove: (PointerMoveEvent event) {
              _scrollController.jumpTo(
                _scrollController.offset - event.delta.dy,
              );
            },
            child: TableCalendar(
              locale: 'ko_KR',
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) => setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              }),
              calendarStyle: const CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Color(0xFF33FFFF),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Color(0xFF33FF00),
                  shape: BoxShape.circle,
                ),
                markerDecoration: BoxDecoration(
                  color: Color(0xFF28E090),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
              eventLoader: (day) =>
                  _dailyStats.containsKey(_formatDate(day)) ? ['data'] : [],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(thickness: 1, height: 30),
          const SizedBox(height: 10),
          Column(
            children: [
              Text(
                DateFormat(
                  'M월 d일 (E)',
                  'ko_KR',
                ).format(_selectedDay ?? DateTime.now()),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              if (data != null) ...[
                _buildStatRow(
                  '총 섭취 칼로리',
                  '${data['cal']!.toInt()} kcal',
                  Colors.black,
                  true,
                ),
                const SizedBox(height: 20),
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
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '기록된 식단이 없습니다.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String key, Color color) {
    bool isActive = _chartVisibility[key]!;
    return GestureDetector(
      onTap: () => setState(() => _chartVisibility[key] = !isActive),
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

  // 🔥 [핵심 함수] 데이터 중 최대값을 찾아 그래프의 Y축 높이를 동적으로 계산
  double _calculateDynamicMaxY() {
    double maxPercentage = 0;

    // 최근 7일 데이터 순회
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      final dateKey = _formatDate(date);

      if (_dailyStats.containsKey(dateKey)) {
        final data = _dailyStats[dateKey]!;

        // 활성화된 필터(칼로리, 탄, 단, 지)만 체크
        if (_chartVisibility['cal']! && _goalCal > 0) {
          double pct = (data['cal'] ?? 0) / _goalCal * 100;
          if (pct > maxPercentage) maxPercentage = pct;
        }
        if (_chartVisibility['carbs']! && _goalCarbs > 0) {
          double pct = (data['carbs'] ?? 0) / _goalCarbs * 100;
          if (pct > maxPercentage) maxPercentage = pct;
        }
        if (_chartVisibility['protein']! && _goalProtein > 0) {
          double pct = (data['protein'] ?? 0) / _goalProtein * 100;
          if (pct > maxPercentage) maxPercentage = pct;
        }
        if (_chartVisibility['fat']! && _goalFat > 0) {
          double pct = (data['fat'] ?? 0) / _goalFat * 100;
          if (pct > maxPercentage) maxPercentage = pct;
        }
      }
    }

    // 기본값 110%보다 작으면 110% 유지, 크면 최대값 + 20% 여유
    return maxPercentage < 110 ? 110 : maxPercentage * 1.2;
  }

  LineChartData _buildLineChartData() {
    // 🔥 계산된 최대 높이 가져오기
    final double dynamicMaxY = _calculateDynamicMaxY();

    return LineChartData(
      // 🟢 자르지 않음 (그래프 점이 온전히 보이게)
      clipData: const FlClipData.none(),

      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => Colors.black.withOpacity(0.8),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) => spots.map((spot) {
            final date = DateTime.now().subtract(
              Duration(days: 6 - spot.x.toInt()),
            );
            final dateKey = _formatDate(date);
            final dailyData = _dailyStats[dateKey];
            final color = spot.bar.color ?? Colors.black;

            String label = '', unit = '';
            double realValue = 0;

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
              '${DateFormat('M/d').format(date)}\n$label: ${spot.y.toInt()}% (${realValue.toInt()}$unit)',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 50,
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
      maxY: dynamicMaxY, // 🔥 동적으로 계산된 높이 적용!
    );
  }

  LineChartBarData _buildLine(Color color, String key, double goal) {
    return LineChartBarData(
      spots: _getPercentageSpots(key, goal),
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true),
    );
  }

  List<FlSpot> _getPercentageSpots(String key, double goal) {
    List<FlSpot> spots = [];
    for (int i = 0; i < 7; i++) {
      final date = DateTime.now().subtract(Duration(days: 6 - i));
      final dateKey = _formatDate(date);

      if (!_dailyStats.containsKey(dateKey)) {
        continue;
      }

      final value = _dailyStats[dateKey]![key] ?? 0;
      final double percentage = (goal == 0) ? 0 : (value / goal * 100);
      spots.add(FlSpot(i.toDouble(), percentage));
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
