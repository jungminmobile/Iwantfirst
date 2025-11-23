import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import 'dart:convert'; // jsonDecode용

class EditFoodScreen extends StatefulWidget {
  final List<Map<String, String>> initialFoods; // 이전 화면에서 넘겨받은 데이터

  const EditFoodScreen({super.key, required this.initialFoods});

  @override
  State<EditFoodScreen> createState() => _EditFoodScreenState();
}

class _EditFoodScreenState extends State<EditFoodScreen> {
  late List<Map<String, String>> _foodList;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    // 리스트 복사 (원본 보호)
    _foodList = List.from(widget.initialFoods);
  }

  // 🟢 음식 추가 다이얼로그
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

  // 🟢 2단계 분석 요청 (최종)
  void _analyzeNutrition() async {
    setState(() => _isAnalyzing = true);

    try {
      final gemini = GeminiService();
      final resultJson = await gemini.analyzeNutritionFromList(_foodList);

      if (resultJson != null && mounted) {
        // 성공! -> 결과 보여주기 (일단 다이얼로그, 나중엔 DB 저장)
        _showResultDialog(resultJson);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _showResultDialog(String json) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('최종 분석 결과'),
        content: SingleChildScrollView(child: Text(json)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // 다이얼로그 닫고
              Navigator.pop(context); // 수정 화면도 닫고 (홈으로 가거나 기록 완료 처리)
              // TODO: 여기서 Firebase DB에 저장하는 로직 추가하면 됨
            },
            child: const Text('기록 완료'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('음식 목록 확인/수정')),
      body: Stack(
        children: [
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('AI가 식별한 결과입니다.\n이름과 양이 맞는지 확인해주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _foodList.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, index) {
                    return ListTile(
                      // 이름 입력 필드
                      title: TextFormField(
                        initialValue: _foodList[index]['name'],
                        decoration: const InputDecoration(labelText: '음식 이름'),
                        onChanged: (v) => _foodList[index]['name'] = v,
                      ),
                      // 양 입력 필드
                      subtitle: TextFormField(
                        initialValue: _foodList[index]['amount'],
                        decoration: const InputDecoration(labelText: '양'),
                        onChanged: (v) => _foodList[index]['amount'] = v,
                      ),
                      // 삭제 버튼
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _foodList.removeAt(index)),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addNewFood,
                        icon: const Icon(Icons.add),
                        label: const Text('음식 추가'),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _analyzeNutrition,
                        icon: const Icon(Icons.check),
                        label: const Text('영양소 분석'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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
          // 로딩 화면
          if (_isAnalyzing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}