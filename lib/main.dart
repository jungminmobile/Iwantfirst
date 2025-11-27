import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase/firebase_options.dart';
//파베 연동 확인
import 'package:firebase_auth/firebase_auth.dart';
// 우리가 만든 홈 화면 임포트
import 'screens/home_screen.dart'; //홈페이지
import 'screens/login/login_page.dart'; //로그인 페이지
import 'screens/main_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 플러터 엔진 초기화

  await initializeDateFormatting();

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  try {
    // FirebaseAuth 인스턴스를 가져와서 null이 아닌지 확인합니다.
    print("✅ Firebase Auth Instance: ${FirebaseAuth.instance}");
    print("🎉 파이어베이스 연동 재확인 성공! 🎉");
  } catch (e) {
    print("❌ 연동 에러: $e");
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // 오른쪽 위 'Debug' 띠 제거
      title: 'AI 식단 관리',
      theme: ThemeData(
        // 1. 폰트 설정 (유지)
        fontFamily: 'Suite',

        // 2. 색상 설정
        colorScheme:
            ColorScheme.fromSeed(
              // [기준] 범위의 딱 중간 색상 (스프링 그린)
              // 이 색을 기준으로 연한색/진한색이 자동 생성됩니다.
              seedColor: const Color(0xFF33CC80),
              brightness: Brightness.light,
            ).copyWith(
              // [메인] 가장 아래쪽 진한 연두색 (확인 버튼, 활성화 탭 등)
              primary: const Color(0xFF33CC00),

              // [강조] 가장 위쪽 하늘색 (플로팅 버튼, 스위치 등)
              secondary: const Color(0xFF33CCFF),

              // [포인트] 중간 색상
              tertiary: const Color(0xFF33CC99),
            ),

        // 3. 배경은 깔끔하게 흰색 (형광색이 돋보이게)
        scaffoldBackgroundColor: Colors.white,

        // 4. 앱바(상단바) 배경색 흰색으로 통일
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // 제목은 검은색
          elevation: 0, // 그림자 제거
        ),

        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // 👈 감시 스트림
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const MainScreen(); // 로그인 상태
          }
          print("로그아웃 화면\n");
          return const LoginPage(); // 로그아웃 상태
        },
      ),
    );
  }
}
