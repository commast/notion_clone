import 'package:flutter/material.dart';

class BlocSelectorModal extends StatelessWidget {
  final Function(String) onBlockSelected;

  const BlocSelectorModal({
    super.key,
    required this.onBlockSelected,
  });

  final List<Map<String, dynamic>> _allBlocks = const [
    // 기본 블록
    {'icon': '📝', 'title': '텍스트', 'subtitle': '일반 본문 텍스트', 'type': 'text', 'category': '기본'},
    {'icon': '📌', 'title': '제목 1', 'subtitle': '큰 섹션 제목', 'type': 'heading1', 'category': '기본'},
    {'icon': '📌', 'title': '제목 2', 'subtitle': '중간 섹션 제목', 'type': 'heading2', 'category': '기본'},
    {'icon': '📌', 'title': '제목 3', 'subtitle': '작은 섹션 제목', 'type': 'heading3', 'category': '기본'},
    
    // 목록
    {'icon': '•', 'title': '글머리 기호 목록', 'subtitle': '순서 없는 목록', 'type': 'bulleted_list', 'category': '목록'},
    {'icon': '1.', 'title': '번호 매기기 목록', 'subtitle': '순서 있는 목록', 'type': 'numbered_list', 'category': '목록'},
    {'icon': '☑', 'title': '할 일 목록', 'subtitle': '체크박스 목록', 'type': 'todo_list', 'category': '목록'},
    {'icon': '▶', 'title': '토글 목록', 'subtitle': '접이식 목록', 'type': 'toggle_list', 'category': '목록'},
    
    // 특수 블록
    {'icon': '📄', 'title': '페이지', 'subtitle': '하위 페이지 생성', 'type': 'page', 'category': '특수'},
    {'icon': '🔗', 'title': '페이지 링크', 'subtitle': '다른 페이지로 이동', 'type': 'page_link', 'category': '특수'},
    {'icon': '💡', 'title': '콜아웃', 'subtitle': '강조 박스', 'type': 'callout', 'category': '특수'},
    {'icon': '❝', 'title': '인용', 'subtitle': '인용문 블록', 'type': 'quote', 'category': '특수'},
    {'icon': '—', 'title': '구분선', 'subtitle': '섹션 구분', 'type': 'divider', 'category': '특수'},
    
    // 미디어
    {'icon': '📑', 'title': '표', 'subtitle': '표 삽입', 'type': '표', 'category': '미디어'},
    {'icon': '💻', 'title': '코드', 'subtitle': '코드 블록', 'type': '코드', 'category': '미디어'},
    {'icon': '📊', 'title': '막대 차트', 'subtitle': '차트 삽입', 'type': '막대 차트', 'category': '미디어'},
  ];

  Map<String, List<Map<String, dynamic>>> get _groupedBlocks {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var block in _allBlocks) {
      final category = block['category'] as String;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(block);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '블록 선택',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: _groupedBlocks.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    ...entry.value.map((block) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              block['icon'] as String,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        title: Text(
                          block['title'] as String,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          block['subtitle'] as String,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        onTap: () {
                          onBlockSelected(block['type'] as String);
                        },
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
