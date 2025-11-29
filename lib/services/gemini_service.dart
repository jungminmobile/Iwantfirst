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