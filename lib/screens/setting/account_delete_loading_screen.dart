import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AccountDeleteLoadingScreen extends StatefulWidget {
  const AccountDeleteLoadingScreen({super.key});

  @override
  State<AccountDeleteLoadingScreen> createState() => _AccountDeleteLoadingScreenState();
}

class _AccountDeleteLoadingScreenState extends State<AccountDeleteLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deleteAccountAndData();
    });
  }

  Future<void> _deleteAccountAndData() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      _showErrorAndGoBack('오류: 로그인된 사용자를 찾을 수 없습니다.');
      return;
    }

    try {
      // 1. Firestore 데이터를 먼저 삭제합니다. (이 부분은 보통 성공합니다)
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).delete();

      // 2. Auth 계정 삭제를 시도합니다.
      //    로그인한 지 오래되었다면 이 부분에서 'requires-recent-login' 오류가 발생합니다.
      await currentUser.delete();

      // 3. 위 두 작업이 모두 성공한 경우 (로그인한 직후 탈퇴를 시도한 경우)
      _showSuccessAndFinish();

    } on FirebaseAuthException catch (e) {
      // ★★★★★ 여기가 핵심 수정 사항입니다 ★★★★★
      // 'requires-recent-login' 오류를 잡아서 사용자에게 명확한 안내를 합니다.
      if (e.code == 'requires-recent-login') {
        _showGuidanceAndGoBack(
            '보안을 위해 재로그인이 필요합니다.\n\n'
                '데이터는 삭제되었으나 계정은 남아있습니다. '
                '앱을 완전히 종료 후 다시 로그인하여 즉시 탈퇴를 다시 진행해주세요.'
        );
      } else {
        // 그 외 다른 Firebase 오류 처리
        _showErrorAndGoBack('계정 삭제 중 오류가 발생했습니다. (코드: ${e.code})');
      }
    } catch (e) {
      // 모든 알 수 없는 오류 처리
      _showErrorAndGoBack('알 수 없는 오류가 발생했습니다: $e');
    }
  }

  // 성공 처리 함수
  void _showSuccessAndFinish() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원 탈퇴가 성공적으로 완료되었습니다.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // 오류 처리 함수
  void _showErrorAndGoBack(String message) {
    if (!mounted) return;
    Navigator.of(context).pop(); // 로딩 화면 닫기
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ★★★ 재로그인 안내를 위한 새로운 함수 ★★★
  void _showGuidanceAndGoBack(String message) {
    if (!mounted) return;
    Navigator.of(context).pop(); // 로딩 화면 닫기
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('재로그인 필요'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // 사용자가 앱을 재시작하도록 유도 (코드로 강제 종료는 권장되지 않음)
            },
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('계정과 데이터를 안전하게 삭제하는 중입니다...'),
          ],
        ),
      ),
    );
  }
}
