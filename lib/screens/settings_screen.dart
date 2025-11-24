import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      print('Firebase 로그아웃 성공');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃되었습니다.')),
        );
      }
    } catch (e) {
      print('로그아웃 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃에 실패했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(
      title: const Text('설정'),
      // AppBar의 하단 그림자 제거 (디자인 통일성)
      elevation: 0,
      backgroundColor: Colors.white, // 배경색을 흰색으로 지정
      foregroundColor: Colors.black, // 제목 텍스트 색상을 검은색으로 지정
    ),
      // ListView를 사용하여 스크롤 가능한 목록 생성
      body: ListView(
        children: [
          // 1. 회원정보 수정
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('회원정보 수정'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 회원정보 수정 화면으로 이동하는 코드 구현
              print('회원정보 수정 눌림');
            },
          ),

          // 2. 목표 칼로리 수정
          ListTile(
            leading: const Icon(Icons.track_changes_outlined),
            title: const Text('목표 칼로리 수정'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: 목표 칼로리 수정 다이얼로그 또는 화면으로 이동하는 코드 구현
              print('목표 칼로리 수정 눌림');
            },
          ),

          // 구분선
          const Divider(),

          // 3. 로그아웃
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () {
              // TODO: 로그아웃 기능 구현 (예: SharedPreferences 토큰 삭제, 로그인 화면으로 이동)
              print('로그아웃 눌림');
              // 예시: 확인 다이얼로그 표시
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                        child: const Text('취소'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: const Text('확인'),
                        onPressed: () {
                          // 실제 로그아웃 로직 실행
                          Navigator.of(context).pop(); // 다이얼로그 닫기
                          _logout(context);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // 4. 회원 탈퇴
          ListTile(
            leading: Icon(Icons.person_remove_outlined, color: Colors.red[700]),
            title: Text('회원 탈퇴', style: TextStyle(color: Colors.red[700])),
            onTap: () {
              // TODO: 회원 탈퇴 기능 구현
              print('회원 탈퇴 눌림');
              // 예시: 확인 다이얼로그 표시
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('회원 탈퇴'),
                    content: const Text('정말 탈퇴하시겠습니까?\n모든 데이터가 영구적으로 삭제됩니다.'),
                    actions: [
                      TextButton(
                        child: const Text('취소'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('탈퇴', style: TextStyle(color: Colors.red[700])),
                        onPressed: () {
                          // 실제 회원 탈퇴 로직 실행
                          Navigator.of(context).pop(); // 다이얼로그 닫기
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
