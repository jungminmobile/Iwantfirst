import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅용
import '../models/food_item.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 식단 저장 함수
  Future<void> saveMeal({
    required String mealType, // 아침, 점심, 저녁
    required List<FoodItem> foods,
  }) async {
    try {
      // 1. 오늘 날짜 문서 ID 생성 (예: '2025-11-23')
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // 2. 저장할 데이터 준비
      // 각 영양소 합계 계산
      int totalCal = foods.fold(0, (sum, item) => sum + item.calories);
      int totalCarbs = foods.fold(0, (sum, item) => sum + item.carbs);
      int totalProtein = foods.fold(0, (sum, item) => sum + item.protein);
      int totalFat = foods.fold(0, (sum, item) => sum + item.fat);

      // 음식 리스트를 Map 형태로 변환
      List<Map<String, dynamic>> foodMaps = foods.map((f) => f.toMap()).toList();

      // 3. Firestore에 저장
      // 구조: daily_logs (컬렉션) -> 2025-11-23 (문서) -> meals (하위 컬렉션) -> 자동ID (문서)
      await _db
          .collection('daily_logs')
          .doc(today)
          .collection('meals')
          .add({
        'mealType': mealType,
        'foods': foodMaps,
        'totalCalories': totalCal,
        'totalCarbs': totalCarbs,
        'totalProtein': totalProtein,
        'totalFat': totalFat,
        'timestamp': FieldValue.serverTimestamp(), // 저장 시간
      });

      print('✅ 식단 저장 완료!');

    } catch (e) {
      print('❌ 저장 실패: $e');
      throw Exception('저장 중 오류가 발생했습니다.');
    }
  }
}