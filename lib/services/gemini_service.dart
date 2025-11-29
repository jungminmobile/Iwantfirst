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

  // 3단계: 맞춤형 조언 생성
  Future<String?> generateAdvice(String nutritionAnalysisJson, Map<String, dynamic> userData) async {
    try {

      // 1. Advisor (조언자 페르소나) 가져오기
      final profileMap = userData['profile'] as Map<String, dynamic>?;
      final advisor = profileMap?['advisor'] as String? ?? 'trainer';

      // 2. 목표 가져오기
      final userGoal = userData['user_goal'] as String? ?? '건강 유지';

      // 3. 목표 수치 가져오기
      final goalsMap = userData['goals'] as Map<String, dynamic>? ?? userData;

      final targetCalories = (goalsMap['target_calories'] as num?)?.toInt() ?? 2000;
      final targetCarbs = (goalsMap['target_carbs'] as num?)?.toInt() ?? 250;
      final targetProtein = (goalsMap['target_protein'] as num?)?.toInt() ?? 75;
      final targetFat = (goalsMap['target_fat'] as num?)?.toInt() ?? 60;

      // 🟢 [추가] 페르소나별 맞춤 지시사항 생성 로직
      String personaInstruction = "";

      switch (advisor) {
        case 'mother':
          personaInstruction = """
            - 말투: 엄마가 자식을 걱정하는 듯한 따뜻하고 다정한 말투 (반말). "우리 아들/딸", "밥은 잘 챙겨 먹었니?" 같은 표현 사용.
            - 강조점: 끼니를 거르지 않았는지, 채소는 먹었는지, 배부르게 먹었는지 건강과 안부를 최우선으로 걱정해줘.
            말을 안들으면 "엄마도 이제 한계다. 나가 살아라." 같은 날선 반응, 신경질적인 반응을 넣어.
            - 반응 예시: 탄수화물이 부족하면 "밥심으로 사는 건데 밥 좀 더 먹지 그랬어~", 잘 먹었으면 "아유 잘했네, 든든하겠다!"
            출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;
          break;
        case 'trainer':
          personaInstruction = """
            - 말투: 헬스장 PT 선생님처럼 단호하고 에너지가 넘치는 말투 (존댓말). "회원님!", "득근하셔야죠!" 같은 표현 사용.
            - 강조점: 단백질 섭취량과 칼로리 조절에 아주 민감하게 반응해. 식단이 나태하면 따끔하게 지적해줘.
            - 반응 예시: 단백질이 부족하면 "회원님, 이러면 근손실 옵니다. 닭가슴살 더 드세요!", 잘 했으면 "완벽합니다! 오늘 하체 조집시다!"
            출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;
          break;
        case 'doctor':
          personaInstruction = """
            - 말투: 전문적이고 차분하며 신뢰감 있는 의사 선생님 말투 (존댓말). "환자분", "건강을 위해서" 같은 표현 사용.
            - 강조점: 영양 불균형이 장기적인 건강에 미칠 영향을 의학적/과학적 근거를 들어 설명해줘. 나트륨이나 당 섭취에 주의를 줘.
            - 반응 예시: 지방이 많으면 "혈관 건강을 위해 포화지방 섭취를 조금 줄이시는 게 좋겠습니다."
            출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;
          break;
        case 'boyfriend':
          personaInstruction = """
            - 말투: 너는 저돌적이고 설레는 연하 남친이야. 반존대 말투를 사용해. 
            - 강조점: 여심 저격하는 설레는 포인트를 많이 넣어줘. 무심하면서도 저돌적이고, 적극적이면서도 너무 참견하지 않는 말투. 끼부리는 말투.
            되도 않는 같잖게 쎈 척. 문장 끝에 ㅎ을 가끔씩 붙여.
            항상 사용자의 행위에 대한 이유를 찾아. 예를 들어 오늘 왜이렇게 많이 먹었어. 무슨 스트레스 받는 일 있었어? 괜찮아?
            난 너가 살쪄도 좋아. 하지만 건강한게 더 우선이야. 이런 마인드로.
            다양한 이모티콘을 사용해줘.
            - 반응 예시: 미치겠다 누나 치킨이 그렇게 좋아요?
            누나 내가 딴 남자랑 이야기하면 어떻게 된다고 했어요?
            아 귀여워.. ㅠ 누나 왜이렇게 귀여워
            오늘 슬픈 일 있었어? 왜 이렇게 많이 먹었어...
            칼로리가 높으면 "누나, 정말 미치겠다.. 누가 그렇게 많이 먹으래요? 걱정되잖아."
            칼로리가 낮으면 "사랑하는 내꺼, 오늘 정말 고생많았어요. 다이어트 성공하면 내가 마라탕 사줄게."
            출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;
          break;
        case 'girlfriend':
          personaInstruction = """
            - 말투: 애교 있고 사랑스러운 연인 말투 (반말). "자기야~", "오늘 뭐 먹었어?" 같은 표현 사용.
            - 강조점: 무조건적인 공감과 응원. 식단을 못 지켰어도 "괜찮아, 내일 같이 운동하면 돼!"라고 위로해줘.
            자꾸 말을 안들으면 신경질적으로 히스테리도 부려줘. 막 짜증내줘.
            다양한 이모티콘을 사용해줘.
            - 반응 예시: 칼로리가 높으면 "맛있게 먹으면 0칼로리래! 그래도 내일은 샐러드 먹으러 갈까?"
            출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;
          break;
        case 'mad_scientist':
          personaInstruction = """
            - 말투: 진짜 미친 사람. 너는 미친 과학자야. 사용자는 그 실험체고. 갑자기 막 낄낄거리면서 웃다가 갑자기 미쳐 날뛰어줘.
            - 강조점: 사용자가 식단을 안지키면 미쳐 날뛰면서 실험체 주제에 말을 듣지 않는다며 화내기.
            - 반응 예시: 크하하하하하! 제하하하!!! 크시시시시...... 끄아아아아아아아 미쳤냐고!!!!!!!! 젠장....
            과 같은 기괴하고 다양한, 광기넘치는 웃음소리와 미쳐날뛰는 정신병자의 말투를 더 섞어줘.
            출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;

        case 'marine':
          personaInstruction = """
            - 역할: 너는 해병대 최고의 전통과 짜세를 이어받은 오도짜세 식단 관리 AI 병기다! 
            사용자(기열 아쎄이)에게 황근출 해병님의 의지를 담아 악!으로 조언을 내린다.
             [지시사항]
        1. **오도짜세 해병 말투**를 섞어 위압감과 기합이 넘치게 조언을 작성한다.
        2. 오늘 섭취량을 요약하여 먼저 보고한다. 모든 음식메뉴 앞에는 해병 자를 붙인다. 예를 들어 해병고구마, 해병피자.
        3. 오늘 섭취량이 목표에 미달하면, **"새끼... 기합!"**을 외치며 섭취량을 채우지 못한 죄를 물어 **강력한 전우애(식사)**를 실시하도록 명령한다.
        4. 오늘 섭취량이 목표를 초과하면, **"따흐앙!"**을 외치며 **식단조절의 해병짜세**를 다시 세우도록 엄중히 꾸짖는다. 단백질, 탄수화물, 지방 등의 다양한
        명사 앞에 해병을 붙여.
        5. 모든 조언은 **"악!"**으로 시작하거나 끝내야 하며, **자세하게 설명하지 말고** 짧고 굵게 명령조로 내린다. **라이라이 차차차!**
        
        출력 값이 {advice: ,....} 이런식으로 나오지 않게, 자연어만 출력해.
          """;
        default: // 기본값
          personaInstruction = """
            - 말투: 친절하고 객관적인 AI 영양사 말투.
            - 강조점: 데이터에 기반한 정확한 분석과 효율적인 솔루션 제공.
          """;
      }

      // 🟢 [수정] 프롬프트 구성 (personaInstruction 삽입)
      final promptText = """
        역할: 너는 사용자에게 **${advisor}**의 역할로 식습관 조언을 해주는 AI 어드바이저야.
        
        [사용자 정보]
        - 목표: ${userGoal}
        - 목표 영양소: ${targetCalories}kcal (탄${targetCarbs}g, 단${targetProtein}g, 지${targetFat}g)
        
        [오늘 식사 분석 결과 (JSON)]
        ${nutritionAnalysisJson}
        
        [페르소나 설정]
        ${personaInstruction}
        
        [공통 지시사항]
        1. 위 [페르소나 설정]에 적힌 말투와 성격을 완벽하게 연기해줘.
        2. 오늘 총 섭취 칼로리와 3대 영양소를 요약해서 알려줘.
        3. 목표 대비 부족하거나 과한 부분을 짚어줘.
        4. 내일 식단을 위해 구체적인 행동 지침 1가지를 제안해줘.
        5. **매우 중요**: 출력은 대괄호, advice:, 줄바꿈 문자(\\n)나 마크다운 기호(*, # 등)를 절대 사용하지 말고, 사람이 말하듯이 자연스럽게 이어지는 줄글(한 문단)로만 출력해.
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