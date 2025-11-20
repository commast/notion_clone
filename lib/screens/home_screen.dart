import 'package:flutter/material.dart';
import '../widgets/common/notion_bottom_bar.dart';
import '../widgets/home/recent_page_card.dart';
import '../widgets/home/personal_page_tile.dart';
import '../data/page_data.dart'; // 아까 만든 모델 import
import '../screens/page_screen.dart';
import '../screens/login_screen.dart';

class NotionHomeScreen extends StatefulWidget {
  const NotionHomeScreen({super.key});

  @override
  State<NotionHomeScreen> createState() => _NotionHomeScreenState();
}

class _NotionHomeScreenState extends State<NotionHomeScreen> {
  final List<Map<String, dynamic>> _recentPages = [];
  String? _userName;

  //로그인 화면 이동
  Future<void> _goToLogin() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        _userName = result; // 로그인된 사용자 이름
      });
    }
  }

  //로그아웃 확인
  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('예'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        _userName = null; // 로그인 해제
      });
    }
  }

  // 개인 페이지 리스트를 PageData로 관리
  final List<PageData> _personalPages = [];

  // --- 버튼 눌렀을 때: 최종 편집 기준으로 정렬 (최근 것이 위로 오게)
  void _sortByLastEdited() {
    setState(() {
      _personalPages.sort((a, b) => b.lastEdited.compareTo(a.lastEdited));
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('최종 편집일 순으로 정렬되었습니다.'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // + 버튼 눌렀을 때: "제목 없음" 새 페이지 추가
  void _addNewPage() {
    setState(() {
      final newPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '제목 없음',
        lastEdited: DateTime.now(),
      );

      // 개인 페이지 리스트에 추가
      _personalPages.insert(0, newPage);

      // 최근 방문한 페이지 카드에도 추가
      _recentPages.insert(0, {
        'pageId': newPage.id, // 👈 새로 추가된 페이지 id 저장
        'title': newPage.title,
        'icon': Icons.edit_note,
        'color': const Color(0xFFF0F0F0),
      });

      if (_recentPages.length > 7) {
        _recentPages.removeLast();
      }
    });
  }

  // 새 페이지를 만들고, 해당 페이지 화면으로 바로 이동
  void _createNewPageAndOpen(BuildContext ctx) {
    late PageData newPage;

    setState(() {
      newPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '제목 없음',
        lastEdited: DateTime.now(),
      );

      // 1) 개인 페이지 리스트에 추가
      _personalPages.insert(0, newPage);

      // 2) 최근 방문한 페이지 카드에도 추가
      _recentPages.insert(0, {
        'pageId': newPage.id,
        'title': newPage.title,
        'icon': Icons.edit_note,
        'color': const Color(0xFFF0F0F0),
      });

      if (_recentPages.length > 7) {
        _recentPages.removeLast();
      }
    });

    // 3) 새 페이지 화면으로 이동
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => NotionPageScreen(
          page: newPage,
          onNewPage: () => _createNewPageAndOpen(ctx), // 페이지 화면에서도 새 페이지 생성 가능
        ),
      ),
    );
  }

  // 페이지 삭제 버튼
  Future<void> _confirmDeletePage(PageData page) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('페이지 삭제'),
          content: const Text('제거하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('예'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      setState(() {
        // 1) 개인 페이지 목록에서 삭제
        _personalPages.remove(page);

        // 2) 최근 방문한 페이지 카드에서도 삭제
        _recentPages.removeWhere((item) => item['pageId'] == page.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _userName == null
            // ✅ 로그인 안 된 상태: "로그인" 텍스트
            ? GestureDetector(
                onTap: _goToLogin,
                child: const Text(
                  '로그인',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              )
            // ✅ 로그인 된 상태: 프로필 아이콘 + "OOO의 Notion"
            : InkWell(
                onTap: _confirmLogout,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade400,
                      child: Text(
                        _userName!.isNotEmpty
                            ? _userName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_userName!}의 Notion',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
        actions: const [
          IconButton(icon: Icon(Icons.more_vert), onPressed: null),
        ],
      ),

      body: CustomScrollView(
        slivers: [
          // 최근 방문한 페이지 제목
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, top: 10.0, bottom: 8.0),
              child: Text(
                '최근 방문한 페이지',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ),

          // 최근 방문 카드
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentPages.length,
                itemBuilder: (context, index) {
                  final recent = _recentPages[index];
                  final pageId = recent['pageId'] as String;

                  // pageId로 실제 PageData 찾기
                  final pageData = _personalPages.firstWhere(
                    (p) => p.id == pageId,
                  );

                  return RecentPageCard(
                    title: pageData.title,
                    icon: recent['icon'] as IconData,
                    color: recent['color'] as Color,
                    onTap: () async {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotionPageScreen(
                            page: pageData, // ✅ PageData 넘기기
                            onNewPage: () => _createNewPageAndOpen(context),
                            onPageChanged: () => setState(() {}),
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ),

          // ------------------ 여기부터 "개인 페이지" 헤더 Row ------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 20.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  const Text(
                    '개인 페이지',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // ... 버튼 (정렬)
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _sortByLastEdited,
                  ),
                  const SizedBox(width: 8),
                  // + 버튼 (새 페이지)
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _addNewPage,
                  ),
                ],
              ),
            ),
          ),
          // -------------------------------------------------------------------

          // 개인 페이지 리스트
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final page = _personalPages[index];
              return PersonalPageTile(
                title: page.title,
                onMorePressed: () => _confirmDeletePage(page),
                onTap: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotionPageScreen(
                        page: page,
                        onNewPage: () => _createNewPageAndOpen(context),
                        onPageChanged: () => setState(() {}),
                      ),
                    ),
                  );
                  setState(() {});
                },
              );
            }, childCount: _personalPages.length),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomSheet: NotionBottomBar(
        onNewPage: () => _createNewPageAndOpen(context),
      ),
    );
  }
}
