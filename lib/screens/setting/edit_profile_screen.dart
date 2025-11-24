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

  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  String? _selectedGender;

  bool _isLoading = true;
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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

      if (doc.exists && doc.data()!.containsKey('profile')) {
        final profileData = doc.data()!['profile'] as Map<String, dynamic>;

        _nameController.text = profileData['name'] ?? '';
        // Firestore에서 number 타입으로 저장된 height를 문자열로 변환
        _heightController.text = (profileData['height'] as num?)?.toString() ?? '';
        _selectedGender = profileData['gender'];
      }
    } catch (e) {
      print("사용자 정보 로드 오류: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || currentUser == null) {
      return;
    }
    setState(() { _isLoading = true; });

    try {
      // ▼▼▼ [수정됨] 키(height)를 double 타입으로 파싱하여 저장 ▼▼▼
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .update({
        'profile.name': _nameController.text.trim(),
        'profile.height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'profile.gender': _selectedGender,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원정보가 성공적으로 수정되었습니다.')),
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
      appBar: AppBar(title: const Text('회원정보 수정')),
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

                // ▼▼▼ [수정됨] 키보드 타입을 소수점 포함 숫자로 변경 ▼▼▼
                TextFormField(
                  controller: _heightController,
                  // 소수점 입력을 위해 키보드 타입 변경
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: '키 (cm)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '키를 입력해주세요.';
                    }
                    // double 파싱이 실패하면 오류 메시지 표시
                    if (double.tryParse(value) == null) {
                      return '숫자 또는 소수점만 입력해주세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

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
    super.dispose();
  }
}
