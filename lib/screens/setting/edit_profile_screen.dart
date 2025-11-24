import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});@override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // 컨트롤러 추가
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _targetCaloriesController = TextEditingController(); // 목표 칼로리 컨트롤러
  String? _selectedGender;

  bool _isLoading = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 데이터 로딩 함수 수정
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
        // profile 데이터 로드
        if (data.containsKey('profile')) {
          final profileData = data['profile'] as Map<String, dynamic>;
          _nameController.text = profileData['name'] ?? '';
          _heightController.text = (profileData['height'] as num?)?.toString() ?? '';
          _selectedGender = profileData['gender'];
        }
        // goals 데이터 로드
        if (data.containsKey('goals')) {
          final goalsData = data['goals'] as Map<String, dynamic>;
          _targetCaloriesController.text = (goalsData['target_calories'] as num?)?.toString() ?? '';
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

  // 저장 함수 수정
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || currentUser == null) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      // profile과 goals 필드를 모두 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'profile.name': _nameController.text.trim(),
        'profile.height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'profile.gender': _selectedGender,
        'goals.target_calories': int.tryParse(_targetCaloriesController.text.trim()) ?? 0,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 이름 입력 필드 (생략되지 않은 전체 코드)
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '이름',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 키 입력 필드 (생략되지 않은 전체 코드)
                TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '키 (cm)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '키를 입력해주세요.';
                    }
                    if (double.tryParse(value) == null) {
                      return '숫자 또는 소수점만 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ▼▼▼ [오류 수정] DropdownButtonFormField의 전체 코드를 복원 ▼▼▼
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: '성별',
                    border: OutlineInputBorder(),
                  ),
                  items: ['남성', '여성']
                      .map((label) => DropdownMenuItem(
                    value: label,
                    child: Text(label),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return '성별을 선택해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 목표 칼로리 입력 필드
                TextFormField(
                  controller: _targetCaloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '목표 칼로리 (kcal)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '목표 칼로리를 입력해주세요.';
                    }
                    if (int.tryParse(value) == null) {
                      return '숫자만 입력해주세요.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),
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
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _targetCaloriesController.dispose();
    super.dispose();
  }
}
