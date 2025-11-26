// lib/services/stub_api_service.dart
import 'api_service.dart';
import 'package:flutter/material.dart';


class StubApiService implements ApiService {
  // 인메모리 데이터 저장소
  final Map<String, Map<String, dynamic>> _pages = {};
  final Map<String, List<Map<String, dynamic>>> _blocks = {};
  final Map<String, Map<String, dynamic>> _trash = {};  // ✅ 추가: 휴지통 저장소
  final Map<String, List<Map<String, dynamic>>> _trashBlocks = {};  // ✅ 추가: 휴지통 블록
  
  StubApiService() {
    _initializeDummyData();
  }
  
  /// 초기 더미 데이터 생성
  void _initializeDummyData() {
    final now = DateTime.now();
    
    // 더미 페이지 1
    final page1Id = '1732358400000'; // 임의의 ID
    _pages[page1Id] = {
      'id': page1Id,
      'title': 'Notion 클론 프로젝트',
      'lastEdited': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'isFavorite': true,
    };
    
    // 더미 페이지 2
    final page2Id = '1732358500000';
    _pages[page2Id] = {
      'id': page2Id,
      'title': 'Flutter 학습 노트',
      'lastEdited': now.subtract(const Duration(days: 1)).toIso8601String(),
      'isFavorite': false,
    };
    
    // 더미 페이지 3
    final page3Id = '1732358600000';
    _pages[page3Id] = {
      'id': page3Id,
      'title': '회의록 2025.11.23',
      'lastEdited': now.subtract(const Duration(hours: 5)).toIso8601String(),
      'isFavorite': false,
    };
    
    // 페이지 1의 블록들
    _blocks[page1Id] = [
      {'type': 'title', 'content': 'Notion 클론 프로젝트'},
      {'type': 'text', 'content': ''},
      {'type': 'heading1', 'content': '프로젝트 개요'},
      {'type': 'text', 'content': 'Flutter로 Notion 클론 앱을 개발하는 프로젝트입니다.'},
      {'type': 'heading2', 'content': '주요 기능'},
      {'type': 'bulleted_list', 'content': '페이지 생성 및 관리'},
      {'type': 'bulleted_list', 'content': '다양한 블록 타입 지원'},
      {'type': 'bulleted_list', 'content': '즐겨찾기 기능'},
      {'type': 'divider', 'content': null},
      {'type': 'todo_list', 'content': {'checked': true, 'text': '기본 UI 구현'}},
      {'type': 'todo_list', 'content': {'checked': true, 'text': '블록 시스템 구현'}},
      {'type': 'todo_list', 'content': {'checked': false, 'text': 'Stub 서버 연동'}},
    ];
    
    // 페이지 2의 블록들
    _blocks[page2Id] = [
      {'type': 'title', 'content': 'Flutter 학습 노트'},
      {'type': 'text', 'content': ''},
      {'type': 'heading1', 'content': 'Provider 패턴'},
      {'type': 'text', 'content': '상태 관리를 위한 Provider 패턴을 학습합니다.'},
    ];
    
    // 페이지 3의 블록들
    _blocks[page3Id] = [
      {'type': 'title', 'content': '회의록 2025.11.23'},
      {'type': 'text', 'content': ''},
    ];
  }
  
  /// 네트워크 지연 시뮬레이션
  Future<void> _simulateNetworkDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  @override
  Future<List<Map<String, dynamic>>> fetchPages() async {
    debugPrint('📡 [Stub API] fetchPages 호출');
    await _simulateNetworkDelay();
    
    final pages = _pages.values.toList();
    debugPrint('✅ [Stub API] ${pages.length}개 페이지 반환');
    return pages;
  }
  
  @override
  Future<Map<String, dynamic>> fetchPage(String pageId) async {
    debugPrint('📡 [Stub API] fetchPage 호출: $pageId');
    await _simulateNetworkDelay();
    
    if (!_pages.containsKey(pageId)) {
      throw Exception('페이지를 찾을 수 없습니다: $pageId');
    }
    
    final page = _pages[pageId]!;
    debugPrint('✅ [Stub API] 페이지 반환: ${page['title']}');
    return page;
  }
  
  @override
  Future<String> createPage(Map<String, dynamic> pageData) async {
    debugPrint('📡 [Stub API] createPage 호출: ${pageData['title']}');
    await _simulateNetworkDelay();
    
    final pageId = pageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    _pages[pageId] = {
      'id': pageId,
      'title': pageData['title'] ?? '제목 없음',
      'lastEdited': DateTime.now().toIso8601String(),
      'isFavorite': pageData['isFavorite'] ?? false,
    };
    
    // 기본 블록 생성
    _blocks[pageId] = [
      {'type': 'title', 'content': pageData['title'] ?? '제목 없음'},
      {'type': 'text', 'content': ''},
    ];
    
    debugPrint('✅ [Stub API] 페이지 생성 완료: $pageId');
    return pageId;
  }
  
