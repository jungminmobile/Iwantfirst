import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import '../models/food_item.dart';
import 'dart:convert';

class EditFoodScreen extends StatefulWidget {
  final List<Map<String, String>> initialFoods;
  final String mealType;
  final DateTime selectedDate;

  const EditFoodScreen({
    super.key,
    required this.initialFoods,
    required this.mealType,
    required this.selectedDate,
  });

  @override
  State<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends State<EditFoodScreen> {
  late List<Map<String, String>> _foodList;
  List<FoodItem> _analyzedFoods = [];
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _foodList = List.from(widget.initialFoods);
  }

  void _addNewFood() {
    String name = '';
    String amount = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('음식 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '음식 이름 (예: 사과)'),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: '양 (예: 1개)'),
              onChanged: (v) => amount = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                setState(() {
                  _foodList.add({'name': name, 'amount': amount});
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _analyzeNutrition() async {
    setState(() => _isAnalyzing = true);
    try {
      final gemini = GeminiService();
      final resultJson = await gemini.analyzeNutritionFromList(_foodList);
      if (resultJson != null && mounted) {
        List<dynamic> parsed = jsonDecode(resultJson);
        setState(() {
          _analyzedFoods = parsed.map((x) => FoodItem.fromJson(x)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _saveToDatabase() async {
    try {
      setState(() => _isAnalyzing = true);
      await DatabaseService().saveMeal(
        mealType: widget.mealType,
        foods: _analyzedFoods,
        date: widget.selectedDate,
      );
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('식단이 저장되었습니다! 📝')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAnalyzed = _analyzedFoods.isNotEmpty;

    int totalCal = isAnalyzed
        ? _analyzedFoods.fold(0, (sum, item) => sum + item.calories)
        : 0;
    int totalCarbs = isAnalyzed
        ? _analyzedFoods.fold(0, (sum, item) => sum + item.carbs)
        : 0;
    int totalProtein = isAnalyzed
        ? _analyzedFoods.fold(0, (sum, item) => sum + item.protein)
        : 0;
    int totalFat = isAnalyzed
        ? _analyzedFoods.fold(0, (sum, item) => sum + item.fat)
        : 0;

    return Scaffold(
      backgroundColor: Colors.grey[100], // [수정] 배경색 연한 회색으로 변경
      appBar: AppBar(
        title: const Text(
          '음식 확인/수정',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  isAnalyzed
                      ? '영양소 분석 결과입니다.\n하단 저장 버튼을 눌러 기록하세요.'
                      : 'AI가 식별한 결과입니다.\n이름과 양이 맞는지 확인해주세요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),

              // 🟢 [수정] 총합계 카드 (분석 완료 시에만 표시)
              if (isAnalyzed)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '총 섭취 영양소',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalCal kcal',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMacroText('탄수화물', '${totalCarbs}g'),
                          Container(
                            width: 1,
                            height: 20,
                            color: Colors.grey[300],
                          ),
                          _buildMacroText('단백질', '${totalProtein}g'),
                          Container(
                            width: 1,
                            height: 20,
                            color: Colors.grey[300],
                          ),
                          _buildMacroText('지방', '${totalFat}g'),
                        ],
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: isAnalyzed
                      ? _analyzedFoods.length
                      : _foodList.length,
                  itemBuilder: (ctx, index) {
                    if (isAnalyzed) {
                      final food = _analyzedFoods[index];
                      // 🟢 [수정] 카드 형태로 감싸기
                      return _buildFoodCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            food.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                '양: ${food.amount}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${food.calories}kcal  |  탄 ${food.carbs}  단 ${food.protein}  지 ${food.fat}',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    } else {
                      // 🟢 [수정] 카드 형태로 감싸기
                      return _buildFoodCard(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: TextFormField(
                            initialValue: _foodList[index]['name'],
                            decoration: const InputDecoration(
                              labelText: '음식 이름',
                              border: InputBorder.none, // 밑줄 제거
                              labelStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            onChanged: (v) => _foodList[index]['name'] = v,
                          ),
                          subtitle: TextFormField(
                            initialValue: _foodList[index]['amount'],
                            decoration: const InputDecoration(
                              labelText: '양',
                              border: InputBorder.none, // 밑줄 제거
                            ),
                            onChanged: (v) => _foodList[index]['amount'] = v,
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                setState(() => _foodList.removeAt(index)),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),

              // 하단 버튼 영역
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: Offset(0, -5),
                    ),
                  ],
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isAnalyzed
                            ? () {
                                setState(() {
                                  _analyzedFoods = [];
                                });
                              }
                            : _addNewFood,
                        icon: Icon(isAnalyzed ? Icons.refresh : Icons.add),
                        label: Text(isAnalyzed ? '다시 수정하기' : '음식 추가'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isAnalyzed
                            ? _saveToDatabase
                            : _analyzeNutrition,
                        icon: Icon(isAnalyzed ? Icons.check : Icons.analytics),
                        label: Text(isAnalyzed ? '기록 완료' : '영양소 분석'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAnalyzed
                              ? const Color(0xFF33FF00)
                              : Colors.blue,
                          foregroundColor: isAnalyzed
                              ? Colors.black
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // 📦 리스트 아이템 카드 위젯 (추가됨)
  Widget _buildFoodCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMacroText(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
