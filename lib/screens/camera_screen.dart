import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'edit_food_screen.dart';
import '../services/gemini_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  // 🟢 [추가] 로딩 상태 변수 (분석 중일 때 true)
  bool _isAnalyzing = false;

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
    _retrieveLostData();
  }

  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;
    final XFile? file = response.file;
    if (file != null) {
      setState(() {
        _breakfastImages.add(file);
      });
    }
  }

  Future<void> _pickImage(String mealType, ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1024,
      );
      if (pickedFile != null) {
        setState(() {
          switch (mealType) {
            case '아침': _breakfastImages.add(pickedFile); break;
            case '점심': _lunchImages.add(pickedFile); break;
            case '저녁': _dinnerImages.add(pickedFile); break;
            case '간식': _snackImages.add(pickedFile); break;
          }
        });
      }
    } catch (e) {
      print('사진 선택 실패: $e');
    }
  }

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
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  setState(() {
                    switch (mealType) {
                      case '아침': _breakfastTexts.add(textController.text); break;
                      case '점심': _lunchTexts.add(textController.text); break;
                      case '저녁': _dinnerTexts.add(textController.text); break;
                      case '간식': _snackTexts.add(textController.text); break;
                    }
                  });
                }
                Navigator.pop(context);
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$mealType 추가하기', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  onTap: () { Navigator.pop(context); _pickImage(mealType, ImageSource.camera); }
              ),
              _buildOptionTile(
                  icon: Icons.photo_library,
                  text: '이미지 업로드',
                  onTap: () { Navigator.pop(context); _pickImage(mealType, ImageSource.gallery); }
              ),
              _buildOptionTile(
                  icon: Icons.edit,
                  text: '텍스트로 입력',
                  onTap: () { Navigator.pop(context); _showTextInputDialog(mealType); }
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({required IconData icon, required String text, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[700]),
      title: Text(text),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  // 🟢 [수정됨] 실제 API 호출 및 화면 이동 로직 구현
  void _onAnalyzePressed(String mealType) async {
    // 1. 해당 끼니의 데이터 가져오기
    List<XFile> targetImages = [];
    List<String> targetTexts = [];

    switch (mealType) {
      case '아침': targetImages = _breakfastImages; targetTexts = _breakfastTexts; break;
      case '점심': targetImages = _lunchImages; targetTexts = _lunchTexts; break;
      case '저녁': targetImages = _dinnerImages; targetTexts = _dinnerTexts; break;
      case '간식': targetImages = _snackImages; targetTexts = _snackTexts; break;
    }

    // 데이터 없으면 중단
    if (targetImages.isEmpty && targetTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('분석할 사진이나 텍스트가 없습니다.')),
      );
      return;
    }

    // 2. 로딩 시작
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final gemini = GeminiService();

      // 3. 1단계 분석 요청 (이름과 양 추정)
      final foodList = await gemini.identifyFoodList(targetImages, targetTexts);

      // 로딩 종료 (화면 이동 전)
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }

      if (foodList != null) {
        // 4. 성공 시 EditFoodScreen으로 이동
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            // 받아온 리스트를 다음 화면으로 넘겨줌
            builder: (context) => EditFoodScreen(initialFoods: foodList, mealType: mealType,),
          ),
        );
      } else {
        throw Exception('음식을 식별하지 못했습니다.');
      }
    } catch (e) {
      // 에러 처리
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🟢 [수정됨] Stack을 사용하여 로딩 화면을 덮어씌움
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('식단 기록'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
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
        ),

        // 🟢 [추가됨] 로딩 인디케이터 오버레이
        if (_isAnalyzing)
          Container(
            color: Colors.black.withOpacity(0.5), // 반투명 검은 배경
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text(
                    'AI가 음식을 확인하고 있어요...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMealSection(String title, List<XFile> images, List<String> textItems) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                onPressed: () => _showAddOptions(context, title),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 28,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),

          (images.isEmpty && textItems.isEmpty)
              ? Container(
            height: 60,
            alignment: Alignment.centerLeft,
            child: Text('$title을 기록해 보세요.', style: TextStyle(color: Colors.grey[400])),
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              if (images.isNotEmpty && textItems.isNotEmpty) const SizedBox(height: 10),

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