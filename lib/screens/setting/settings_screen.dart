import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ★★★ 정확한 파일 경로인지 다시 한번 확인해주세요! ★★★
import 'package:hackton_2025_2/screens/setting/edit_profile_screen.dart';
import 'package:hackton_2025_2/screens/setting/account_delete_loading_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _userName = '사용자'; // 불러온 이름을 저장할 변수 (기본값)
  bool _isLoadingProfile = true; // 로딩 상태 변수

  @override
  void initState() {
    super.initState();
    // 화면이 시작될 때 프로필 정보를 불러옵니다.
    _fetchUserProfile();
  }

  // 🔥 Firestore에서 사용자 프로필(이름) 정보를 가져오는 함수
  Future<void> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data();
        // data['profile']['name'] 경로에 있는 닉네임을 가져옵니다.
        if (data != null &&
            data['profile'] is Map &&
            data['profile']['name'] != null) {
          if (mounted) {
            setState(() {
              _userName = data['profile']['name'];
              _isLoadingProfile = false; // 로딩 완료
            });
          }
          return;
        }
      }
    } catch (e) {
      print("❌ 프로필 정보 불러오기 실패: $e");
    }

    // 데이터가 없거나 에러가 나도 로딩 표시를 해제합니다.
    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그아웃되었습니다.')));
    } catch (e) {
      print('로그아웃 오류: $e');
    }
  }

  void _showDeleteAccountDialog() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    String? userNickname;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null &&
            data.containsKey('profile') &&
            data['profile'] is Map &&
            data['profile'].containsKey('name')) {
          userNickname = data['profile']['name'];
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('사용자 정보 로딩 실패: $e')));
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }

    if (userNickname == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임 정보를 찾을 수 없어 탈퇴를 진행할 수 없습니다.')),
      );
      return;
    }

    final nicknameController = TextEditingController();
    // 1. 닉네임 입력 팝업
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원 탈퇴 인증'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('계정을 영구적으로 삭제하려면, 아래에 본인의 닉네임을 정확하게 입력해주세요.'),
            const SizedBox(height: 12),
            Text(
              '닉네임: $userNickname',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(
                hintText: '닉네임을 입력하세요',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              // 2. 닉네임 일치 확인
              if (nicknameController.text == userNickname) {
                Navigator.of(dialogContext).pop();
                // 3. 최종 확인 팝업
                showDialog(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('정말 탈퇴하시겠습니까?'),
                    content: const Text(
                      '모든 데이터가 영구적으로 삭제되며, 이 작업은 되돌릴 수 없습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(confirmContext).pop(),
                        child: const Text('취소'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(confirmContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const AccountDeleteLoadingScreen(),
                            ),
                          );
                        },
                        child: Text(
                          '탈퇴 진행',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('닉네임이 일치하지 않습니다. 다시 확인해주세요.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: Text('확인', style: TextStyle(color: Colors.blue[700])),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎨 [디자인 수정] 전체 배경색을 아주 연한 회색으로 설정
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text(
            '설정',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24),
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
        // actions: [...]  <-- 이 부분이 아예 사라짐
      ),
      // 프로필 정보 로딩 중이면 로딩 표시
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20), // 전체적인 여백 설정
              children: [
                const SizedBox(height: 20),

                // ✨✨✨ [핵심 디자인 수정 부분] 커스텀 프로필 카드 ✨✨✨
                Stack(
                  clipBehavior: Clip.none, // 프로필 아이콘이 카드 밖으로 나가도 잘리지 않게 설정
                  alignment: Alignment.topCenter,
                  children: [
                    // 1️⃣ 흰색 카드 배경 (내용물 포함)
                    Container(
                      margin: const EdgeInsets.only(
                        top: 50.0,
                      ), // 아이콘이 들어갈 자리만큼 상단 여백
                      padding: const EdgeInsets.fromLTRB(
                        20.0,
                        70.0,
                        20.0,
                        40.0,
                      ), // 내부 여백 (아이콘 아래부터 텍스트 시작)
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30.0), // 둥근 모서리
                        // (선택) 살짝 그림자를 줘서 입체감 추가
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      width: double.infinity,
                      child: Column(
                        children: [
                          // 불러온 사용자 이름 표시
                          Text(
                            _userName,
                            style: const TextStyle(
                              fontSize: 26.0,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2️⃣ 프로필 아이콘 (카드 위에 겹쳐짐)
                    Positioned(
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4.0), // 흰색 테두리 두께
                        decoration: const BoxDecoration(
                          color: Colors.white, // 배경과 같은 색의 테두리로 자연스럽게 연결
                          shape: BoxShape.circle,
                        ),
                        child: const CircleAvatar(
                          radius: 55.0, // 아이콘 크기
                          backgroundColor: Color(0xFF69E7B6), // 민트색 배경 (이미지 참조)
                          child: Icon(
                            Icons.person,
                            size: 65.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // 3️⃣ 편집 버튼 (카드 오른쪽 상단)
                    Positioned(
                      top: 75.0, // 카드 상단에서의 위치 조정
                      right: 25.0, // 오른쪽 여백
                      child: GestureDetector(
                        onTap: () {
                          // '편집' 버튼 클릭 시 프로필 수정 화면으로 이동
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EditProfileScreen(),
                            ),
                          ).then((_) {
                            // 수정 화면에서 돌아왔을 때 데이터 새로고침 (정보가 바뀌었을 수 있으므로)
                            _fetchUserProfile();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18.0,
                            vertical: 9.0,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[200], // 연한 회색 버튼 배경
                            borderRadius: BorderRadius.circular(
                              20.0,
                            ), // 둥근 알약 모양
                          ),
                          child: const Text(
                            '편집',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ✨✨✨ 커스텀 프로필 카드 끝 ✨✨✨
                const SizedBox(height: 40), // 카드와 하단 메뉴 사이 간격
                // 나머지 메뉴들은 깔끔하게 ListTile로 유지 (디자인 약간 다듬음)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        leading: const Icon(
                          Icons.logout,
                          color: Colors.black54,
                        ),
                        title: const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: const Text('로그아웃'),
                                content: const Text('정말 로그아웃 하시겠습니까?'),
                                actions: [
                                  TextButton(
                                    child: const Text('취소'),
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(),
                                  ),
                                  TextButton(
                                    child: const Text('확인'),
                                    onPressed: () {
                                      Navigator.of(dialogContext).pop();
                                      _logout();
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      const Divider(
                        height: 1,
                        indent: 20,
                        endIndent: 20,
                      ), // 구분선
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        leading: Icon(
                          Icons.person_remove_outlined,
                          color: Colors.red[300],
                        ),
                        title: Text(
                          '회원 탈퇴',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: _showDeleteAccountDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }
}
