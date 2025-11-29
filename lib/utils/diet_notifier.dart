// lib/utils/diet_notifier.dart
import 'package:flutter/material.dart';

// 어디서든 접근 가능한 '식단 변경 알림이'
class DietNotifier {
  // 변경 사항이 생길 때마다 이 값을 바꿈
  static final ValueNotifier<bool> shouldRefresh = ValueNotifier(false);

  // "야! 식단 바뀌었어!"라고 소리치는 함수
  static void notify() {
    shouldRefresh.value = !shouldRefresh.value; // 값을 토글해서 리스너를 깨움
  }
}