  @override
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData) async {
    debugPrint('📡 [Stub API] updatePage 호출: $pageId');
    await _simulateNetworkDelay();
    
    if (!_pages.containsKey(pageId)) {
      throw Exception('페이지를 찾을 수 없습니다: $pageId');
    }
    
    _pages[pageId] = {
      ..._pages[pageId]!,
      ...pageData,
      'lastEdited': DateTime.now().toIso8601String(),
    };
    
    debugPrint('✅ [Stub API] 페이지 업데이트 완료');
  }
  
  @override
  Future<void> deletePage(String pageId) async {
    debugPrint('📡 [Stub API] deletePage 호출: $pageId');
    await _simulateNetworkDelay();
    
    _pages.remove(pageId);
    _blocks.remove(pageId);
    
    debugPrint('✅ [Stub API] 페이지 삭제 완료');
  }
  
  @override
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId) async {
    debugPrint('📡 [Stub API] fetchBlocks 호출: $pageId');
    await _simulateNetworkDelay();
    
    final blocks = _blocks[pageId] ?? [];
    debugPrint('✅ [Stub API] ${blocks.length}개 블록 반환');
    return List<Map<String, dynamic>>.from(blocks);
  }
  
  @override
  Future<void> saveBlocks(String pageId, List<Map<String, dynamic>> blocks) async {
    debugPrint('📡 [Stub API] saveBlocks 호출: $pageId (${blocks.length}개)');
    await _simulateNetworkDelay();
    
    _blocks[pageId] = List<Map<String, dynamic>>.from(blocks);
    
    // 제목 블록이 있으면 페이지 제목도 업데이트
    final titleBlock = blocks.firstWhere(
      (block) => block['type'] == 'title',
      orElse: () => {},
    );
    
    if (titleBlock.isNotEmpty && _pages.containsKey(pageId)) {
      _pages[pageId]!['title'] = titleBlock['content'] ?? '제목 없음';
      _pages[pageId]!['lastEdited'] = DateTime.now().toIso8601String();
    }
    
    debugPrint('✅ [Stub API] 블록 저장 완료');
  }
  
  @override
  Future<void> toggleFavorite(String pageId, bool isFavorite) async {
    debugPrint('📡 [Stub API] toggleFavorite 호출: $pageId -> $isFavorite');
    await _simulateNetworkDelay();
    
    if (!_pages.containsKey(pageId)) {
      throw Exception('페이지를 찾을 수 없습니다: $pageId');
    }
    
    _pages[pageId]!['isFavorite'] = isFavorite;
    _pages[pageId]!['lastEdited'] = DateTime.now().toIso8601String();
    
    debugPrint('✅ [Stub API] 즐겨찾기 업데이트 완료');
  }

  // ✅ 아래 휴지통 관련 메서드 추가

  @override
  Future<void> moveToTrash(String pageId) async {
    debugPrint('📡 [Stub API] moveToTrash 호출: $pageId');
    await _simulateNetworkDelay();
    
    if (!_pages.containsKey(pageId)) {
      throw Exception('페이지를 찾을 수 없습니다: $pageId');
    }
    
    // 휴지통으로 이동
    _trash[pageId] = {
      ..._pages[pageId]!,
      'deletedAt': DateTime.now().toIso8601String(),
    };
    
    // 블록도 함께 이동
    if (_blocks.containsKey(pageId)) {
      _trashBlocks[pageId] = _blocks[pageId]!;
      _blocks.remove(pageId);
    }
    
    // 원본 페이지 삭제
    _pages.remove(pageId);
    
    debugPrint('✅ [Stub API] 휴지통 이동 완료');
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrash() async {
    debugPrint('📡 [Stub API] fetchTrash 호출');
    await _simulateNetworkDelay();
    
    final trashPages = _trash.values.toList();
    debugPrint('✅ [Stub API] ${trashPages.length}개 휴지통 페이지 반환');
    return trashPages;
  }

  @override
  Future<void> restoreFromTrash(String pageId) async {
    debugPrint('📡 [Stub API] restoreFromTrash 호출: $pageId');
    await _simulateNetworkDelay();
    
    if (!_trash.containsKey(pageId)) {
      throw Exception('휴지통에서 페이지를 찾을 수 없습니다: $pageId');
    }
    
    // 페이지 복원
    final restoredPage = Map<String, dynamic>.from(_trash[pageId]!);
    restoredPage.remove('deletedAt');
    restoredPage['lastEdited'] = DateTime.now().toIso8601String();
    _pages[pageId] = restoredPage;
    
    // 블록도 복원
    if (_trashBlocks.containsKey(pageId)) {
      _blocks[pageId] = _trashBlocks[pageId]!;
      _trashBlocks.remove(pageId);
    }
    
    // 휴지통에서 제거
    _trash.remove(pageId);
    
    debugPrint('✅ [Stub API] 페이지 복원 완료');
  }

  @override
  Future<void> permanentlyDelete(String pageId) async {
    debugPrint('📡 [Stub API] permanentlyDelete 호출: $pageId');
    await _simulateNetworkDelay();
    
    _trash.remove(pageId);
    _trashBlocks.remove(pageId);
    
    debugPrint('✅ [Stub API] 영구 삭제 완료');
  }

  @override
  Future<void> emptyTrash() async {
    debugPrint('📡 [Stub API] emptyTrash 호출');
    await _simulateNetworkDelay();
    
    final count = _trash.length;
    _trash.clear();
    _trashBlocks.clear();
    
    debugPrint('✅ [Stub API] 휴지통 비우기 완료: $count개 삭제');
  }
}
