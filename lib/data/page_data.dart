import 'package:flutter/material.dart';

// 기존 블록 데이터 모델
class BlockData {
  final String type; // 블록의 종류 식별자
  dynamic content; // 블록의 실제 데이터

  BlockData({required this.type, this.content});
}

// 페이지 메타데이터 모델
class PageMetadata {
  final String id;
  String title;
  PageMetadata({required this.id, required this.title});
}

// 페이지 데이터 모델
class PageData {
  final String id; // 고유 식별자
  String title; // 페이지 제목
  DateTime lastEdited; // 마지막 편집 시간
  bool isFavorite; // 즐겨찾기 여부
  bool isExpanded; // 확장 상태 (하위 페이지 표시 여부)
  List<PageData> subPages; // 하위 페이지 리스트
  PageData? parentPage; // 상위 페이지 참조

  PageData({
    required this.id,
    required this.title,
    required this.lastEdited,
    this.isFavorite = false,
    this.isExpanded = false,
    List<PageData>? subPages,
    this.parentPage,
  }) : subPages = subPages ?? [];

  // 복제를 위한 메서드
  PageData copyWith({
    String? id,
    String? title,
    DateTime? lastEdited,
    bool? isFavorite,
    bool? isExpanded,
    List<PageData>? subPages,
    PageData? parentPage,
  }) {
    return PageData(
      id: id ?? this.id,
      title: title ?? this.title,
      lastEdited: lastEdited ?? this.lastEdited,
      isFavorite: isFavorite ?? this.isFavorite,
      isExpanded: isExpanded ?? this.isExpanded,
      subPages: subPages ?? List.from(this.subPages),
      parentPage: parentPage ?? this.parentPage,
    );
  }

  // 들여쓰기 레벨 계산
  int get level {
    int count = 0;
    PageData? current = parentPage;
    while (current != null) {
      count++;
      current = current.parentPage;
    }
    return count;
  }
}

// 전역 저장소 및 관리 로직
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

// 새 페이지를 생성하고 리스트에 추가하는 함수
String addNewPage() {
  final newId = DateTime.now().millisecondsSinceEpoch.toString();
  final newTitle = '제목 없음';

  final newPageMetadata = PageMetadata(id: newId, title: newTitle);
  allPages.add(newPageMetadata);

  return newId;
}

// 페이지의 모든 텍스트 내용을 가져오는 함수
String getPageContent(String pageId) {
  final blocks = getPageBlocks(pageId);
  StringBuffer content = StringBuffer();
  
  for (var block in blocks) {
    if (block.type == 'title' || block.type == 'text') {
      if (block.content != null && block.content.toString().isNotEmpty) {
        content.write(block.content.toString());
        content.write(' ');
      }
    }
  }
  
  return content.toString();
}
