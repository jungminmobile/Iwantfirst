import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // 나중에 실제 데이터를 담을 리스트들 (지금은 비어있음)
  final List<String> _breakfastItems = [];
  final List<String> _lunchItems = [];
  final List<String> _dinnerItems = [];
  final List<String> _snackItems = [];

  // 더하기 버튼 눌렀을 때 실행되는 함수 (메뉴 선택창 띄우기)
  void _showAddOptions(BuildContext context, String mealType) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250, // 높이 조절
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단 타이틀 및 X 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$mealType 추가하기',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context), // 닫기 기능
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 3가지 옵션 버튼들
              _buildOptionTile(
                icon: Icons.camera_alt,
                text: '카메라로 촬영',
                onTap: () {
                  Navigator.pop(context);
                  print('$mealType - 카메라 촬영 선택됨');
                  // TODO: 카메라 기능 구현
                },
              ),
              _buildOptionTile(
                icon: Icons.photo_library,
                text: '이미지 업로드',
                onTap: () {
                  Navigator.pop(context);
                  print('$mealType - 이미지 업로드 선택됨');
                  // TODO: 갤러리 기능 구현
                },
              ),
              _buildOptionTile(
                icon: Icons.edit,
                text: '텍스트로 입력',
                onTap: () {
                  Navigator.pop(context);
                  print('$mealType - 텍스트 입력 선택됨');
                  // TODO: 텍스트 입력 기능 구현
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 모달 내부의 옵션 타일 위젯
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('식단 기록'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildMealSection('아침', _breakfastItems),
            const Divider(height: 1, thickness: 1),
            _buildMealSection('점심', _lunchItems),
            const Divider(height: 1, thickness: 1),
            _buildMealSection('저녁', _dinnerItems),
            const Divider(height: 1, thickness: 1),
            _buildMealSection('간식', _snackItems),
          ],
        ),
      ),
    );
  }

  // 각 끼니별 섹션 빌더 (아침, 점심, 저녁, 간식)
  Widget _buildMealSection(String title, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 150), // 최소 높이 설정
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 섹션 헤더 (제목 + 더하기 버튼)
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
              IconButton(
                onPressed: () => _showAddOptions(context, title),
                icon: const Icon(Icons.add_circle_outline),
                iconSize: 28,
                color: Colors.blue, // 버튼 색상
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 아이템 리스트 (아직 데이터가 없으면 안내 문구)
          items.isEmpty
              ? Container(
            height: 80,
            alignment: Alignment.centerLeft,
            child: Text(
              '$title을 기록해 보세요.',
              style: TextStyle(color: Colors.grey[400]),
            ),
          )
              : SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (context, index) {
                // 나중에 여기에 이미지나 텍스트 카드를 표시
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  color: Colors.grey[200],
                  child: Center(child: Text('Item $index')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
