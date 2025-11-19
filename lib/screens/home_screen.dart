import 'package:flutter/material.dart';
import '../widgets/common/notion_bottom_bar.dart';
import '../widgets/home/recent_page_card.dart';
import '../widgets/home/personal_page_tile.dart';

class NotionHomeScreen extends StatelessWidget {
  const NotionHomeScreen({super.key});

  final List<Map<String, dynamic>> _recentPages = const [
    {'title': '개인 메모장', 'icon': Icons.edit_note, 'color': Color(0xFFF0F0F0)},
    {'title': '모바일에서 시작하기', 'icon': Icons.waving_hand, 'color': Color(0xFFF0F0F0)},
    {'title': '오픈소스 ...', 'icon': Icons.folder_open, 'color': Color(0xFFF0F0F0)},
  ];

  final List<String> _personalPages = const [
    '개인 메모장',
    '모바일에서 시작하기',
    '1:1 회의록',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text(
              '오픈소스 프로젝트',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
        actions: const [
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: null,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, top: 10.0, bottom: 8.0),
              child: Text(
                '최근 방문한 페이지',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentPages.length,
                itemBuilder: (context, index) {
                  final page = _recentPages[index];
                  return RecentPageCard(
                    title: page['title'] as String,
                    icon: page['icon'] as IconData,
                    color: page['color'] as Color,
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, top: 20.0, bottom: 8.0),
              child: Text(
                '개인 페이지',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return PersonalPageTile(title: _personalPages[index]);
              },
              childCount: _personalPages.length,
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      // ★ 수정됨: AIChatBar 제거하고 NotionBottomBar만 표시
      bottomSheet: const NotionBottomBar(),
    );
  }
}