import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // jsonDecode를 위해 필요
import '../api_config.dart';

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
        이 음식 사진들과 메모를 보고, 포함된 모든 음식의 '이름'과 '양'을 추정해줘.
        양을 추정할 때는 대략적인 gram 수를 꼭 포함해줘
        사용자 메모($userNotes)에 있는 음식도 포함해.
        
        반드시 아래와 같은 JSON 배열(List<Map>) 형식으로만 출력해.
        [
          {"name": "현미밥", "amount": "1공기"},
          {"name": "멸치볶음", "amount": "작은 접시 한 개. 약 100g"},
          {"name": "두유", "amount": "1팩 (190ml)"}
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
}