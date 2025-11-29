import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_food_screen.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';
import '../utils/diet_notifier.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  late PageController _pageController;

  bool _isAnalyzing = false;
  Map<String, dynamic> _savedMeals = {};

  // 수정 모드인지 확인하는 상태 변수 (DB 삭제 없이 UI만 변경하기 위함)
  final Map<String, bool> _isEditingMode = {};

  List<XFile> _breakfastImages = [];
  List<XFile> _lunchImages = [];
  List<XFile> _dinnerImages = [];
  List<XFile> _snackImages = [];
  List<String> _breakfastTexts = [];
  List<String> _lunchTexts = [];
  List<String> _dinnerTexts = [];
  List<String> _snackTexts = [];

  late DateTime _selectedDate;

  DateTime get _dietDate {
    final now = DateTime.now();
    if (now.hour < 4) {
      return now.subtract(const Duration(days: 1));
    }
    return now;
  }

  List<DateTime> get _weekDates {
    return List.generate(7, (index) {
      return _dietDate.subtract(Duration(days: 6 - index));
    });
  }

  String _key(String baseKey) {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return "${dateStr}_$baseKey";
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _dietDate;
    _pageController = PageController(initialPage: 6);
    _retrieveLostData();
    _loadTempData();
    _fetchFirebaseData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchFirebaseData() async {
    final data = await DatabaseService().fetchTodayMeals(_selectedDate);
    if (mounted) {
      setState(() {
        _savedMeals = data;
        // 데이터를 새로 불러오면 수정 모드는 해제 (보기 모드로)
        _isEditingMode.clear();
      });
    }
  }

  Future<void> _loadTempData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _breakfastTexts = prefs.getStringList(_key('breakfast_texts')) ?? [];
      _lunchTexts = prefs.getStringList(_key('lunch_texts')) ?? [];
      _dinnerTexts = prefs.getStringList(_key('dinner_texts')) ?? [];
      _snackTexts = prefs.getStringList(_key('snack_texts')) ?? [];

      _breakfastImages = (prefs.getStringList(_key('breakfast_images')) ?? [])
          .map((path) => XFile(path))
          .toList();
      _lunchImages = (prefs.getStringList(_key('lunch_images')) ?? [])
          .map((path) => XFile(path))
          .toList();
      _dinnerImages = (prefs.getStringList(_key('dinner_images')) ?? [])
          .map((path) => XFile(path))
          .toList();
      _snackImages = (prefs.getStringList(_key('snack_images')) ?? [])
          .map((path) => XFile(path))
          .toList();
    });
  }

  Future<void> _saveTempData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key('breakfast_texts'), _breakfastTexts);
    await prefs.setStringList(_key('lunch_texts'), _lunchTexts);
    await prefs.setStringList(_key('dinner_texts'), _dinnerTexts);
    await prefs.setStringList(_key('snack_texts'), _snackTexts);

    await prefs.setStringList(
      _key('breakfast_images'),
      _breakfastImages.map((e) => e.path).toList(),
    );
    await prefs.setStringList(
      _key('lunch_images'),
      _lunchImages.map((e) => e.path).toList(),
    );
    await prefs.setStringList(
      _key('dinner_images'),
      _dinnerImages.map((e) => e.path).toList(),
    );
    await prefs.setStringList(
      _key('snack_images'),
      _snackImages.map((e) => e.path).toList(),
    );
  }

  Future<void> _onDateChanged(int index) async {
    // 날짜 변경 시 현재 작업 중이던(저장 안 한) 내용은 버리고, 새 날짜의 저장된 데이터를 불러옴
    setState(() {
      _selectedDate = _weekDates[index];
      _breakfastImages = [];
      _breakfastTexts = [];
      _lunchImages = [];
      _lunchTexts = [];
      _dinnerImages = [];
      _dinnerTexts = [];
      _snackImages = [];
      _snackTexts = [];
      _savedMeals = {};
      _isEditingMode.clear();
    });
    await _loadTempData();
    await _fetchFirebaseData();
  }

  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;
    final XFile? file = response.file;
    if (file != null) {
      setState(() {
        _breakfastImages.add(file);
      });
      // _saveTempData(); // 자동 저장 제거
    }
  }

  // Firestore 데이터 삭제 함수 (초기화 버튼을 눌렀을 때만 사용)
  Future<void> _deleteMealFromDB(String mealType) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('daily_logs')
          .doc(dateStr)
          .collection('meals')
          .doc(mealType)
          .delete();

      if (mounted) {
        setState(() {
          _savedMeals.remove(mealType);
          _isEditingMode[mealType] = false;
        });
        DietNotifier.notify();
      }
    } catch (e) {
      print("DB 삭제 실패: $e");
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
        // _saveTempData(); // 자동 저장 제거 (분석 안 누르면 날아가게)
        // DB 삭제 로직 제거 (정정 버튼 누를 때만 삭제)
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
                  // _saveTempData(); // 자동 저장 제거
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

  void _removeText(String mealType, String text) {
    setState(() {
      switch (mealType) {
        case '아침':
          _breakfastTexts.remove(text);
          break;
        case '점심':
          _lunchTexts.remove(text);
          break;
        case '저녁':
          _dinnerTexts.remove(text);
          break;
        case '간식':
          _snackTexts.remove(text);
          break;
      }
    });
    // _saveTempData(); // 자동 저장 제거
  }

  void _removeImage(String mealType, XFile image) {
    setState(() {
      switch (mealType) {
        case '아침':
          _breakfastImages.remove(image);
          break;
        case '점심':
          _lunchImages.remove(image);
          break;
        case '저녁':
          _dinnerImages.remove(image);
          break;
        case '간식':
          _snackImages.remove(image);
          break;
      }
    });
    // _saveTempData(); // 자동 저장 제거
  }

  // 수정 버튼 누르면 -> 화면만 입력 폼으로 바꿈
  void _onModifyPressed(String mealType) {
    setState(() {
      _isEditingMode[mealType] = true;
    });
  }

  // 🔥 [초기화 버튼] 누르면 -> 로컬 싹 지우고 + DB 데이터도 날림
  void _onCorrectionPressed(String mealType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('정말 초기화하시겠습니까?'),
        content: const Text('입력된 사진과 기존 저장된 데이터가 모두 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 다이얼로그 닫기

              // 1. 로컬 데이터 초기화
              setState(() {
                switch (mealType) {
                  case '아침':
                    _breakfastImages.clear();
                    _breakfastTexts.clear();
                    break;
                  case '점심':
                    _lunchImages.clear();
                    _lunchTexts.clear();
                    break;
                  case '저녁':
                    _dinnerImages.clear();
                    _dinnerTexts.clear();
                    break;
                  case '간식':
                    _snackImages.clear();
                    _snackTexts.clear();
                    break;
                }
              });
              _saveTempData();

              // 2. DB 데이터 삭제 (실제 초기화)
              _deleteMealFromDB(mealType);
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _onAnalyzePressed(String mealType) async {
    List<XFile> targetImages = [];
    List<String> targetTexts = [];
    switch (mealType) {
      case '아침':
        targetImages = _breakfastImages;
        targetTexts = _breakfastTexts;
        break;
      case '점심':
        targetImages = _lunchImages;
        targetTexts = _lunchTexts;
        break;
      case '저녁':
        targetImages = _dinnerImages;
        targetTexts = _dinnerTexts;
        break;
      case '간식':
        targetImages = _snackImages;
        targetTexts = _snackTexts;
        break;
    }

    if (targetImages.isEmpty && targetTexts.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final gemini = GeminiService();
      final foodList = await gemini.identifyFoodList(targetImages, targetTexts);

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }

      if (foodList != null) {
        if (!mounted) return;
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditFoodScreen(
              initialFoods: foodList,
              mealType: mealType,
              selectedDate: _selectedDate,
            ),
          ),
        );
        if (result == true) {
          // 저장이 완료되었을 때만 DB를 다시 불러오고, 임시 사진을 정리함
          _fetchFirebaseData();
          DietNotifier.notify();
          setState(() {
            _isEditingMode[mealType] = false; // 수정 모드 종료
            // 🔥 분석 완료 후에도 사진과 텍스트를 유지하고 싶으면 아래 부분을 주석 처리하세요.
            // 🔥 현재는 "저장됨" 상태가 되면 UI가 요약 카드로 바뀌므로 입력 폼의 데이터를 굳이 남길 필요가 없어 보이지만,
            // 🔥 "다시 수정"을 눌렀을 때 이전 사진이 남아있길 원한다면 아래 clear() 부분을 삭제하세요.
            // 여기서는 "저장 완료 시 로컬 입력 데이터는 클리어하지 않음"으로 설정하여 수정 시 다시 보이게 합니다.
            _saveTempData();
          });
        }
      } else {
        throw Exception('음식을 식별하지 못했습니다.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Widget _buildDateSelector() {
    return Container(
      height: 60,
      color: Colors.grey[200],
      padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(_weekDates.length, (index) {
          final date = _weekDates[index];
          final isSelected =
              DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(_selectedDate);
          Widget tabContent = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E', 'en_US').format(date),
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.black : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isSelected
                        ? FontWeight.w900
                        : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey[600],
                    height: 1.0,
                  ),
                ),
              ),
            ],
          );
          return Expanded(
            child: GestureDetector(
              onTap: () => _pageController.jumpToPage(index),
              child: isSelected
                  ? Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(10),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: tabContent,
                        ),
                        const Positioned(
                          bottom: 0,
                          left: -10,
                          child: _InvertedCorner(
                            color: Color(0xFFF5F5F5),
                            isLeft: true,
                          ),
                        ),
                        const Positioned(
                          bottom: 0,
                          right: -10,
                          child: _InvertedCorner(
                            color: Color(0xFFF5F5F5),
                            isLeft: false,
                          ),
                        ),
                      ],
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: tabContent,
                    ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      onFocusGained: () {
        _loadTempData();
        _fetchFirebaseData();
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey[200],
            body: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  backgroundColor: Colors.grey[200],
                  floating: true,
                  pinned: false,
                  snap: true,
                  expandedHeight: 80,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 1),
                          child: Text(
                            '새벽 4시 ~ 익일 새벽 4시 기준',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                        _buildDateSelector(),
                      ],
                    ),
                  ),
                ),
              ],
              body: Container(
                color: const Color(0xFFF5F5F5),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: 7,
                  onPageChanged: (index) => _onDateChanged(index),
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildMealSection(
                            '아침',
                            _breakfastImages,
                            _breakfastTexts,
                          ),
                          const SizedBox(height: 16),
                          _buildMealSection('점심', _lunchImages, _lunchTexts),
                          const SizedBox(height: 16),
                          _buildMealSection('저녁', _dinnerImages, _dinnerTexts),
                          const SizedBox(height: 16),
                          _buildMealSection('간식', _snackImages, _snackTexts),
                          const SizedBox(height: 100),
                        ],
                      ),
                    );
                  },
                ),
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
                    Text(
                      'AI가 음식을 확인하고 있어요...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMealSection(
    String title,
    List<XFile> images,
    List<String> textItems,
  ) {
    bool isSaved = _savedMeals.containsKey(title);
    bool isEditing = _isEditingMode[title] ?? false;

    if (isSaved && !isEditing) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _onModifyPressed(title),
                  icon: const Icon(Icons.edit, size: 12, color: Colors.grey),
                  label: const Text(
                    '수정',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSummaryCard(_savedMeals[title]),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Flexible(
                  child: ExpandableFab(
                    onCameraTap: () => _pickImage(title, ImageSource.camera),
                    onGalleryTap: () => _pickImage(title, ImageSource.gallery),
                    onTextTap: () => _showTextInputDialog(title),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildInputForm(title, images, textItems),
          ],
        ),
      );
    }
  }

  Widget _buildSummaryCard(Map<String, dynamic> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${data['totalCalories']} kcal',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
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
        Text(
          val,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildInputForm(
    String title,
    List<XFile> images,
    List<String> textItems,
  ) {
    bool hasContent = images.isNotEmpty || textItems.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (!hasContent)
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
                  if (images.isNotEmpty)
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                margin: const EdgeInsets.only(
                                  right: 10,
                                  top: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(File(images[index].path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 5,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      _removeImage(title, images[index]),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  if (images.isNotEmpty && textItems.isNotEmpty)
                    const SizedBox(height: 10),
                  if (textItems.isNotEmpty)
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: textItems.map((text) {
                        return Chip(
                          label: Text(text),
                          backgroundColor: Colors.lightBlue[50],
                          side: BorderSide.none,
                          onDeleted: () => _removeText(title, text),
                        );
                      }).toList(),
                    ),
                ],
              ),
        if (hasContent) ...[
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _onAnalyzePressed(title),
                  icon: const Icon(Icons.analytics_outlined, size: 18),
                  label: const Text('분석 시작'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE8F5E9),
                    foregroundColor: Colors.green[700],
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 80,
                child: ElevatedButton(
                  onPressed: () => _onCorrectionPressed(title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('초기화'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ExpandableFab extends StatefulWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  final VoidCallback onTextTap;

  const ExpandableFab({
    super.key,
    required this.onCameraTap,
    required this.onGalleryTap,
    required this.onTextTap,
  });

  @override
  State<ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<ExpandableFab>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: SizedBox(
            width: _isOpen ? null : 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionBtn(Icons.camera_alt, '카메라', widget.onCameraTap),
                  const SizedBox(width: 8),
                  _buildActionBtn(
                    Icons.photo_library,
                    '갤러리',
                    widget.onGalleryTap,
                  ),
                  const SizedBox(width: 8),
                  _buildActionBtn(Icons.edit, '텍스트', widget.onTextTap),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: _toggle,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isOpen ? Colors.grey[200] : const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: _isOpen ? Colors.grey : Colors.blue,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        _toggle();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _InvertedCorner extends StatelessWidget {
  final Color color;
  final bool isLeft;
  const _InvertedCorner({required this.color, required this.isLeft});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: CustomPaint(
        painter: _InvertedCornerPainter(color: color, isLeft: isLeft),
      ),
    );
  }
}

class _InvertedCornerPainter extends CustomPainter {
  final Color color;
  final bool isLeft;
  _InvertedCornerPainter({required this.color, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    if (isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(size.width),
        clockwise: false,
      );
    } else {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.arcToPoint(Offset(0, 0), radius: Radius.circular(size.width));
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
