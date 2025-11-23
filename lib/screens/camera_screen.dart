import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'edit_food_screen.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart'; // DB 서비스 추가

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  // 로딩 상태 변수
  bool _isAnalyzing = false;

  // DB에서 가져온 저장된 식단 데이터 (키: '아침', '점심' 등)
  Map<String, dynamic> _savedMeals = {};

  // 데이터 리스트들
  List<XFile> _breakfastImages = [];
  List<XFile> _lunchImages = [];
  List<XFile> _dinnerImages = [];
  List<XFile> _snackImages = [];
  List<String> _breakfastTexts = [];
  List<String> _lunchTexts = [];
  List<String> _dinnerTexts = [];
  List<String> _snackTexts = [];

  // 새벽 4시 기준 날짜 계산 (오늘 날짜)
  DateTime get _dietDate {
    final now = DateTime.now();
    if (now.hour < 4) {
      return now.subtract(const Duration(days: 1));
    }
    return now;
  }

  @override
  void initState() {
    super.initState();
    _retrieveLostData(); // 안드로이드 앱 전환 복구
    _loadTempData();     // 로컬 임시 저장 데이터 복구
    _fetchFirebaseData(); // Firebase DB 데이터 불러오기
  }

  // 1. 파이어베이스에서 오늘 기록 불러오기
  Future<void> _fetchFirebaseData() async {
    final data = await DatabaseService().fetchTodayMeals();
    if (mounted) {
      setState(() {
        _savedMeals = data;
      });
    }
  }

  // 2. 로컬 임시 데이터 불러오기
  Future<void> _loadTempData() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedDate = prefs.getString('temp_date');
    String todayStr = DateFormat('yyyy-MM-dd').format(_dietDate);

    // 날짜가 다르면(어제 기록이면) 초기화
    if (savedDate != todayStr) {
      await prefs.clear();
      return;
    }

    setState(() {
      _breakfastTexts = prefs.getStringList('breakfast_texts') ?? [];
      _lunchTexts = prefs.getStringList('lunch_texts') ?? [];
      _dinnerTexts = prefs.getStringList('dinner_texts') ?? [];
      _snackTexts = prefs.getStringList('snack_texts') ?? [];

      _breakfastImages = (prefs.getStringList('breakfast_images') ?? []).map((path) => XFile(path)).toList();
      _lunchImages = (prefs.getStringList('lunch_images') ?? []).map((path) => XFile(path)).toList();
      _dinnerImages = (prefs.getStringList('dinner_images') ?? []).map((path) => XFile(path)).toList();
      _snackImages = (prefs.getStringList('snack_images') ?? []).map((path) => XFile(path)).toList();
    });
  }

  // 3. 로컬 임시 데이터 저장하기
  Future<void> _saveTempData() async {
    final prefs = await SharedPreferences.getInstance();
    String todayStr = DateFormat('yyyy-MM-dd').format(_dietDate);

    await prefs.setString('temp_date', todayStr);

    await prefs.setStringList('breakfast_texts', _breakfastTexts);
    await prefs.setStringList('lunch_texts', _lunchTexts);
    await prefs.setStringList('dinner_texts', _dinnerTexts);
    await prefs.setStringList('snack_texts', _snackTexts);

    await prefs.setStringList('breakfast_images', _breakfastImages.map((e) => e.path).toList());
    await prefs.setStringList('lunch_images', _lunchImages.map((e) => e.path).toList());
    await prefs.setStringList('dinner_images', _dinnerImages.map((e) => e.path).toList());
    await prefs.setStringList('snack_images', _snackImages.map((e) => e.path).toList());
  }

  // 안드로이드 프로세스 복구
  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;
    final XFile? file = response.file;
    if (file != null) {
      setState(() {
        _breakfastImages.add(file); // 임시로 아침에 추가
      });
      _saveTempData();
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
        _saveTempData();
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
              hintText: '예: 현미밥 1공기',
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
                  _saveTempData();
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

  void _removeText(String mealType, String text) {
    setState(() {
      switch (mealType) {
        case '아침': _breakfastTexts.remove(text); break;
        case '점심': _lunchTexts.remove(text); break;
        case '저녁': _dinnerTexts.remove(text); break;
        case '간식': _snackTexts.remove(text); break;
      }
    });
    _saveTempData();
  }

  // 🟢 분석 시작 버튼 클릭
  void _onAnalyzePressed(String mealType) async {
    List<XFile> targetImages = [];
    List<String> targetTexts = [];

    switch (mealType) {
      case '아침': targetImages = _breakfastImages; targetTexts = _breakfastTexts; break;
      case '점심': targetImages = _lunchImages; targetTexts = _lunchTexts; break;
      case '저녁': targetImages = _dinnerImages; targetTexts = _dinnerTexts; break;
      case '간식': targetImages = _snackImages; targetTexts = _snackTexts; break;
    }

    if (targetImages.isEmpty && targetTexts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('분석할 사진이나 텍스트가 없습니다.')));
      return;
    }

    setState(() { _isAnalyzing = true; });

    try {
      final gemini = GeminiService();
      final foodList = await gemini.identifyFoodList(targetImages, targetTexts);

      if (mounted) { setState(() { _isAnalyzing = false; }); }

      if (foodList != null) {
        if (!mounted) return;

        // 화면 이동 (갔다 오면 DB 다시 조회)
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditFoodScreen(
              initialFoods: foodList,
              mealType: mealType,
            ),
          ),
        );
        _fetchFirebaseData(); // 돌아왔을 때 새로고침
      } else {
        throw Exception('음식을 식별하지 못했습니다.');
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isAnalyzing = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  // 🟢 수정하기 버튼 클릭 (요약 카드 지우기)
  void _onModifyPressed(String mealType) {
    setState(() {
      _savedMeals.remove(mealType);
    });
  }

  @override
  Widget build(BuildContext context) {
    String dateDisplay = DateFormat('M월 d일').format(_dietDate);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            centerTitle: true,
            toolbarHeight: 80,
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dateDisplay 식단',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 4),
                const Text(
                  '새벽 4시 ~ 익일 새벽 4시 기준',
                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
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

        if (_isAnalyzing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text('AI가 음식을 확인하고 있어요...', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 🟢 끼니 섹션 빌더 (분기 처리)
  Widget _buildMealSection(String title, List<XFile> images, List<String> textItems) {
    bool isSaved = _savedMeals.containsKey(title);
    Map<String, dynamic>? savedData = isSaved ? _savedMeals[title] : null;

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
              isSaved
                  ? TextButton.icon(
                onPressed: () => _onModifyPressed(title),
                icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                label: const Text('수정하기', style: TextStyle(color: Colors.grey)),
              )
                  : IconButton(
                onPressed: () => _showAddOptions(context, title),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 28,
                color: Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 저장됨 ? 요약카드 : 입력폼
          if (isSaved && savedData != null)
            _buildSummaryCard(savedData)
          else
            _buildInputForm(title, images, textItems),
        ],
      ),
    );
  }

  // 🟢 요약 카드 UI
  Widget _buildSummaryCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data['totalCalories']} kcal',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMacroInfo('탄수화물', '${data['totalCarbs']}g'),
              const SizedBox(width: 16),
              _buildMacroInfo('단백질', '${data['totalProtein']}g'),
              const SizedBox(width: 16),
              _buildMacroInfo('지방', '${data['totalFat']}g'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroInfo(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        Text(val, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // 🟢 입력 폼 UI (기존 로직 분리)
  Widget _buildInputForm(String title, List<XFile> images, List<String> textItems) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    onDeleted: () => _removeText(title, text),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }
}