import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Firebase와 Firestore 인스턴스
final _auth = FirebaseAuth.instance;
final _firestore = FirebaseFirestore.instance;
const String _userCollectionPath = 'users';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  // --- 컨트롤러 ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController(); // ★ 1. 몸무게 컨트롤러 추가
  final _goalCalorieController = TextEditingController();
  final _goalCarbsController = TextEditingController();
  final _goalProteinController = TextEditingController();
  final _goalFatController = TextEditingController();

  // --- 포커스 노드 (힌트 표시용) ---
  final _calorieFocusNode = FocusNode();
  final _carbsFocusNode = FocusNode();
  final _proteinFocusNode = FocusNode();
  final _fatFocusNode = FocusNode();

  String _selectedGender = '남성';
  bool _isLoading = false;

  // --- 권장 섭취량 저장 변수 ---
  int? _recommendedCalories;
  int? _recommendedCarbs;
  int? _recommendedProtein;
  int? _recommendedFat;


  @override
  void initState() {
    super.initState();
    // ★ 2. 키, 몸무게 값이 변경될 때마다 계산 함수 호출
    _heightController.addListener(_calculateRecommendations);
    _weightController.addListener(_calculateRecommendations);

    // FocusNode에 리스너를 추가하여 힌트가 제때 보이도록 화면 갱신
    _calorieFocusNode.addListener(() => setState(() {}));
    _carbsFocusNode.addListener(() => setState(() {}));
    _proteinFocusNode.addListener(() => setState(() {}));
    _fatFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // 모든 컨트롤러와 FocusNode, 리스너를 정리하여 메모리 누수 방지
    _heightController.removeListener(_calculateRecommendations);
    _weightController.removeListener(_calculateRecommendations);
    _calorieFocusNode.removeListener(() => setState(() {}));
    _carbsFocusNode.removeListener(() => setState(() {}));
    _proteinFocusNode.removeListener(() => setState(() {}));
    _fatFocusNode.removeListener(() => setState(() {}));

    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalCalorieController.dispose();
    _goalCarbsController.dispose();
    _goalProteinController.dispose();
    _goalFatController.dispose();

    _calorieFocusNode.dispose();
    _carbsFocusNode.dispose();
    _proteinFocusNode.dispose();
    _fatFocusNode.dispose();
    super.dispose();
  }

  // ★ 3. 표준 권장 섭취량 계산 함수
  void _calculateRecommendations() {
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);

    // 키 또는 몸무게 값이 유효하지 않으면 계산하지 않음
    if (height == null || height <= 0 || weight == null || weight <= 0) {
      setState(() {
        _recommendedCalories = null;
        _recommendedCarbs = null;
        _recommendedProtein = null;
        _recommendedFat = null;
      });
      return;
    }

    // 해리스-베네딕트 방정식 (나이는 30세, 활동량은 적음(x1.2)으로 가정)
    double bmr;
    if (_selectedGender == '남성') {
      bmr = (66.47 + (13.75 * weight) + (5 * height) - (6.76 * 30)) * 1.2;
    } else {
      bmr = (655.1 + (9.56 * weight) + (1.85 * height) - (4.68 * 30)) * 1.2;
    }

    // 계산된 값을 상태 변수에 저장 (탄수화물 50%, 단백질 30%, 지방 20% 비율)
    setState(() {
      _recommendedCalories = bmr.round();
      _recommendedCarbs = ((_recommendedCalories! * 0.5) / 4).round();
      _recommendedProtein = ((_recommendedCalories! * 0.3) / 4).round();
      _recommendedFat = ((_recommendedCalories! * 0.2) / 9).round();
    });
  }

  // ★ 4. 가입 로직 수정 (권장량 저장 및 자동 로그아웃)
  Future<void> _signUp() async {
    setState(() { _isLoading = true; });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      setState(() { _isLoading = false; });
      return;
    }

    try {
      // 1. 계정 생성
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final String uid = userCredential.user!.uid;

      // 2. 데이터베이스에 정보 저장
      await _firestore.collection(_userCollectionPath).doc(uid).set({
        'account_info': {'email': email,'created_at': FieldValue.serverTimestamp()},
        'profile': {
          'name': _nameController.text.trim(),
          'height': double.tryParse(_heightController.text) ?? 0.0,
          'weight': double.tryParse(_weightController.text) ?? 0.0, // 몸무게 저장
          'gender': _selectedGender,
        },
        'goals': {
          // 사용자가 직접 입력했으면 그 값을, 아니면 계산된 권장량을 저장
          'target_calories': int.tryParse(_goalCalorieController.text.trim()) ?? _recommendedCalories ?? 2000,
          'target_carbs': int.tryParse(_goalCarbsController.text.trim()) ?? _recommendedCarbs ?? 0,
          'target_protein': int.tryParse(_goalProteinController.text.trim()) ?? _recommendedProtein ?? 0,
          'target_fat': int.tryParse(_goalFatController.text.trim()) ?? _recommendedFat ?? 0,
        },
      });

      // 3. 화면 전환 충돌 방지를 위해 즉시 로그아웃
      await _auth.signOut();

      // 4. 로그인 페이지로 돌아가기
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('회원가입 성공! 이제 로그인하세요.')));
        Navigator.pop(context);
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('회원가입 에러: ${e.message}')));
        setState(() { _isLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('알 수 없는 에러: $e')));
        setState(() { _isLoading = false; });
      }
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

            // ★ 5. 몸무게 입력 필드 UI 추가
            const SizedBox(height: 8),
            TextField(controller: _weightController, decoration: const InputDecoration(labelText: '몸무게 (kg)'), keyboardType: TextInputType.number),

            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(labelText: '성별'),
              items: ['남성', '여성'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (val) {
                // 성별 변경 시에도 다시 계산
                if (val != null) {
                  setState(() => _selectedGender = val);
                  _calculateRecommendations();
                }
              },
            ),

            const SizedBox(height: 30),
            const Text("목표 설정", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),

            // ★ 6. 목표 설정 UI 수정 (힌트 기능 적용)
            TextField(
              controller: _goalCalorieController,
              focusNode: _calorieFocusNode, // FocusNode 연결
              decoration: InputDecoration(
                labelText: '목표 칼로리 (kcal)',
                // 포커스 상태이고, 입력값이 없고, 추천값이 있을 때만 힌트 표시
                hintText: _calorieFocusNode.hasFocus && _goalCalorieController.text.isEmpty && _recommendedCalories != null
                    ? '권장: $_recommendedCalories kcal'
                    : null,
                hintStyle: const TextStyle(color: Colors.green), // 힌트 텍스트 색상
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalCarbsController,
              focusNode: _carbsFocusNode,
              decoration: InputDecoration(
                labelText: '목표 탄수화물 (g)',
                hintText: _carbsFocusNode.hasFocus && _goalCarbsController.text.isEmpty && _recommendedCarbs != null
                    ? '권장: $_recommendedCarbs g'
                    : null,
                hintStyle: const TextStyle(color: Colors.green),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalProteinController,
              focusNode: _proteinFocusNode,
              decoration: InputDecoration(
                labelText: '목표 단백질 (g)',
                hintText: _proteinFocusNode.hasFocus && _goalProteinController.text.isEmpty && _recommendedProtein != null
                    ? '권장: $_recommendedProtein g'
                    : null,
                hintStyle: const TextStyle(color: Colors.green),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _goalFatController,
              focusNode: _fatFocusNode,
              decoration: InputDecoration(
                labelText: '목표 지방 (g)',
                hintText: _fatFocusNode.hasFocus && _goalFatController.text.isEmpty && _recommendedFat != null
                    ? '권장: $_recommendedFat g'
                    : null,
                hintStyle: const TextStyle(color: Colors.green),
              ),
              keyboardType: TextInputType.number,
            ),


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
