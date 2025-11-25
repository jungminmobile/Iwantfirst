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
  final _weightController = TextEditingController(); // ★ 1. 몸무게 컨트롤러 추가
  final _targetCaloriesController = TextEditingController();
  final _targetCarbsController = TextEditingController();
  final _targetProteinController = TextEditingController();
  final _targetFatController = TextEditingController();

  // --- 포커스 노드 (힌트 표시용) ---
  final _calorieFocusNode = FocusNode();
  final _carbsFocusNode = FocusNode();
  final _proteinFocusNode = FocusNode();
  final _fatFocusNode = FocusNode();

  String? _selectedGender;
  bool _isLoading = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // --- 권장 섭취량 저장 변수 ---
  int? _recommendedCalories;
  int? _recommendedCarbs;
  int? _recommendedProtein;
  int? _recommendedFat;

  @override
  void initState() {
    super.initState();
    // 1. 기존 사용자 데이터를 먼저 불러옵니다.
    _loadUserData();

    // ★ 2. 키, 몸무게, 포커스 노드에 리스너를 추가합니다.
    _heightController.addListener(_calculateRecommendations);
    _weightController.addListener(_calculateRecommendations);
    _calorieFocusNode.addListener(() => setState(() {}));
    _carbsFocusNode.addListener(() => setState(() {}));
    _proteinFocusNode.addListener(() => setState(() {}));
    _fatFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // 모든 컨트롤러와 FocusNode를 정리하여 메모리 누수를 방지합니다.
    _heightController.removeListener(_calculateRecommendations);
    _weightController.removeListener(_calculateRecommendations);
    _calorieFocusNode.removeListener(() => setState(() {}));
    _carbsFocusNode.removeListener(() => setState(() {}));
    _proteinFocusNode.removeListener(() => setState(() {}));
    _fatFocusNode.removeListener(() => setState(() {}));

    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
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

  // 데이터 로딩 함수 (몸무게 추가 및 권장량 계산 호출)
  Future<void> _loadUserData() async {
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data.containsKey('profile')) {
          final profileData = data['profile'] as Map<String, dynamic>;
          _nameController.text = profileData['name'] ?? '';
          _heightController.text = (profileData['height'] as num?)?.toString() ?? '';
          _weightController.text = (profileData['weight'] as num?)?.toString() ?? ''; // 몸무게 로드
          _selectedGender = profileData['gender'];
        }
        if (data.containsKey('goals')) {
          final goalsData = data['goals'] as Map<String, dynamic>;
          _targetCaloriesController.text = (goalsData['target_calories'] as num?)?.toString() ?? '';
          _targetCarbsController.text = (goalsData['target_carbs'] as num?)?.toString() ?? '';
          _targetProteinController.text = (goalsData['target_protein'] as num?)?.toString() ?? '';
          _targetFatController.text = (goalsData['target_fat'] as num?)?.toString() ?? '';
        }
        // ★ 데이터를 모두 로드한 후, 현재 값으로 권장량을 한번 계산합니다.
        _calculateRecommendations();
      }
    } catch (e) {
      print("사용자 정보 로드 오류: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ★ 3. 표준 권장 섭취량 계산 함수
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

  // ★ 4. 저장 함수 수정 (권장량 자동 저장)
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'profile.name': _nameController.text.trim(),
        'profile.height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'profile.weight': double.tryParse(_weightController.text.trim()) ?? 0.0, // 몸무게 저장
        'profile.gender': _selectedGender,
        'goals.target_calories': int.tryParse(_targetCaloriesController.text.trim()) ?? _recommendedCalories ?? 0,
        'goals.target_carbs': int.tryParse(_targetCarbsController.text.trim()) ?? _recommendedCarbs ?? 0,
        'goals.target_protein': int.tryParse(_targetProteinController.text.trim()) ?? _recommendedProtein ?? 0,
        'goals.target_fat': int.tryParse(_targetFatController.text.trim()) ?? _recommendedFat ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('정보가 성공적으로 수정되었습니다.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("프로필 저장 오류: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류가 발생했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 및 목표 설정')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("프로필 정보", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해주세요.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _heightController,
                decoration: const InputDecoration(labelText: '키 (cm)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return '키를 입력해주세요.';
                  if (double.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // ★ 5. 몸무게 입력 필드 추가
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: '몸무게 (kg)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return '몸무게를 입력해주세요.';
                  if (double.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: '성별', border: OutlineInputBorder()),
                items: ['남성', '여성'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _selectedGender = v);
                    _calculateRecommendations(); // 성별 변경 시에도 재계산
                  }
                },
                validator: (v) => v == null ? '성별을 선택해주세요.' : null,
              ),
              const SizedBox(height: 32),

              const Text("목표 설정", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // ★ 6. 목표 설정 UI 수정 (힌트 기능 적용)
              TextFormField(
                controller: _targetCaloriesController,
                focusNode: _calorieFocusNode,
                decoration: InputDecoration(
                  labelText: '목표 칼로리 (kcal)',
                  border: const OutlineInputBorder(),
                  hintText: _calorieFocusNode.hasFocus && _targetCaloriesController.text.isEmpty && _recommendedCalories != null
                      ? '권장: $_recommendedCalories kcal'
                      : null,
                  hintStyle: const TextStyle(color: Colors.green),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetCarbsController,
                focusNode: _carbsFocusNode,
                decoration: InputDecoration(
                  labelText: '목표 탄수화물 (g)',
                  border: const OutlineInputBorder(),
                  hintText: _carbsFocusNode.hasFocus && _targetCarbsController.text.isEmpty && _recommendedCarbs != null
                      ? '권장: $_recommendedCarbs g'
                      : null,
                  hintStyle: const TextStyle(color: Colors.green),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetProteinController,
                focusNode: _proteinFocusNode,
                decoration: InputDecoration(
                  labelText: '목표 단백질 (g)',
                  border: const OutlineInputBorder(),
                  hintText: _proteinFocusNode.hasFocus && _targetProteinController.text.isEmpty && _recommendedProtein != null
                      ? '권장: $_recommendedProtein g'
                      : null,
                  hintStyle: const TextStyle(color: Colors.green),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetFatController,
                focusNode: _fatFocusNode,
                decoration: InputDecoration(
                  labelText: '목표 지방 (g)',
                  border: const OutlineInputBorder(),
                  hintText: _fatFocusNode.hasFocus && _targetFatController.text.isEmpty && _recommendedFat != null
                      ? '권장: $_recommendedFat g'
                      : null,
                  hintStyle: const TextStyle(color: Colors.green),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v != null && v.isNotEmpty && int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
