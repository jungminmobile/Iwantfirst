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

  // --- 1. 컨트롤러 추가 ---
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _targetCaloriesController = TextEditingController();
  // ★★★ 목표 탄/단/지 컨트롤러 추가 ★★★
  final _targetCarbsController = TextEditingController();
  final _targetProteinController = TextEditingController();
  final _targetFatController = TextEditingController();

  String? _selectedGender;
  bool _isLoading = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- 2. 데이터 로딩 함수 수정 ---
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
          _selectedGender = profileData['gender'];
        }

        // ★★★ goals 데이터 로드 로직 수정 ★★★
        if (data.containsKey('goals')) {
          final goalsData = data['goals'] as Map<String, dynamic>;
          _targetCaloriesController.text = (goalsData['target_calories'] as num?)?.toString() ?? '';
          _targetCarbsController.text = (goalsData['target_carbs'] as num?)?.toString() ?? '';
          _targetProteinController.text = (goalsData['target_protein'] as num?)?.toString() ?? '';
          _targetFatController.text = (goalsData['target_fat'] as num?)?.toString() ?? '';
        }
      }
    } catch (e) {
      print("사용자 정보 로드 오류: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- 4. 저장 함수 수정 ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || currentUser == null) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      // ★★★ profile과 모든 goals 필드를 함께 업데이트 ★★★
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'profile.name': _nameController.text.trim(),
        'profile.height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'profile.gender': _selectedGender,
        'goals.target_calories': int.tryParse(_targetCaloriesController.text.trim()) ?? 0,
        'goals.target_carbs': int.tryParse(_targetCarbsController.text.trim()) ?? 0,
        'goals.target_protein': int.tryParse(_targetProteinController.text.trim()) ?? 0,
        'goals.target_fat': int.tryParse(_targetFatController.text.trim()) ?? 0,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('정보가 성공적으로 수정되었습니다.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("프로필 저장 오류: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '키 (cm)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '키를 입력해주세요.';
                  if (double.tryParse(v) == null) return '숫자 또는 소수점만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(labelText: '성별', border: OutlineInputBorder()),
                items: ['남성', '여성'].map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) => setState(() => _selectedGender = v),
                validator: (v) => v == null ? '성별을 선택해주세요.' : null,
              ),
              const SizedBox(height: 32),

              // --- 3. UI 변경 ---
              const Text("목표 설정", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _targetCaloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '목표 칼로리 (kcal)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '목표 칼로리를 입력해주세요.';
                  if (int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              // ★★★ 탄/단/지 입력 필드 추가 ★★★
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetCarbsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '목표 탄수화물 (g)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '목표 탄수화물을 입력해주세요.';
                  if (int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetProteinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '목표 단백질 (g)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '목표 단백질을 입력해주세요.';
                  if (int.tryParse(v) == null) return '숫자만 입력해주세요.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetFatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '목표 지방 (g)', border: OutlineInputBorder()),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '목표 지방을 입력해주세요.';
                  if (int.tryParse(v) == null) return '숫자만 입력해주세요.';
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

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _targetCaloriesController.dispose();
    // ★★★ 추가된 컨트롤러들도 dispose 해줘야 합니다 ★★★
    _targetCarbsController.dispose();
    _targetProteinController.dispose();
    _targetFatController.dispose();
    super.dispose();
  }
}
