import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase/firebase_options.dart';
//파베 연동 확인
import 'package:firebase_auth/firebase_auth.dart';
// 우리가 만든 홈 화면 임포트
import 'screens/home_screen.dart'; //홈페이지
import 'screens/login/login_page.dart'; //로그인 페이지
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 플러터 엔진 초기화

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
        // 전체 테마 색상을 초록색 계열로 변경 (식단 관리 느낌)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(), // 👈 감시 스트림
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const MainScreen(); // 로그인 상태
          }
          return const LoginPage();  // 로그아웃 상태
        },
      ),
    );
  }
}