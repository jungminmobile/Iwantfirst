import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // 이 파일이 없으면 에러가 납니다 (Firebase CLI 설정 필요)

// 우리가 만든 홈 화면 임포트
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 플러터 엔진 초기화

  // Firebase 초기화 (사용자님이 작성하신 코드 유지)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      // [중요] 여기서 MyHomePage(카운터 앱) 대신 HomeScreen을 연결합니다.
      home: const HomeScreen(),
    );
  }
}

// 밑에 있던 class MyHomePage ... 와 class _MyHomePageState ... 는 이제 필요 없으니 지웁니다.