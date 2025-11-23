import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🟢 [이 함수가 꼭 있어야 합니다!]
  // 새벽 4시 기준 날짜 계산 함수
  String getTodayDate() {
    final now = DateTime.now();
    // 새벽 4시 이전이면 어제 날짜로 계산
    final dietDate = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    return DateFormat('yyyy-MM-dd').format(dietDate);
  }

  // 식단 저장 함수
  Future<void> saveMeal({
    required String mealType, // '아침', '점심', '저녁', '간식'
    required List<FoodItem> foods,
  }) async {
    try {
      String today = getTodayDate(); // 위에서 만든 함수 호출

      int totalCal = foods.fold(0, (sum, item) => sum + item.calories);
      int totalCarbs = foods.fold(0, (sum, item) => sum + item.carbs);
      int totalProtein = foods.fold(0, (sum, item) => sum + item.protein);
      int totalFat = foods.fold(0, (sum, item) => sum + item.fat);

      List<Map<String, dynamic>> foodMaps = foods.map((f) => f.toMap()).toList();

      await _db
          .collection('daily_logs')
          .doc(today)
          .collection('meals')
          .doc(mealType)
          .set({
        'mealType': mealType,
        'foods': foodMaps,
        'totalCalories': totalCal,
        'totalCarbs': totalCarbs,
        'totalProtein': totalProtein,
        'totalFat': totalFat,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ $mealType 식단 저장 완료!');

    } catch (e) {
      print('❌ 저장 실패: $e');
      throw Exception('저장 중 오류가 발생했습니다.');
    }
  }

  // 오늘 날짜의 모든 식단 기록 가져오기
  Future<Map<String, dynamic>> fetchTodayMeals() async {
    String today = getTodayDate(); // 위에서 만든 함수 호출
    Map<String, dynamic> results = {};

    try {
      var snapshot = await _db
          .collection('daily_logs')
          .doc(today)
          .collection('meals')
          .get();

      for (var doc in snapshot.docs) {
        results[doc.id] = doc.data();
      }
      return results;
    } catch (e) {
      print('데이터 불러오기 실패: $e');
      return {};
    }
  }
}