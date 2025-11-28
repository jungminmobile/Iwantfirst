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

  // 🎨 디자인용 색상 (앱 테마와 통일)
  final Color _primaryColor = const Color(0xFF33FF00); // 형광 연두
  final Color _backgroundColor = const Color(0xFFF5F5F5); // 연한 회색 배경

  @override
  void initState() {
    super.initState();
    // 키, 몸무게 값이 변경될 때마다 계산 함수 호출
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

  // 표준 권장 섭취량 계산 함수
  void _calculateRecommendations() {
    final double? height = double.tryParse(_heightController.text);
    final double? weight = double.tryParse(_weightController.text);

    if (height == null || height <= 0 || weight == null || weight <= 0) {
      setState(() {
        _recommendedCalories = null;
        _recommendedCarbs = null;
        _recommendedProtein = null;
        _recommendedFat = null;
      });
      return;
    }

    double bmr;
    if (_selectedGender == '남성') {
      bmr = (66.47 + (13.75 * weight) + (5 * height) - (6.76 * 30)) * 1.2;
    } else {
      bmr = (655.1 + (9.56 * weight) + (1.85 * height) - (4.68 * 30)) * 1.2;
    }

    setState(() {
      _recommendedCalories = bmr.round();
      _recommendedCarbs = ((_recommendedCalories! * 0.5) / 4).round();
      _recommendedProtein = ((_recommendedCalories! * 0.3) / 4).round();
      _recommendedFat = ((_recommendedCalories! * 0.2) / 9).round();
    });
  }

  // 가입 로직
  Future<void> _signUp() async {
    setState(() {
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력해주세요.')));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 1. 계정 생성
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);
      final String uid = userCredential.user!.uid;

      // 2. 데이터베이스에 정보 저장
      await _firestore.collection(_userCollectionPath).doc(uid).set({
        'account_info': {
          'email': email,
          'created_at': FieldValue.serverTimestamp(),
        },
        'profile': {
          'name': _nameController.text.trim(),
          'height': double.tryParse(_heightController.text) ?? 0.0,
          'weight': double.tryParse(_weightController.text) ?? 0.0,
          'gender': _selectedGender,
        },
        'goals': {
          'target_calories':
              int.tryParse(_goalCalorieController.text.trim()) ??
              _recommendedCalories ??
              2000,
          'target_carbs':
              int.tryParse(_goalCarbsController.text.trim()) ??
              _recommendedCarbs ??
              0,
          'target_protein':
              int.tryParse(_goalProteinController.text.trim()) ??
              _recommendedProtein ??
              0,
          'target_fat':
              int.tryParse(_goalFatController.text.trim()) ??
              _recommendedFat ??
              0,
        },
      });

      // 3. 화면 전환 충돌 방지를 위해 즉시 로그아웃
      await _auth.signOut();

      // 4. 로그인 페이지로 돌아가기
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('회원가입 성공! 이제 로그인하세요.')));
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('회원가입 에러: ${e.message}')));
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('알 수 없는 에러: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor, // 배경색 통일
      appBar: AppBar(
        title: const Text(
          '회원가입',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black), // 뒤로가기 아이콘 검정색
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 계정 정보 섹션
                  const Text(
                    "계정 정보",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildSectionCard(
                    children: [
                      _buildTextField(
                        "이메일",
                        _emailController,
                        icon: Icons.email_outlined,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "비밀번호 (6자 이상)",
                        _passwordController,
                        icon: Icons.lock_outline,
                        obscureText: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 2. 프로필 정보 섹션
                  const Text(
                    "프로필 정보",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  _buildSectionCard(
                    children: [
                      _buildTextField(
                        "이름/닉네임",
                        _nameController,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              "키",
                              _heightController,
                              suffix: "cm",
                              isNumber: true,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildTextField(
                              "몸무게",
                              _weightController,
                              suffix: "kg",
                              isNumber: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "성별",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildGenderSelector(),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 3. 목표 설정 섹션
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "목표 설정",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_recommendedCalories != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "권장: $_recommendedCalories kcal",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildSectionCard(
                    children: [
                      _buildTextField(
                        "목표 칼로리",
                        _goalCalorieController,
                        suffix: "kcal",
                        isNumber: true,
                        focusNode: _calorieFocusNode,
                        placeholder: _recommendedCalories?.toString(),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "목표 탄수화물",
                        _goalCarbsController,
                        suffix: "g",
                        isNumber: true,
                        focusNode: _carbsFocusNode,
                        placeholder: _recommendedCarbs?.toString(),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "목표 단백질",
                        _goalProteinController,
                        suffix: "g",
                        isNumber: true,
                        focusNode: _proteinFocusNode,
                        placeholder: _recommendedProtein?.toString(),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        "목표 지방",
                        _goalFatController,
                        suffix: "g",
                        isNumber: true,
                        focusNode: _fatFocusNode,
                        placeholder: _recommendedFat?.toString(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // 가입 완료 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black, // 버튼 검은색 (형광색과 대비)
                        foregroundColor: Colors.white, // 글씨 흰색
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "가입 완료 및 프로필 저장",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // 📦 흰색 카드 위젯
  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ⌨️ 커스텀 텍스트 필드 (트렌디한 스타일)
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? suffix,
    bool isNumber = false,
    IconData? icon,
    bool obscureText = false,
    FocusNode? focusNode,
    String? placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (placeholder != null &&
                controller.text.isEmpty &&
                focusNode != null &&
                focusNode.hasFocus)
              Text(
                "권장: $placeholder",
                style: TextStyle(fontSize: 12, color: Colors.green[700]),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: isNumber
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          obscureText: obscureText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100], // 연한 회색 배경
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.grey[600])
                : null,
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none, // 테두리 없애기
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 1.5,
              ), // 포커스 시 검은색 테두리
            ),
          ),
        ),
      ],
    );
  }

  // 🚻 성별 선택 토글 버튼
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
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black
              : Colors.grey[100], // 선택되면 검정, 아니면 회색
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Text(
          gender,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
