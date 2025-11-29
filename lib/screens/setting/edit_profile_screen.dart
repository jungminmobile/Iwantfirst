import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- 컨트롤러 ---
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController(); // ★ 1. 나이 컨트롤러 추가
  final _targetCaloriesController = TextEditingController();
  final _targetCarbsController = TextEditingController();
  final _targetProteinController = TextEditingController();
  final _targetFatController = TextEditingController();

  // --- 포커스 노드 ---
  final _calorieFocusNode = FocusNode();
  final _carbsFocusNode = FocusNode();
  final _proteinFocusNode = FocusNode();
  final _fatFocusNode = FocusNode();

  // --- 상태 변수 ---
  String _selectedGender = '남성';
  String _selectedGoal = '유지';
  String _selectedActivity = '매우 비활동적'; // ★ 2. 활동량 상태 변수 추가
  bool _isLoading = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

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
    _loadUserData();

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

    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    _targetCaloriesController.dispose();
    _targetCarbsController.dispose();
    _targetProteinController.dispose();
    _targetFatController.dispose();

    _calorieFocusNode.dispose();
    _carbsFocusNode.dispose();
    _proteinFocusNode.dispose();
    _fatFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('profile')) {
          final profileData = data['profile'] as Map<String, dynamic>;
          _nameController.text = profileData['name'] ?? '';
          _heightController.text = (profileData['height'] as num?)?.toString() ?? '';
          _weightController.text = (profileData['weight'] as num?)?.toString() ?? '';
          _ageController.text = (profileData['age'] as num?)?.toString() ?? ''; // ★ 나이 불러오기
          _selectedGender = profileData['gender'] ?? '남성';
        }
        if (data.containsKey('goals')) {
          final goalsData = data['goals'] as Map<String, dynamic>;
          _targetCaloriesController.text = (goalsData['target_calories'] as num?)?.toString() ?? '';
          _targetCarbsController.text = (goalsData['target_carbs'] as num?)?.toString() ?? '';
          _targetProteinController.text = (goalsData['target_protein'] as num?)?.toString() ?? '';
          _targetFatController.text = (goalsData['target_fat'] as num?)?.toString() ?? '';
          _selectedGoal = goalsData['user_goal'] ?? '유지';
          _selectedActivity = goalsData['activity_level'] ?? '매우 비활동적'; // ★ 활동량 불러오기
        }
        _calculateRecommendations(); // 모든 데이터 로드 후 권장량 계산
      }
    } catch (e) {
      print("사용자 정보 로드 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    double finalKcal;
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

  // ★ 4. 저장 로직에 나이, 활동량 정보 업데이트 추가
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      // Map을 사용하여 업데이트할 데이터 구성 (점 표기법 대신)
      final Map<String, dynamic> updatedData = {
        'profile': {
          'name': _nameController.text.trim(),
          'height': double.tryParse(_heightController.text.trim()) ?? 0.0,
          'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
          'age': int.tryParse(_ageController.text.trim()) ?? 0, // 나이 저장
          'gender': _selectedGender,
        },
        'goals': {
          'target_calories': int.tryParse(_targetCaloriesController.text.trim()) ?? _recommendedCalories ?? 0,
          'target_carbs': int.tryParse(_targetCarbsController.text.trim()) ?? _recommendedCarbs ?? 0,
          'target_protein': int.tryParse(_targetProteinController.text.trim()) ?? _recommendedProtein ?? 0,
          'target_fat': int.tryParse(_targetFatController.text.trim()) ?? _recommendedFat ?? 0,
          'user_goal': _selectedGoal,
          'activity_level': _selectedActivity, // 활동량 저장
        },
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .set(updatedData, SetOptions(merge: true)); // set + merge: true => update와 동일 효과

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정보가 저장되었습니다.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("프로필 저장 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('프로필 수정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("기본 정보"),
              const SizedBox(height: 15),
              _buildSectionCard(children: [
                _buildTextField("이름", _nameController, icon: Icons.person_outline),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _buildTextField("키", _heightController, suffix: "cm", isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField("몸무게", _weightController, suffix: "kg", isNumber: true)),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _buildTextField("나이", _ageController, suffix: "세", isNumber: true)), // ★ 나이 필드 UI
                  const SizedBox(width: 15),
                  Expanded(child: SizedBox()),
                ]),
                const SizedBox(height: 20),
                _buildSubHeader("성별"),
                const SizedBox(height: 10),
                _buildGenderSelector(),
              ]),
              const SizedBox(height: 30),
              _buildSectionHeaderWithHint(), // 목표 설정 헤더
              const SizedBox(height: 15),
              _buildSectionCard(children: [
                _buildSubHeader("나의 활동량"), // ★ 활동량 섹션 UI
                const SizedBox(height: 10),
                _buildActivitySelector(),
                const SizedBox(height: 20),
                _buildSubHeader("나의 목표"),
                const SizedBox(height: 10),
                _buildGoalSelector(),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                _buildTextField("목표 칼로리", _targetCaloriesController, suffix: "kcal", isNumber: true, focusNode: _calorieFocusNode, placeholder: _recommendedCalories?.toString()),
                const SizedBox(height: 20),
                _buildTextField("목표 탄수화물", _targetCarbsController, suffix: "g", isNumber: true, focusNode: _carbsFocusNode, placeholder: _recommendedCarbs?.toString()),
                const SizedBox(height: 20),
                _buildTextField("목표 단백질", _targetProteinController, suffix: "g", isNumber: true, focusNode: _proteinFocusNode, placeholder: _recommendedProtein?.toString()),
                const SizedBox(height: 20),
                _buildTextField("목표 지방", _targetFatController, suffix: "g", isNumber: true, focusNode: _fatFocusNode, placeholder: _recommendedFat?.toString()),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("저장하기", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
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

  Widget _buildTextField(String label, TextEditingController controller, {String? suffix, bool isNumber = false, IconData? icon, FocusNode? focusNode, String? placeholder}) {
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
            errorStyle: TextStyle(color: Colors.redAccent[400]),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent[200]!, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent[400]!, width: 2.0)),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return '값을 입력해주세요.';
            if (isNumber && double.tryParse(v) == null) return '숫자만 입력해주세요.';
            return null;
          },
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

  // ★ 5. 활동량 선택 UI 빌더 추가
  Widget _buildActivitySelector() {
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
