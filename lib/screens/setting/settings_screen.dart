import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart'; // 방금 만든 화면 임포트

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // 로그아웃 함수
  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
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

  // 목표 칼로리 수정 다이얼로그 표시 함수
  void _showTargetCaloriesDialog(BuildContext context) {
    final caloriesController = TextEditingController();
    final User? currentUser = FirebaseAuth.instance.currentUser;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('목표 칼로리 수정'),
          content: TextField(
            controller: caloriesController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: '새로운 목표 칼로리 입력'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (caloriesController.text.isNotEmpty && currentUser != null) {
                  final newCalories = int.tryParse(caloriesController.text);
                  if (newCalories != null) {
                    try {
                      // 점 표기법을 사용하여 'goals.target_calories'를 업데이트합니다.
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(currentUser.uid)
                          .update({'goals.target_calories': newCalories});

                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('목표 칼로리가 변경되었습니다.')),
                      );
                    } catch (e) {
                      print("목표 칼로리 업데이트 오류: $e");
                    }
                  }
                }
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          // 1. 회원정보 수정
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('회원정보 수정'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // 회원정보 수정 화면으로 이동
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),

          // 2. 목표 칼로리 수정
          ListTile(
            leading: const Icon(Icons.track_changes_outlined),
            title: const Text('목표 칼로리 수정'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // 목표 칼로리 수정 다이얼로그 호출
              _showTargetCaloriesDialog(context);
            },
          ),
          const Divider(),

          // 3. 로그아웃
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃 하시겠습니까?'),
                    actions: [
                      TextButton(
                        child: const Text('취소'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                      TextButton(
                        child: const Text('확인'),
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _logout(context); // 로그아웃 함수 호출
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
            },
          ),
        ],
      ),
    );
  }
}
