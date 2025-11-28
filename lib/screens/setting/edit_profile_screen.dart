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
  final _targetCaloriesController = TextEditingController();
  final _targetCarbsController = TextEditingController();
  final _targetProteinController = TextEditingController();
  final _targetFatController = TextEditingController();

  // --- 포커스 노드 ---
  final _calorieFocusNode = FocusNode();
  final _carbsFocusNode = FocusNode();
  final _proteinFocusNode = FocusNode();
  final _fatFocusNode = FocusNode();

  String _selectedGender = '남성'; // 기본값 설정
  bool _isLoading = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

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
    _loadUserData();

    _heightController.addListener(_calculateRecommendations);
    _weightController.addListener(_calculateRecommendations);
    _calorieFocusNode.addListener(() => setState(() {}));
    _carbsFocusNode.addListener(() => setState(() {}));
    _proteinFocusNode.addListener(() => setState(() {}));
    _fatFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _heightController.removeListener(_calculateRecommendations);
    _weightController.removeListener(_calculateRecommendations);
    _calorieFocusNode.dispose();
    _carbsFocusNode.dispose();
    _proteinFocusNode.dispose();
    _fatFocusNode.dispose();

    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetCaloriesController.dispose();
    _targetCarbsController.dispose();
    _targetProteinController.dispose();
    _targetFatController.dispose();
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
          _heightController.text =
              (profileData['height'] as num?)?.toString() ?? '';
          _weightController.text =
              (profileData['weight'] as num?)?.toString() ?? '';
          _selectedGender = profileData['gender'] ?? '남성';
        }
        if (data.containsKey('goals')) {
          final goalsData = data['goals'] as Map<String, dynamic>;
          _targetCaloriesController.text =
              (goalsData['target_calories'] as num?)?.toString() ?? '';
          _targetCarbsController.text =
              (goalsData['target_carbs'] as num?)?.toString() ?? '';
          _targetProteinController.text =
              (goalsData['target_protein'] as num?)?.toString() ?? '';
          _targetFatController.text =
              (goalsData['target_fat'] as num?)?.toString() ?? '';
        }
        _calculateRecommendations();
      }
    } catch (e) {
      print("사용자 정보 로드 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
            'profile.name': _nameController.text.trim(),
            'profile.height':
                double.tryParse(_heightController.text.trim()) ?? 0.0,
            'profile.weight':
                double.tryParse(_weightController.text.trim()) ?? 0.0,
            'profile.gender': _selectedGender,
            'goals.target_calories':
                int.tryParse(_targetCaloriesController.text.trim()) ??
                _recommendedCalories ??
                0,
            'goals.target_carbs':
                int.tryParse(_targetCarbsController.text.trim()) ??
                _recommendedCarbs ??
                0,
            'goals.target_protein':
                int.tryParse(_targetProteinController.text.trim()) ??
                _recommendedProtein ??
                0,
            'goals.target_fat':
                int.tryParse(_targetFatController.text.trim()) ??
                _recommendedFat ??
                0,
          });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('정보가 저장되었습니다.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("프로필 저장 오류: $e");
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text(
          '프로필 수정',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
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
                    // 1. 프로필 정보 섹션
                    const Text(
                      "기본 정보",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildSectionCard(
                      children: [
                        _buildTextField(
                          "이름",
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

                    // 2. 목표 설정 섹션
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
                          _targetCaloriesController,
                          suffix: "kcal",
                          isNumber: true,
                          focusNode: _calorieFocusNode,
                          placeholder: _recommendedCalories?.toString(),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          "목표 탄수화물",
                          _targetCarbsController,
                          suffix: "g",
                          isNumber: true,
                          focusNode: _carbsFocusNode,
                          placeholder: _recommendedCarbs?.toString(),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          "목표 단백질",
                          _targetProteinController,
                          suffix: "g",
                          isNumber: true,
                          focusNode: _proteinFocusNode,
                          placeholder: _recommendedProtein?.toString(),
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          "목표 지방",
                          _targetFatController,
                          suffix: "g",
                          isNumber: true,
                          focusNode: _fatFocusNode,
                          placeholder: _recommendedFat?.toString(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // 저장 버튼
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black, // 버튼 검은색 (형광색과 대비)
                          foregroundColor: Colors.white, // 글씨 흰색
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "저장하기",
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
            // 힌트가 있고, 입력값이 없을 때 우측 상단에 추천값 표시
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
          validator: (v) => (v == null || v.isEmpty) ? '입력해주세요' : null,
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
