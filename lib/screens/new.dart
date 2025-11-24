import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth 임포트class SettingsScreen extends StatelessWidget {

const SettingsScreen
(
{super.key});

// 로그아웃 함수


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
// ... (회원정보 수정, 목표 칼로리 수정 ListTile)
ListTile(
leading: const Icon(Icons.person_outline),
title: const Text('회원정보 수정'),
trailing: const Icon(Icons.arrow_forward_ios, size: 16),
onTap: () {
print('회원정보 수정 눌림');
},
),
ListTile(
leading: const Icon(Icons.track_changes_outlined),
title: const Text('목표 칼로리 수정'),
trailing: const Icon(Icons.arrow_forward_ios, size: 16),
onTap: () {
print('목표 칼로리 수정 눌림');
},
),
const Divider(),

// ▼▼▼ 로그아웃 ListTile 수정 ▼▼▼
ListTile(
leading: const Icon(Icons.logout),
title: const Text('로그아웃'),
onTap: () {
// 로그아웃 확인 다이얼로그 표시
showDialog(
context: context,
builder: (BuildContext dialogContext) {
return AlertDialog(
title: const Text('로그아웃'),
content: const Text('정말 로그아웃 하시겠습니까?'),
actions: [
TextButton(
child: const Text('취소'),
onPressed: () {
Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
},
),
TextButton(
child: const Text('확인'),
onPressed: () {
// 다이얼로그를 먼저 닫고 로그아웃 함수 실행
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

// ... (회원 탈퇴 ListTile)
ListTile(
leading: Icon(Icons.person_remove_outlined, color: Colors.red[700]),
title: Text('회원 탈퇴', style: TextStyle(color: Colors.red[700])),
onTap: () {
print('회원 탈퇴 눌림');
},
),
],
),
);
}
}
