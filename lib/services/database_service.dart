import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/food_item.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 로그인된 사용자의 UID를 가져오는 헬퍼 함수
  String? getUserId() {
    return _auth.currentUser?.uid;
  }

  // 새벽 4시 기준 날짜 계산 함수
  String getTodayDate() {
    final now = DateTime.now();
    final dietDate = now.hour < 4 ? now.subtract(const Duration(days: 1)) : now;
    return DateFormat('yyyy-MM-dd').format(dietDate);
  }

  // 식단 저장 함수
  Future<void> saveMeal({
    required String mealType,
    required List<FoodItem> foods,
    DateTime? date,
  }) async {
    String? userId = getUserId();
    if (userId == null) {
      print('❌ 저장 실패: 사용자가 로그인되어 있지 않습니다.');
      // 실제 앱에서는 여기서 로그인 화면으로 보내거나 에러 처리를 해야 합니다.
      return;
    }

    try {
      String targetDate;
      if (date != null) {
        targetDate = DateFormat('yyyy-MM-dd').format(date);
      } else {
        targetDate = getTodayDate();
      }

      int totalCal = foods.fold(0, (sum, item) => sum + item.calories);
      int totalCarbs = foods.fold(0, (sum, item) => sum + item.carbs);
      int totalProtein = foods.fold(0, (sum, item) => sum + item.protein);
      int totalFat = foods.fold(0, (sum, item) => sum + item.fat);

      List<Map<String, dynamic>> foodMaps = foods.map((f) => f.toMap()).toList();

      // ✅ 저장 경로: users -> uid -> daily_logs -> 날짜 -> meals -> 아침
      await _db
          .collection('users')
          .doc(userId)
          .collection('daily_logs')
          .doc(targetDate)
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

      print('✅ $mealType 식단 저장 완료! (경로: users/$userId/daily_logs/$targetDate/meals/$mealType)');

    } catch (e) {
      print('❌ 저장 실패: $e');
      throw Exception('저장 중 오류가 발생했습니다.');
    }
  }

  // 오늘 날짜의 모든 식단 기록 가져오기
  Future<Map<String, dynamic>> fetchTodayMeals([DateTime? date]) async {
    // 🟢 1. 불러올 때도 유저 ID가 필요합니다!
    String? userId = getUserId();
    if (userId == null) return {}; // 로그인 안 했으면 빈 데이터 반환

    String targetDate;
    if (date != null) {
      targetDate = DateFormat('yyyy-MM-dd').format(date);
    } else {
      targetDate = getTodayDate();
    }

    Map<String, dynamic> results = {};

    try {
      // 🟢 2. 경로 수정: 저장한 곳과 똑같은 경로(users -> uid...)를 찾아가야 합니다.
      var snapshot = await _db
          .collection('users')      // 👈 여기 수정됨
          .doc(userId)              // 👈 여기 수정됨
          .collection('daily_logs')
          .doc(targetDate)
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