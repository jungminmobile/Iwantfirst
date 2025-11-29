// lib/models/food_item.dart

class FoodItem {
  final String name;
  final String amount;
  final int calories;
  final int carbs;
  final int protein;
  final int fat;

  FoodItem({
    required this.name,
    required this.amount,
    required this.calories,
    required this.carbs,
    required this.protein,
    required this.fat,
  });

  // JSON 데이터를 받아서 객체로 만드는 생성자
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['foodName'] ?? '이름 없음',
      amount: json['amount'] ?? '',
      // 숫자가 문자열로 올 수도 있어서 안전하게 처리
      calories: int.tryParse(json['calories'].toString()) ?? 0,
      carbs: int.tryParse(json['carbs'].toString()) ?? 0,
      protein: int.tryParse(json['protein'].toString()) ?? 0,
      fat: int.tryParse(json['fat'].toString()) ?? 0,
    );
  }

  // 객체를 다시 JSON(Map)으로 바꾸는 함수 (DB 저장용)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'calories': calories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    };
  }
}