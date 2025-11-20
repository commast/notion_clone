import 'package:flutter/material.dart';

// ==========================================================
// 기존 블록 데이터 모델
// ==========================================================
class BlockData {
  final String type; // 블록의 종류 식별자
  dynamic content; // 블록의 실제 데이터

  BlockData({required this.type, this.content});
}

// ==========================================================
// ★ 새 페이지 메타데이터 모델
// ==========================================================
class PageMetadata {
  final String id;
  String title;
  PageMetadata({required this.id, required this.title});
}

// lib/data/page_data.dart
class PageData {
  final String id; // 나중에 상세 페이지 이동할 때 쓰기 좋음
  String title;
  DateTime lastEdited;

  PageData({required this.id, required this.title, required this.lastEdited});
}

// ==========================================================
// 전역 저장소 및 관리 로직
// ==========================================================
Map<String, List<BlockData>> _pageDataMap = {};

// 모든 페이지의 목록 (목록 화면에서 표시)
List<PageMetadata> allPages = [
  PageMetadata(id: 'personal_page', title: '개인 페이지'),
  PageMetadata(id: 'mobile_start_guide', title: '모바일에서 시작하기'),
];

// 특정 페이지의 블록 리스트를 가져오거나 초기화하는 함수
List<BlockData> getPageBlocks(String pageId) {
  if (!_pageDataMap.containsKey(pageId)) {
    debugPrint('새 페이지 초기화: $pageId');
    _pageDataMap[pageId] = [
      BlockData(type: 'title', content: '제목 없음'),
      BlockData(type: 'text', content: ''),
    ];
  }
  return _pageDataMap[pageId]!;
}

// ★ 새 페이지를 생성하고 리스트에 추가하는 함수
String addNewPage() {
  final newId = DateTime.now().millisecondsSinceEpoch.toString();
  final newTitle = '제목 없음';

  final newPageMetadata = PageMetadata(id: newId, title: newTitle);
  allPages.add(newPageMetadata);
  // getPageBlocks(newId) 호출 시 데이터가 초기화됩니다.

  return newId;
}
