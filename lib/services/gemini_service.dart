import 'dart:io';
import 'package:flutter/material.dart'; // import 'package:flutter/material.dart';는 일반적으로 필요 없지만, SnackBar 등을 위해 추가했을 수 있어 남겨둠
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // jsonDecode를 위해 필요
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth 사용을 위해 추가
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore 사용을 위해 추가
import '../api_config.dart'; // API 키가 정의된 파일

class GeminiService {
  final model = GenerativeModel(
    model: 'gemini-2.5-flash',
    apiKey: geminiApiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    ),
  );

  // 1단계: 이미지와 텍스트를 보고 "음식 이름 목록"만 반환
  Future<List<Map<String, String>>?> identifyFoodList(List<XFile> images, List<String> texts) async {
    try {
      String userNotes = texts.isNotEmpty ? "사용자 메모: ${texts.join(', ')}" : "";

      final promptText = """
       역할: 너는 음식 사진과 텍스트 메모를 분석하는 AI 스캐너야.
      
      [지시사항]
      1. 제공된 사진과 사용자 메모($userNotes)를 분석하여 포함된 음식의 '이름'과 '양'을 추출해.
      2. **절대 추측하지 마.** 사진에 보이지 않거나 메모에 적혀있지 않은 음식(반찬, 국, 물 등)은 절대 추가하면 안 돼.
      3. 오직 입력된 데이터(사진 시각 정보, 텍스트 내용)에 확실히 존재하는 것만 결과에 포함해.
      4. 양을 추정할 때는 대략적인 gram 수를 포함해줘 (예: 약 150g).
      5. 사진이 없고 텍스트만 있다면, 텍스트에 언급된 음식만 반환해.
      
      [출력 형식]
      반드시 아래와 같은 JSON 배열(List<Map>) 형식으로만 출력해. 주석이나 마크다운(```json)을 포함하지 마.
      
      [형식 예시 - 내용은 참고하지 말고 형식만 따를 것]
      [
        {"name": "사과", "amount": "1개 (약 200g)"},
        {"name": "피자", "amount": "2조각 (약 300g)"}
      ]
      """;

      final contentParts = <Part>[TextPart(promptText)];
      for (var img in images) {
        final bytes = await File(img.path).readAsBytes();
        contentParts.add(DataPart('image/jpeg', bytes));
      }

      final response = await model.generateContent([
        Content.multi(contentParts)
      ]);

      if (response.text == null) return null;

      // JSON 파싱 (List<dynamic> -> List<Map<String, String>>)
      List<dynamic> parsed = jsonDecode(response.text!);
      return parsed.map((item) => {
        "name": item["name"].toString(),
        "amount": item["amount"].toString()
      }).toList();

    } catch (e) {
      print("1단계 오류: $e");
      return null;
    }
  }

  // 2단계: 이름과 양을 모두 받아서 영양소 분석
  Future<String?> analyzeNutritionFromList(List<Map<String, String>> foodList) async {
    try {
      // 프롬프트 만들기
      String foodListStr = foodList.map((f) => "${f['name']} (${f['amount']})").join(", ");

      final promptText = """
        다음 음식 리스트를 바탕으로 영양 성분을 분석해줘.
        음식 리스트: $foodListStr
        
        각 음식의 제시된 양을 기준으로 영양소를 추정해서 아래 JSON 형식으로 출력해.
        
        [지시사항]
        칼로리, 탄수화물, 단백질, 지방, 수분은 반드시 **정수(int)**로만 표현해.
        
        [출력 형식]
        [
          {
            "foodName": "음식 이름",
            "amount": "입력된 양",
            "calories": 총칼로리(정수),
            "carbs": 탄수화물(정수),
            "protein": 단백질(정수),
            "fat": 지방(정수)
            "water": 수분(정수)
          },
          ...
        ]
      """;

      final response = await model.generateContent([
        Content.text(promptText)
      ]);
      return response.text;
    } catch (e) {
      print("2단계 오류: $e");
      return null;
    }
  }

  // 3단계: 영양소 분석 결과와 사용자 목표를 기반으로 맞춤형 조언 생성
  // 파이어베이스에서 가져온 사용자 데이터가 Map 형태로 필요합니다.
  Future<String?> generateAdvice(String nutritionAnalysisJson, Map<String, dynamic> userData) async {
    try {
      // ----------------------------------------------------
      // 1. userData에서 필요한 정보 추출
      // ----------------------------------------------------
      // userData 맵 구조: {'profile': {'advisor': 'mother', ...}, 'target_calories': 1946, ...}
      final advisor = userData['profile']['advisor'] as String? ?? 'trainer'; // 역할 (기본값 trainer)
      final userGoal = userData['user_goal'] as String? ?? '유지'; // 목표 (기본값 유지)
      // num으로 받은 후 int로 변환하거나, null 체크를 통해 기본값 할당 (파이어스토어 데이터 구조에 따라 num일 수 있음)
      final targetCalories = userData.containsKey('target_calories') ? (userData['target_calories'] as num).toInt() : 2000;
      final targetCarbs = userData.containsKey('target_carbs') ? (userData['target_carbs'] as num).toInt() : 275;
      final targetProtein = userData.containsKey('target_protein') ? (userData['target_protein'] as num).toInt() : 75;
      final targetFat = userData.containsKey('target_fat') ? (userData['target_fat'] as num).toInt() : 60;

      // ----------------------------------------------------
      // 2. 프롬프트 구성
      // ----------------------------------------------------
      final promptText = """
        역할: 너는 사용자에게 **${advisor}**의 역할로 식습관 조언을 해주는 AI 어드바이저야.
        
        [사용자 정보]
        - 목표: ${userGoal}
        - 일일 목표 칼로리: ${targetCalories}kcal
        - 일일 목표 탄수화물: ${targetCarbs}g
        - 일일 목표 단백질: ${targetProtein}g
        - 일일 목표 지방: ${targetFat}g
        
        [오늘 식사 분석 결과 (JSON)]
        ${nutritionAnalysisJson}
        
        [지시사항]
        1. **${advisor}**의 페르소나에 맞춰 친근하고 도움이 되는 어투로 조언을 작성해.
        2. 오늘 식사 분석 결과(JSON)를 요약하여 **총 칼로리 및 3대 영양소 섭취량**을 먼저 알려줘. (예: "오늘 총 섭취 칼로리는 500kcal이고, 탄수화물 70g, 단백질 20g, 지방 15g을 섭취했어.")
        3. 이 섭취량이 사용자의 일일 목표(칼로리 및 영양소) 대비 **과도한지 또는 부족한지**를 명확하게 짚어줘.
        4. 사용자의 **목표($userGoal)** 달성에 도움이 되도록 구체적인 행동 개선 방안을 1~2가지 제시해.
        5. 출력은 JSON 형식을 사용하지 말고, 사용자에게 직접 말하는 **자연스러운 텍스트**로만 출력해.
      """;

      // ----------------------------------------------------
      // 3. Gemini 호출
      // ----------------------------------------------------
      final response = await model.generateContent([
        Content.text(promptText)
      ]);
      // ✅ 추가된 로그: Gemini가 생성한 조언 내용을 로그캣에 출력
      print("📢 [Gemini Advice] 조언 생성 성공:");
      print("--------------------------------------------------");
      print(response.text);
      print("--------------------------------------------------");
      // ----------------------------------------------------
      // 4. 결과 반환
      // ----------------------------------------------------
      return response.text;

    } catch (e) {
      print("3단계 오류 - 조언 생성 실패: $e");
      return "조언을 생성하는 데 문제가 발생했습니다.";
    }
  }
}