// lib/models/nutrient_data.dart

class NutrientData {
  final double currentCalories;
  final double targetCalories;
  final double currentCarbs; // 탄수화물
  final double targetCarbs;
  final double currentProtein; // 단백질
  final double targetProtein;
  final double currentFat; // 지방
  final double targetFat;

  NutrientData({
    required this.currentCalories,
    required this.targetCalories,
    required this.currentCarbs,
    required this.targetCarbs,
    required this.currentProtein,
    required this.targetProtein,
    required this.currentFat,
    required this.targetFat,
  });
}