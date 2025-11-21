import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase와 Firestore 인스턴스 (Auth는 로그인, Firestore는 데이터 저장 담당)
final _auth = FirebaseAuth.instance;
final _firestore = FirebaseFirestore.instance;
const String _userCollectionPath = 'users';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // 입력 컨트롤러들
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _goalCalorieController = TextEditingController();

  String _selectedGender = '남성';
  bool _isLoading = false;

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    // 입력값 유효성 검사 (간단하게)
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      }
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // 1. Firebase Authentication에 사용자 생성 (경비실에 신분 등록)
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // 2. Firestore에 사용자 데이터 저장 (데이터베이스 창고에 짐 보관)
      //    사용자 데이터 구조: users/{uid} 문서 안에 계정, 프로필, 목표 저장
      await _firestore.collection(_userCollectionPath).doc(uid).set({

        'account_info': {
          'email': _emailController.text.trim(),
          'created_at': FieldValue.serverTimestamp(), // Firestore 서버 시간으로 가입 시간 기록
        },

        'profile': {
          'name': _nameController.text.trim(),
          'height': double.tryParse(_heightController.text) ?? 0.0,
          'gender': _selectedGender,
          // 여기에 'age', 'weight' 등 필드를 나중에 추가해도 됩니다.
        },

        'goals': {
          'target_calories': int.tryParse(_goalCalorieController.text) ?? 2000,
        },

        // 'daily_logs' 서브 컬렉션은 첫 기록 시 자동으로 생성됩니다.
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공! 이제 로그인하세요.')),
        );
        Navigator.pop(context); // 가입 후 로그인 페이지로 돌아가기
      }

    } on FirebaseAuthException catch (e) {
      // Firebase Auth 관련 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 에러: ${e.message}')),
        );
      }
    } catch (e) {
      // 일반 에러 처리
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('알 수 없는 에러: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("계정 정보", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            TextField(controller: _emailController, decoration: const InputDecoration(labelText: '이메일')),
            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)'), obscureText: true),

            const SizedBox(height: 30),
            const Text("프로필 정보", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: '이름/닉네임')),
            TextField(controller: _heightController, decoration: const InputDecoration(labelText: '키 (cm)'), keyboardType: TextInputType.number),

            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: '성별'),
              items: ['남성', '여성'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) => setState(() => _selectedGender = val ?? '남성'),
            ),

            const SizedBox(height: 30),
            const Text("목표 설정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            TextField(controller: _goalCalorieController, decoration: const InputDecoration(labelText: '하루 목표 칼로리 (kcal)'), keyboardType: TextInputType.number),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('가입 완료 및 프로필 저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}