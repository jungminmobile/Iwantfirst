import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
// ★★★ 여기가 핵심 수정 사항입니다: 정확한 파일 경로로 수정 ★★★
// ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
import 'package:hackton_2025_2/screens/setting/edit_profile_screen.dart';
import 'package:hackton_2025_2/screens/setting/account_delete_loading_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }

  void _showDeleteAccountDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String? userNickname;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null && data.containsKey('profile') && data['profile'] is Map && data['profile'].containsKey('name')) {
          userNickname = data['profile']['name'];
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('사용자 정보 로딩 실패: $e')));
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (userNickname == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임 정보를 찾을 수 없어 탈퇴를 진행할 수 없습니다.')),
      );
      return;
    }

    final nicknameController = TextEditingController();
    // 1. 닉네임 입력 팝업
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴 인증'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('계정을 영구적으로 삭제하려면, 아래에 본인의 닉네임을 정확하게 입력해주세요.'),
            const SizedBox(height: 12),
            Text('닉네임: $userNickname', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(
                hintText: '닉네임을 입력하세요',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // 2. 닉네임 일치 확인
              if (nicknameController.text == userNickname) {
                Navigator.of(dialogContext).pop();
                // 3. 최종 확인 팝업
                showDialog(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('정말 탈퇴하시겠습니까?'),
                    content: const Text('모든 데이터가 영구적으로 삭제되며, 이 작업은 되돌릴 수 없습니다.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(confirmContext).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AccountDeleteLoadingScreen(),
                          ));
                        },
                        child: Text('탈퇴 진행', style: TextStyle(color: Colors.red[700])),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('닉네임이 일치하지 않습니다. 다시 확인해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('확인', style: TextStyle(color: Colors.blue[700])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // UI 부분은 변경 없습니다.
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('프로필 및 목표 설정'),
            subtitle: const Text('이름, 키, 성별, 목표 칼로리를 수정합니다.'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EditProfileScreen()),
              );
            },
          ),
          const Divider(),
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
                          _logout();
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person_remove_outlined, color: Colors.red[700]),
            title: Text('회원 탈퇴', style: TextStyle(color: Colors.red[700])),
            onTap: _showDeleteAccountDialog,
          ),
        ],
      ),
    );
  }
}
