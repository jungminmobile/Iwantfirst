import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../api_config.dart';

class GeminiService {
  final model = GenerativeModel(
    // ⚠️ Flash 모델 사용 (속도 빠름, 무료 할당량 많음)
    model: 'gemini-2.5-flash',
    apiKey: geminiApiKey,
    generationConfig: GenerationConfig(
      responseMimeType: 'application/json',
    ),
  );

  // 1단계: 음식 목록 식별
  Future<List<Map<String, String>>?> identifyFoodList(List<XFile> images, List<String> texts) async {
    try {
      String userNotes = texts.isNotEmpty ? "사용자 메모: ${texts.join(', ')}" : "";

      final promptText = """
       역할: 너는 음식 사진과 텍스트 메모를 분석하는 AI 스캐너야.
       [지시사항]
       1. 제공된 사진과 메모($userNotes)를 분석해 음식 '이름'과 '양'을 추출해.
       2. 사진에 없거나 메모에 없는 음식은 절대 추측하지 마.
       3. 양은 대략적인 gram 수를 포함해줘 (예: 약 150g).
       
       [출력 형식]
       반드시 아래와 같은 JSON 배열(List<Map>) 형식으로만 출력해. 마크다운 제외.
       [{"name": "음식명", "amount": "양"}]
      """;

      final contentParts = <Part>[TextPart(promptText)];
      for (var img in images) {
        final bytes = await File(img.path).readAsBytes();
        contentParts.add(DataPart('image/jpeg', bytes));
      }

      final response = await model.generateContent([Content.multi(contentParts)]);
      if (response.text == null) return null;

      String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      List<dynamic> parsed = jsonDecode(cleanJson);

      return parsed.map((item) => {
        "name": item["name"].toString(),
        "amount": item["amount"].toString()
      }).toList();

    } catch (e) {
      print("1단계 오류: $e");
      return null;
    }
  }

  // 2단계: 영양소 분석
  Future<String?> analyzeNutritionFromList(List<Map<String, String>> foodList) async {
    try {
      String foodListStr = foodList.map((f) => "${f['name']} (${f['amount']})").join(", ");

      final promptText = """
        다음 음식 리스트를 바탕으로 영양 성분을 분석해줘.
        음식 리스트: $foodListStr
        
        [지시사항]
        칼로리, 탄수화물, 단백질, 지방, 수분은 반드시 **정수(int)**로만 표현해.
        
        [출력 형식]
        [
          {
            "foodName": "음식 이름",
            "amount": "입력된 양",
            "calories": 0,
            "carbs": 0,
            "protein": 0,
            "fat": 0,
            "water": 0
          }
        ]
      """;

      final response = await model.generateContent([Content.text(promptText)]);
      String cleanJson = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
      return cleanJson;
    } catch (e) {
      print("2단계 오류: $e");
      return null;
    }
  }

  // 3단계: 맞춤형 조언 생성 (🟢 여기가 수정된 부분입니다!)
  Future<String?> generateAdvice(String nutritionAnalysisJson, Map<String, dynamic> userData) async {
    try {
      // 🟢 [안전장치 추가] 데이터가 없거나 null일 경우 기본값('trainer', '유지' 등)을 사용

      // 1. Advisor (조언자 페르소나) 가져오기
      final profileMap = userData['profile'] as Map<String, dynamic>?; // profile이 없으면 null
      final advisor = profileMap?['advisor'] as String? ?? 'trainer';

      // 2. 목표 가져오기
      final userGoal = userData['user_goal'] as String? ?? '건강 유지';

      // 3. 목표 수치 가져오기 (goals 맵 안에 있거나 root에 있을 수 있음)
      final goalsMap = userData['goals'] as Map<String, dynamic>? ?? userData;

      final targetCalories = (goalsMap['target_calories'] as num?)?.toInt() ?? 2000;
      final targetCarbs = (goalsMap['target_carbs'] as num?)?.toInt() ?? 250;
      final targetProtein = (goalsMap['target_protein'] as num?)?.toInt() ?? 75;
      final targetFat = (goalsMap['target_fat'] as num?)?.toInt() ?? 60;

      final promptText = """
        역할: 너는 사용자에게 **${advisor}**의 역할로 식습관 조언을 해주는 AI 어드바이저야.
        
        [사용자 정보]
        - 목표: ${userGoal}
        - 목표 영양소: ${targetCalories}kcal (탄${targetCarbs}g, 단${targetProtein}g, 지${targetFat}g)
        
        [오늘 식사 분석 결과 (JSON)]
        ${nutritionAnalysisJson}
        
        [지시사항]
        1. **${advisor}**의 말투와 성격으로 친근하게 말해줘.
        2. 오늘 총 섭취 칼로리와 3대 영양소를 요약해서 알려줘.
        3. 목표 대비 부족하거나 과한 부분을 짚어줘.
        4. 내일 식단을 위해 구체적인 행동 지침 1가지를 제안해줘.
        5. 자연스러운 텍스트로만 출력해.
      """;

      final response = await model.generateContent([Content.text(promptText)]);

      print("📢 [Gemini Advice] 생성 완료: ${response.text}");
      return response.text;

    } catch (e) {
      print("3단계 오류 - 조언 생성 실패: $e");
      return "AI 조언을 불러오는 중 문제가 발생했습니다.";
    }
  }
}