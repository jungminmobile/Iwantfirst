import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 👈 [추가됨] 사용자 인증 정보 접근을 위해 필요
import 'package:intl/intl.dart';
import '../models/food_item.dart'; // 👈 기존에 사용하시던 FoodItem 모델

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance; // 👈 [추가됨] FirebaseAuth 인스턴스

  // 현재 로그인된 사용자의 UID를 가져오는 헬퍼 함수
  String? getUserId() {
    // 현재 로그인된 유저 객체에서 UID를 반환합니다.
    return _auth.currentUser?.uid;
  }

  // 🟢 새벽 4시 기준 날짜 계산 함수
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
    // 1. UID 가져오기 (사용자 분리의 핵심)
    String? userId = getUserId();
    if (userId == null) {
      print('❌ 저장 실패: 사용자가 로그인되어 있지 않습니다.');
      throw Exception('사용자가 로그인되어 있지 않아 데이터를 저장할 수 없습니다.');
    }

    try {
      String today = getTodayDate(); // 위에서 만든 함수 호출

      // 영양소 합계 계산
      int totalCal = foods.fold(0, (sum, item) => sum + item.calories);
      int totalCarbs = foods.fold(0, (sum, item) => sum + item.carbs);
      int totalProtein = foods.fold(0, (sum, item) => sum + item.protein);
      int totalFat = foods.fold(0, (sum, item) => sum + item.fat);

      List<Map<String, dynamic>> foodMaps = foods.map((f) => f.toMap()).toList();

      // ✅ 경로 수정: UID를 포함하여 사용자별로 데이터 분리
      await _db
          .collection('users')
          .doc(userId) // 👈 [수정] 로그인된 사용자의 UID 문서
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

      print('✅ $mealType 식단 저장 완료! (경로: users/$userId/daily_logs/$today/meals/$mealType)');

    } catch (e) {
      print('❌ 저장 실패: $e');
      throw Exception('저장 중 오류가 발생했습니다.');
    }
  }

  // 오늘 날짜의 모든 식단 기록 가져오기
  Future<Map<String, dynamic>> fetchTodayMeals() async {
    // 1. UID 가져오기 (사용자 분리의 핵심)
    String? userId = getUserId();
    if (userId == null) {
      return {}; // 로그인 안 했으면 빈 데이터 반환
    }

    String today = getTodayDate(); // 위에서 만든 함수 호출
    Map<String, dynamic> results = {};

    try {
      // ✅ 경로 수정: UID를 포함하여 사용자별 데이터에서 불러오기
      var snapshot = await _db
          .collection('users')
          .doc(userId) // 👈 [수정] 로그인된 사용자의 UID 문서
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