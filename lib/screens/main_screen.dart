import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'camera_screen.dart';
import 'stats_screen.dart';
import 'login/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 현재 선택된 탭 번호 (0: 홈, 1: 입력, 2: 통계)
  int _selectedIndex = 0;

  // 탭별 화면 리스트
  final List<Widget> _screens = [
    const HomeScreen(),   // 0번
    const CameraScreen(), // 1번
    const StatsScreen(),  // 2번
  ];

  // 탭을 눌렀을 때 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  //로그인 로그아웃을 하기위한 임시 코드
  void _logout() async {
    try {
      // 1. FIREBASE에서 현재 사용자 로그아웃을 처리하는 코드는 이것 하나로 충분합니다.
      await FirebaseAuth.instance.signOut();
      print('Firebase 로그아웃 성공');

      // 2. 🌟 Navigator 코드는 제거합니다. 🌟
      // 로그아웃이 성공하면 StreamBuilder가 자동으로 LoginPage로 전환합니다.

      if (mounted) {
        // (선택 사항) 사용자에게 로그아웃 성공 메시지를 표시할 수 있습니다.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃되었습니다.')),
        );
      }

    } catch (e) {
      print('로그아웃 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃에 실패했습니다: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //로그아웃 버튼 임시로 만든것
      appBar: AppBar(
        title: const Text('앱 이름'), // 앱 제목
        actions: [
          // 임시 로그아웃 버튼
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout, // 로그아웃 함수 연결
            tooltip: '로그아웃',
          ),
        ],
      ),
      
      // 현재 선택된 인덱스에 맞는 화면을 보여줌
      body: _screens[_selectedIndex],

      // 하단 네비게이션 바
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        indicatorColor: Colors.green.shade200, // 선택된 탭 배경색
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: '식단기록',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '통계',
          ),
        ],
      ),
    );
  }
}