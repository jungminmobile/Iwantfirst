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
  final _weightController = TextEditingController();
  final _ageController = TextEditingController(); // ★ 1. 나이 컨트롤러 추가
  final _goalCalorieController = TextEditingController();
  final _goalCarbsController = TextEditingController();
  final _goalProteinController = TextEditingController();
  final _goalFatController = TextEditingController();

  // --- 포커스 노드 (힌트 표시용) ---
  final _calorieFocusNode = FocusNode();
  final _carbsFocusNode = FocusNode();
  final _proteinFocusNode = FocusNode();
  final _fatFocusNode = FocusNode();

  // --- 상태 변수 ---
  String _selectedGender = '남성';
  String _selectedGoal = '유지';
  String _selectedActivity = '매우 비활동적'; // ★ 2. 활동량 상태 변수 추가
  bool _isLoading = false;

  // --- 권장 섭취량 저장 변수 ---
  int? _recommendedCalories;
  int? _recommendedCarbs;
  int? _recommendedProtein;
  int? _recommendedFat;

  // 🎨 디자인용 색상
  final Color _primaryColor = const Color(0xFF33FF00);
  final Color _backgroundColor = const Color(0xFFF5F5F5);

  // ★ 활동량 계수 맵
  final Map<String, double> _activityFactors = {
    '매우 비활동적': 1.2,
    '가벼운 활동': 1.375,
    '중간 활동': 1.55,
    '고활동': 1.725,
    '매우 고활동': 1.9,
  };

  @override
  void initState() {
    super.initState();
    // 사용자 입력이 변경될 때마다 계산 함수 호출
    _heightController.addListener(_calculateRecommendations);
    _weightController.addListener(_calculateRecommendations);
    _ageController.addListener(_calculateRecommendations);

    _calorieFocusNode.addListener(() => setState(() {}));
    _carbsFocusNode.addListener(() => setState(() {}));
    _proteinFocusNode.addListener(() => setState(() {}));
    _fatFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // 모든 컨트롤러와 포커스 노드 해제
    _heightController.removeListener(_calculateRecommendations);
    _weightController.removeListener(_calculateRecommendations);
    _ageController.removeListener(_calculateRecommendations);

    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
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

  // ★ 3. 제공된 새 공식으로 권장 섭취량 계산 함수 전면 수정
  void _calculateRecommendations() {
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);
    final int? age = int.tryParse(_ageController.text);
    final double activityFactor = _activityFactors[_selectedActivity]!;

    if (height == null || height <= 0 || weight == null || weight <= 0 || age == null || age <= 0) {
      setState(() {
        _recommendedCalories = null;
        _recommendedCarbs = null;
        _recommendedProtein = null;
        _recommendedFat = null;
      });
      return;
    }

    // 1. BMR 및 TDEE 계산 (해리스-베네딕트 수정 공식)
    double bmr;
    if (_selectedGender == '남성') {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    } else {
      bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161; // 여성 공식
    }
    double tdee = bmr * activityFactor;

    // 2. 목표에 따라 최종 칼로리 및 영양소 계산
    double finalKcal = tdee;
    double proteinG, carbG, fatG;
    double fatRatio;

    if (_selectedGoal == '유지') {
      finalKcal = tdee;
      proteinG = weight * 1.1;
      fatRatio = 0.25;
    } else if (_selectedGoal == '체중 감소') {
      finalKcal = tdee - 300;
      proteinG = weight * 1.3;
      fatRatio = 0.25;
    } else { // 근육량 증가
      finalKcal = tdee + 200;
      proteinG = weight * 1.5;
      fatRatio = 0.20;
    }

    fatG = (finalKcal * fatRatio) / 9;
    double carbKcal = finalKcal - (proteinG * 4) - (fatG * 9);
    carbG = carbKcal / 4;

    setState(() {
      _recommendedCalories = finalKcal.round();
      _recommendedCarbs = carbG.round();
      _recommendedProtein = proteinG.round();
      _recommendedFat = fatG.round();
    });
  }

  // ★ 4. 가입 로직에 나이, 활동량 정보 저장 추가
  Future<void> _signUp() async {
    // 유효성 검사 추가 (이름, 키, 몸무게, 나이)
    final name = _nameController.text.trim();
    final height = _heightController.text.trim();
    final weight = _weightController.text.trim();
    final age = _ageController.text.trim();

    if (name.isEmpty || height.isEmpty || weight.isEmpty || age.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필 정보(이름, 키, 몸무게, 나이)를 모두 입력해주세요.')));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim());
      final String uid = userCredential.user!.uid;

      await _firestore.collection(_userCollectionPath).doc(uid).set({
        'account_info': {
          'email': _emailController.text.trim(),
          'created_at': FieldValue.serverTimestamp(),
        },
        'profile': {
          'name': name,
          'height': double.tryParse(height) ?? 0.0,
          'weight': double.tryParse(weight) ?? 0.0,
          'age': int.tryParse(age) ?? 0,
          'gender': _selectedGender,
        },
        'goals': {
          'target_calories': int.tryParse(_goalCalorieController.text.trim()) ?? _recommendedCalories ?? 2000,
          'target_carbs': int.tryParse(_goalCarbsController.text.trim()) ?? _recommendedCarbs ?? 0,
          'target_protein': int.tryParse(_goalProteinController.text.trim()) ?? _recommendedProtein ?? 0,
          'target_fat': int.tryParse(_goalFatController.text.trim()) ?? _recommendedFat ?? 0,
          'user_goal': _selectedGoal,
          'activity_level': _selectedActivity, // 활동량 저장
        },
      });

      await _auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원가입 성공! 이제 로그인하세요.')));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('회원가입 에러: ${e.message}')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('알 수 없는 에러: $e')));
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('회원가입', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader("계정 정보"),
            const SizedBox(height: 15),
            _buildSectionCard(children: [
              _buildTextField("이메일", _emailController, icon: Icons.email_outlined),
              const SizedBox(height: 20),
              _buildTextField("비밀번호 (6자 이상)", _passwordController, icon: Icons.lock_outline, obscureText: true),
            ]),

            const SizedBox(height: 30),

            _buildSectionHeader("프로필 정보"),
            const SizedBox(height: 15),
            _buildSectionCard(children: [
              _buildTextField("이름/닉네임", _nameController, icon: Icons.person_outline),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _buildTextField("키", _heightController, suffix: "cm", isNumber: true)),
                const SizedBox(width: 15),
                Expanded(child: _buildTextField("몸무게", _weightController, suffix: "kg", isNumber: true)),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _buildTextField("나이", _ageController, suffix: "세", isNumber: true)), // ★ 나이 필드 추가
                const SizedBox(width: 15),
                Expanded(child: SizedBox()), // 공간 채우기
              ]),
              const SizedBox(height: 20),
              _buildSubHeader("성별"),
              const SizedBox(height: 10),
              _buildGenderSelector(),
            ]),

            const SizedBox(height: 30),

            _buildSectionHeaderWithHint(),
            const SizedBox(height: 15),
            _buildSectionCard(children: [
              _buildSubHeader("나의 활동량"), // ★ 활동량 섹션 추가
              const SizedBox(height: 10),
              _buildActivitySelector(),
              const SizedBox(height: 20),
              _buildSubHeader("나의 목표"),
              const SizedBox(height: 10),
              _buildGoalSelector(),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              _buildTextField("목표 칼로리", _goalCalorieController, suffix: "kcal", isNumber: true, focusNode: _calorieFocusNode, placeholder: _recommendedCalories?.toString()),
              const SizedBox(height: 20),
              _buildTextField("목표 탄수화물", _goalCarbsController, suffix: "g", isNumber: true, focusNode: _carbsFocusNode, placeholder: _recommendedCarbs?.toString()),
              const SizedBox(height: 20),
              _buildTextField("목표 단백질", _goalProteinController, suffix: "g", isNumber: true, focusNode: _proteinFocusNode, placeholder: _recommendedProtein?.toString()),
              const SizedBox(height: 20),
              _buildTextField("목표 지방", _goalFatController, suffix: "g", isNumber: true, focusNode: _fatFocusNode, placeholder: _recommendedFat?.toString()),
            ]),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signUp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("가입 완료 및 프로필 저장", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- 위젯 빌더 함수들 ---

  Widget _buildSectionHeader(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildSubHeader(String title) => Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold));

  Widget _buildSectionHeaderWithHint() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionHeader("목표 설정"),
        if (_recommendedCalories != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _primaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text("권장: $_recommendedCalories kcal", style: TextStyle(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? suffix, bool isNumber = false, IconData? icon, bool obscureText = false, FocusNode? focusNode, String? placeholder}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSubHeader(label),
            if (placeholder != null && controller.text.isEmpty && focusNode != null && focusNode.hasFocus)
              Text("권장: $placeholder", style: TextStyle(fontSize: 12, color: Colors.green[700])),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          obscureText: obscureText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            prefixIcon: icon != null ? Icon(icon, color: Colors.grey[600]) : null,
            suffixText: suffix,
            suffixStyle: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        Expanded(child: _buildGenderButton('남성')),
        const SizedBox(width: 15),
        Expanded(child: _buildGenderButton('여성')),
      ],
    );
  }

  Widget _buildGenderButton(String gender) {
    bool isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGender = gender);
        _calculateRecommendations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text(gender, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  // ★ 5. 목표 선택 UI 빌더
  Widget _buildGoalSelector() {
    return Row(
      children: [
        Expanded(child: _buildGoalButton('유지')),
        const SizedBox(width: 10),
        Expanded(child: _buildGoalButton('체중 감소')),
        const SizedBox(width: 10),
        Expanded(child: _buildGoalButton('근육량 증가')),
      ],
    );
  }

  Widget _buildGoalButton(String goal) {
    bool isSelected = _selectedGoal == goal;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedGoal = goal);
        _calculateRecommendations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text(goal, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  // ★ 6. 활동량 선택 UI 빌더
  Widget _buildActivitySelector() {
    // 사용자가 이해하기 쉬운 텍스트 맵
    final Map<String, String> activityDescriptions = {
      '매우 비활동적': '운동 거의 안함',
      '가벼운 활동': '주 1-3회 운동',
      '중간 활동': '주 3-5회 운동',
      '고활동': '주 6-7회 운동',
      '매우 고활동': '매일, 하루 2번',
    };

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildActivityButton('매우 비활동적', activityDescriptions['매우 비활동적']!)),
            const SizedBox(width: 10),
            Expanded(child: _buildActivityButton('가벼운 활동', activityDescriptions['가벼운 활동']!)),
            const SizedBox(width: 10),
            Expanded(child: _buildActivityButton('중간 활동', activityDescriptions['중간 활동']!)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildActivityButton('고활동', activityDescriptions['고활동']!)),
            const SizedBox(width: 10),
            Expanded(child: _buildActivityButton('매우 고활동', activityDescriptions['매우 고활동']!)),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityButton(String activityLevel, String description) {
    bool isSelected = _selectedActivity == activityLevel;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedActivity = activityLevel);
        _calculateRecommendations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
        child: Text(description, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
      ),
    );
  }
}
