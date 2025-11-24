import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:focus_detector/focus_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'edit_food_screen.dart';
import '../services/gemini_service.dart';
import '../services/database_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isAnalyzing = false;
  Map<String, dynamic> _savedMeals = {};

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

  String _key(String baseKey) {
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return "${dateStr}_$baseKey";
  }

  List<DateTime> get _weekDates {
    return List.generate(7, (index) {
      return _dietDate.subtract(Duration(days: 6 - index));
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = _dietDate;
    _retrieveLostData();
    _loadTempData();
    _fetchFirebaseData();
  }

  Future<void> _fetchFirebaseData() async {
    final data = await DatabaseService().fetchTodayMeals(_selectedDate);
    if (mounted) {
      setState(() {
        _savedMeals = data;
      });
    }
  }

  Future<void> _loadTempData() async {
    final prefs = await SharedPreferences.getInstance();
    // 키 생성 함수(_key)를 사용해서 해당 날짜의 데이터를 가져옴
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

    await prefs.setStringList(_key('breakfast_images'), _breakfastImages.map((e) => e.path).toList());
    await prefs.setStringList(_key('lunch_images'), _lunchImages.map((e) => e.path).toList());
    await prefs.setStringList(_key('dinner_images'), _dinnerImages.map((e) => e.path).toList());
    await prefs.setStringList(_key('snack_images'), _snackImages.map((e) => e.path).toList());
  }

  Future<void> _retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) return;
    final XFile? file = response.file;
    if (file != null) {
      setState(() {
        _breakfastImages.add(file);
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

  void _removeImage(String mealType, XFile image) {
    setState(() {
      switch (mealType) {
        case '아침': _breakfastImages.remove(image); break;
        case '점심': _lunchImages.remove(image); break;
        case '저녁': _dinnerImages.remove(image); break;
        case '간식': _snackImages.remove(image); break;
      }
    });
    _saveTempData();
  }

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
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditFoodScreen(
              initialFoods: foodList,
              mealType: mealType,
            ),
          ),
        );
        _fetchFirebaseData();
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

  void _onModifyPressed(String mealType) {
    setState(() {
      _savedMeals.remove(mealType);
    });
  }

  // 🟢 [수정] 날짜 선택 위젯 (반전된 곡선 적용)
  Widget _buildDateSelector() {
    return Container(
      height: 50,
      color: Colors.grey[200],
      // 🟢 하단 패딩 제거 (몸통과 밀착)
      padding: const EdgeInsets.only(left: 10, right: 10, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end, // 하단 정렬
        children: _weekDates.map((date) {
          final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
              DateFormat('yyyy-MM-dd').format(_selectedDate);

          // 날짜/요일 내용물
          Widget tabContent = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('E', 'en_US').format(date),
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.black : Colors.grey[500],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  DateFormat('d').format(date),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                    color: isSelected ? Colors.black : Colors.grey[600],
                    height: 1.0, // 줄간격 타이트하게
                  ),
                ),
              ),
            ],
          );

          return Expanded(
            child: GestureDetector(
              onTap: () async {
                setState(() {
                  _selectedDate = date;
                  // 2. 화면의 리스트들 일단 비우기 (깜빡임 방지 & 잔상 제거)
                  _breakfastImages = []; _breakfastTexts = [];
                  _lunchImages = []; _lunchTexts = [];
                  _dinnerImages = []; _dinnerTexts = [];
                  _snackImages = []; _snackTexts = [];
                  _savedMeals = {}; // DB 데이터도 초기화
                });

                await _loadTempData();     // 로컬 데이터(작성중인 것) 로드
                await _fetchFirebaseData(); // DB 데이터(저장된 것) 로드

              },
              child: isSelected
                  ? Stack(
                clipBehavior: Clip.none, // 영역 밖으로 그리기 허용
                alignment: Alignment.bottomCenter,
                children: [
                  // 🟢 메인 흰색 탭 (위쪽만 둥글게)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    alignment: Alignment.center,
                    child: tabContent,
                  ),
                  // 🟢 왼쪽 하단 연결부 (반전 곡선)
                  const Positioned(
                    bottom: 0,
                    left: -10, // 탭 바깥쪽으로 위치
                    child: _InvertedCorner(color: Colors.white, isLeft: true),
                  ),
                  // 🟢 오른쪽 하단 연결부 (반전 곡선)
                  const Positioned(
                    bottom: 0,
                    right: -10, // 탭 바깥쪽으로 위치
                    child: _InvertedCorner(color: Colors.white, isLeft: false),
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
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusDetector(
      // 🟢 [핵심] 탭을 눌러서 이 화면이 다시 보일 때마다 실행됨
      onFocusGained: () {
        _loadTempData();      // 로컬 데이터 다시 불러오기
        _fetchFirebaseData(); // 파이어베이스 데이터 다시 불러오기
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey[200],
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.grey[200],
                  floating: true,
                  pinned: false,
                  snap: true,
                  expandedHeight: 85,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '새벽 4시 ~ 익일 새벽 4시 기준',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                          ),
                        ),
                        _buildDateSelector(),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 85,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        _buildMealSection('아침', _breakfastImages, _breakfastTexts),
                        const Divider(height: 1, thickness: 1),
                        _buildMealSection('점심', _lunchImages, _lunchTexts),
                        const Divider(height: 1, thickness: 1),
                        _buildMealSection('저녁', _dinnerImages, _dinnerTexts),
                        const Divider(height: 1, thickness: 1),
                        _buildMealSection('간식', _snackImages, _snackTexts),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
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
      ),
    );
  }

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
                icon: const Icon(Icons.edit, size: 12, color: Colors.grey),
                label: const Text('수정', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
                  : Flexible(
                child: ExpandableFab(
                  onCameraTap: () => _pickImage(title, ImageSource.camera),
                  onGalleryTap: () => _pickImage(title, ImageSource.gallery),
                  onTextTap: () => _showTextInputDialog(title),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (isSaved && savedData != null)
            _buildSummaryCard(savedData)
          else
            _buildInputForm(title, images, textItems),
        ],
      ),
    );
  }

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
                          margin: const EdgeInsets.only(right: 10, top: 5),
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
                            onTap: () => _removeImage(title, images[index]),
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
            if (images.isNotEmpty && textItems.isNotEmpty) const SizedBox(height: 10),
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

class _ExpandableFabState extends State<ExpandableFab> with SingleTickerProviderStateMixin {
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
                  _buildActionBtn(Icons.photo_library, '갤러리', widget.onGalleryTap),
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
                color: _isOpen ? Colors.grey[200] : Colors.blue[50],
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
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

// 🟢 [신규] 반전된 곡선을 그리는 페인터 위젯
class _InvertedCorner extends StatelessWidget {
  final Color color;
  final bool isLeft; // 왼쪽인지 오른쪽인지

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

    // 🟢 왼쪽 조각 (탭의 왼쪽에 붙음)
    // -> 오른쪽 아래가 꽉 차고, 왼쪽 위가 오목하게 파인 모양
    if (isLeft) {
      path.moveTo(size.width, 0); // 1. 오른쪽 위 (탭과 닿는 점)
      path.lineTo(size.width, size.height); // 2. 오른쪽 아래
      path.lineTo(0, size.height); // 3. 왼쪽 아래
      // 4. 오목한 곡선으로 다시 1번 점으로 돌아감
      path.arcToPoint(
        Offset(size.width, 0),
        radius: Radius.circular(size.width),
        clockwise: false, // 반시계 방향으로 돌려야 안쪽으로 파입니다.
      );
    }

    // 🟢 오른쪽 조각 (탭의 오른쪽에 붙음)
    // -> 왼쪽 아래가 꽉 차고, 오른쪽 위가 오목하게 파인 모양
    else {
      path.moveTo(0, 0); // 1. 왼쪽 위 (탭과 닿는 점)
      path.lineTo(0, size.height); // 2. 왼쪽 아래
      path.lineTo(size.width, size.height); // 3. 오른쪽 아래
      // 4. 오목한 곡선으로 다시 1번 점으로 돌아감
      path.arcToPoint(
        Offset(0, 0),
        radius: Radius.circular(size.width),
      );
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}