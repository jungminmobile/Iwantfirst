import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'camera_screen.dart';
import 'stats_screen.dart';
import 'login/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hackton_2025_2/screens/settings_screen.dart';

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
    const SettingsScreen(), // 3번
  ];

  // 탭을 눌렀을 때 실행되는 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  //로그인 로그아웃을 하기위한 임시 코드



  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          )
        ],
      ),
    );
  }
}