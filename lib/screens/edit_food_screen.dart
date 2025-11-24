import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import '../models/food_item.dart';
import 'dart:convert';

class EditFoodScreen extends StatefulWidget {
  final List<Map<String, String>> initialFoods;
  final String mealType;

  const EditFoodScreen({
    super.key,
    required this.initialFoods,
    required this.mealType,
  });

  @override
  State<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends State<EditFoodScreen> {
  // 1. 초기 상태: 이름과 양을 수정하는 리스트
  late List<Map<String, String>> _foodList;

  // 2. 분석 완료 상태: 영양소 정보가 포함된 리스트 (비어있으면 분석 전)
  List<FoodItem> _analyzedFoods = [];

  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _foodList = List.from(widget.initialFoods);
  }

  // 음식 추가 다이얼로그
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
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

  // 영양소 분석 요청
  void _analyzeNutrition() async {
    setState(() => _isAnalyzing = true);

    try {
      final gemini = GeminiService();
      final resultJson = await gemini.analyzeNutritionFromList(_foodList);

      if (resultJson != null && mounted) {
        // JSON 파싱 -> FoodItem 리스트로 변환
        List<dynamic> parsed = jsonDecode(resultJson);
        setState(() {
          _analyzedFoods = parsed.map((x) => FoodItem.fromJson(x)).toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // DB 저장 요청
  void _saveToDatabase() async {
    try {
      setState(() => _isAnalyzing = true); // 저장 중 로딩 표시

      await DatabaseService().saveMeal(
        mealType: widget.mealType,
        foods: _analyzedFoods,
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('식단이 저장되었습니다! 📝')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAnalyzed = _analyzedFoods.isNotEmpty;

    // 🟢 [추가] 총합 계산 (분석되었을 때만 0보다 큼)
    int totalCal = isAnalyzed ? _analyzedFoods.fold(0, (sum, item) => sum + item.calories) : 0;
    int totalCarbs = isAnalyzed ? _analyzedFoods.fold(0, (sum, item) => sum + item.carbs) : 0;
    int totalProtein = isAnalyzed ? _analyzedFoods.fold(0, (sum, item) => sum + item.protein) : 0;
    int totalFat = isAnalyzed ? _analyzedFoods.fold(0, (sum, item) => sum + item.fat) : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('음식 목록 확인/수정')),
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
              Expanded(
                child: ListView.separated(
                  itemCount: isAnalyzed ? _analyzedFoods.length : _foodList.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, index) {
                    if (isAnalyzed) {
                      final food = _analyzedFoods[index];
                      return ListTile(
                        key: ObjectKey(food),
                        title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('양: ${food.amount}'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${food.calories}kcal  |  탄 ${food.carbs}g  단 ${food.protein}g  지 ${food.fat}g',
                                style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return ListTile(
                        key: ObjectKey(_foodList[index]),

                        title: TextFormField(
                          initialValue: _foodList[index]['name'],
                          decoration: const InputDecoration(labelText: '음식 이름'),
                          onChanged: (v) => _foodList[index]['name'] = v,
                        ),
                        subtitle: TextFormField(
                          initialValue: _foodList[index]['amount'],
                          decoration: const InputDecoration(labelText: '양'),
                          onChanged: (v) => _foodList[index]['amount'] = v,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _foodList.removeAt(index)),
                        ),
                      );
                    }
                  },
                ),
              ),

              // 🟢 [추가됨] 총합계 표시 섹션 (분석 완료 시에만 보임)
              if (isAnalyzed)
                Container(
                  width: double.infinity, // 가로 꽉 차게
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 0), // 버튼과의 간격 조절
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50], // 연한 파란 배경
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text('총 섭취 영양소', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(
                        '$totalCal kcal',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildMacroText('탄수화물', '${totalCarbs}g'),
                          Container(width: 1, height: 12, color: Colors.grey[300]), // 구분선
                          _buildMacroText('단백질', '${totalProtein}g'),
                          Container(width: 1, height: 12, color: Colors.grey[300]), // 구분선
                          _buildMacroText('지방', '${totalFat}g'),
                        ],
                      ),
                    ],
                  ),
                ),

              // 하단 버튼 영역
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isAnalyzed
                            ? () { setState(() { _analyzedFoods = []; }); }
                            : _addNewFood,
                        icon: Icon(isAnalyzed ? Icons.refresh : Icons.add),
                        label: Text(isAnalyzed ? '다시 수정하기' : '음식 추가'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isAnalyzed ? _saveToDatabase : _analyzeNutrition,
                        icon: Icon(isAnalyzed ? Icons.save : Icons.analytics),
                        label: Text(isAnalyzed ? '기록 완료' : '영양소 분석'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAnalyzed ? Colors.green : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildMacroText(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }
}