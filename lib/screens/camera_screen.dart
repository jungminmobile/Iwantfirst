import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  final List<XFile> _breakfastImages = [];
  final List<XFile> _lunchImages = [];
  final List<XFile> _dinnerImages = [];
  final List<XFile> _snackImages = [];
  final List<String> _breakfastTexts = [];
  final List<String> _lunchTexts = [];
  final List<String> _dinnerTexts = [];
  final List<String> _snackTexts = [];

  @override
  void initState() {
    super.initState();
    // 앱이 죽었다가 살아났을 때, 잃어버린 데이터(사진)가 있는지 확인하는 함수 실행
    _retrieveLostData();
  }

  // 🟢 [중요] 안드로이드에서 앱이 종료되었을 때 사진 복구하는 함수
  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();

    if (response.isEmpty) {
      return;
    }

    final XFile? file = response.file;
    if (file != null) {
      setState(() {
        // 복구된 사진은 일단 '아침' 섹션에 넣거나,
        // (임시) 가장 최근에 작업하던 곳에 넣어야 하는데
        // 여기서는 예시로 '아침'에 추가해둡니다.
        // 실제로는 어떤 버튼을 눌렀었는지 저장하는 로직이 더 필요하지만,
        // 일단 사진이 날아가지 않게 하는 것이 우선입니다.
        _breakfastImages.add(file);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미지를 복구했습니다. (아침 섹션 확인)')),
      );
    } else {
      print('이미지 복구 실패: ${response.exception?.code}');
    }
  }

  Future<void> _pickImage(String mealType, ImageSource source) async {
    try {
      // 이미지 품질을 50%로 줄여서 메모리 부족 방지
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50, // 🟢 품질 압축
        maxWidth: 1024,   // 🟢 크기 제한
      );

      if (pickedFile != null) {
        setState(() {
          switch (mealType) {
            case '아침':
              _breakfastImages.add(pickedFile);
              break;
            case '점심':
              _lunchImages.add(pickedFile);
              break;
            case '저녁':
              _dinnerImages.add(pickedFile);
              break;
            case '간식':
              _snackImages.add(pickedFile);
              break;
          }
        });
      }
    } catch (e) {
      print('사진 선택 실패: $e');
    }
  }

  // 텍스트 입력 다이얼로그 표시 함수
  Future<void> _showTextInputDialog(String mealType) async {
    final TextEditingController textController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$mealType 텍스트 입력'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: '예: 현미밥 1공기, 사과 반 쪽',
              border: OutlineInputBorder(),
            ),
            maxLines: 3, // 여러 줄 입력 가능하게
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 취소
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  setState(() {
                    // 입력된 텍스트를 리스트에 추가
                    switch (mealType) {
                      case '아침':
                        _breakfastTexts.add(textController.text);
                        break;
                      case '점심':
                        _lunchTexts.add(textController.text);
                        break;
                      case '저녁':
                        _dinnerTexts.add(textController.text);
                        break;
                      case '간식':
                        _snackTexts.add(textController.text);
                        break;
                    }
                  });
                }
                Navigator.pop(context); // 다이얼로그 닫기
              },
              child: const Text('추가'),
            ),
          ],
        );
      },
    );
  }

  void _showAddOptions(BuildContext context, String mealType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 🟢 높이 유동적 조절
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        // 🟢 2.0 픽셀 오버플로우 해결을 위해 높이를 고정하지 않고 Wrap으로 감쌈
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40), // 하단 여백 넉넉히
          child: Column(
            mainAxisSize: MainAxisSize.min, // 내용물만큼만 높이 차지
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$mealType 추가하기',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildOptionTile(
                icon: Icons.camera_alt,
                text: '카메라로 촬영',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(mealType, ImageSource.camera);
                },
              ),
              _buildOptionTile(
                icon: Icons.photo_library,
                text: '이미지 업로드',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(mealType, ImageSource.gallery);
                },
              ),
              _buildOptionTile(
                icon: Icons.edit,
                text: '텍스트로 입력',
                onTap: () {
                  Navigator.pop(context);
                  _showTextInputDialog(mealType);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(text),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  void _onAnalyzePressed(String mealType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$mealType 분석을 시작합니다...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('식단 기록'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(          children: [
          // 👇 매개변수가 하나 더 늘었습니다 (텍스트 리스트 전달)
          _buildMealSection('아침', _breakfastImages, _breakfastTexts),
          const Divider(height: 1, thickness: 1),
          _buildMealSection('점심', _lunchImages, _lunchTexts),
          const Divider(height: 1, thickness: 1),
          _buildMealSection('저녁', _dinnerImages, _dinnerTexts),
          const Divider(height: 1, thickness: 1),
          _buildMealSection('간식', _snackImages, _snackTexts),
          const SizedBox(height: 50),
        ],
        ),
      ),
    );
  }

  // 👇 인자 추가: List<String> textItems
  Widget _buildMealSection(
      String title, List<XFile> images, List<String> textItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      // 내용이 많아질 수 있으니 minHeight 제거하거나 조절
      constraints: const BoxConstraints(minHeight: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => _showAddOptions(context, title),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 28,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. 아무것도 없을 때 안내 문구
          (images.isEmpty && textItems.isEmpty)
              ? Container(
            height: 60,
            alignment: Alignment.centerLeft,
            child: Text(
              '$title을 기록해 보세요.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. 이미지 리스트 표시 (있을 때만)
              if (images.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(File(images[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),

              if (images.isNotEmpty && textItems.isNotEmpty)
                const SizedBox(height: 10),

              // 3. 텍스트 리스트 표시 (있을 때만)
              if (textItems.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: textItems.map((text) {
                    return Chip(
                      label: Text(text),
                      backgroundColor: Colors.orange[50],
                      side: BorderSide.none,
                      onDeleted: () {
                        setState(() {
                          textItems.remove(text);
                        });
                      },
                    );
                  }).toList(),
                ),
            ],
          ),

          const SizedBox(height: 15),

          // 분석 버튼은 내용이 하나라도 있을 때만 보여주기
          if (images.isNotEmpty || textItems.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _onAnalyzePressed(title),
                icon: const Icon(Icons.analytics_outlined, size: 18),
                label: const Text('분석 시작'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[50],
                  foregroundColor: Colors.blue[700],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
