import 'api_service.dart';
import 'package:flutter/material.dart';

class StubApiService implements ApiService {
  // 인메모리 데이터 저장소
  final Map<String, Map<String, dynamic>> _pages = {};
  final Map<String, List<Map<String, dynamic>>> _blocks = {};
  final Map<String, Map<String, dynamic>> _trash = {};  
  final Map<String, List<Map<String, dynamic>>> _trashBlocks = {};  
  
  StubApiService() {
    _initializeDummyData();
  }
  
  /// 초기 더미 데이터 생성
  void _initializeDummyData() {
    final now = DateTime.now();
    
    // 테스트를 위해 userId가 없는 공용 더미 데이터 생성 (또는 특정 테스트 ID 할당 가능)
    // 여기서는 userId가 없으면 모든 유저가 볼 수 있다고 가정하거나, 
    // 테스트 시 userId 체크를 유연하게 처리합니다.
    
    final page1Id = '1732358400000';
    _pages[page1Id] = {
      'id': page1Id,
      'title': 'Notion 클론 프로젝트',
      'lastEdited': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'isFavorite': true,
      'userId': 'test_user', // 예시 userId
    };
    // ... (기타 더미 데이터는 필요에 따라 userId 추가)
    
    _blocks[page1Id] = [
      {'type': 'title', 'content': 'Notion 클론 프로젝트'},
      {'type': 'text', 'content': ''},
    ];
  }
  
  Future<void> _simulateNetworkDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  // =========================================================
  // ✅ 모든 메서드에 String userId 추가 및 필터링 로직 적용
  // =========================================================

  @override
  Future<List<Map<String, dynamic>>> fetchPages(String userId) async {
    debugPrint('📡 [Stub API] fetchPages 호출 (User: $userId)');
    await _simulateNetworkDelay();
    
    // 해당 유저의 페이지 + userId가 없는 공용 페이지(초기 더미) 반환
    final pages = _pages.values.where((p) => p['userId'] == userId || p['userId'] == null).toList();
    
    debugPrint('✅ [Stub API] ${pages.length}개 페이지 반환');
    return pages;
  }
  
  @override
  Future<Map<String, dynamic>> fetchPage(String pageId, String userId) async {
    debugPrint('📡 [Stub API] fetchPage 호출: $pageId');
    await _simulateNetworkDelay();
    
    if (!_pages.containsKey(pageId)) {
      throw Exception('페이지를 찾을 수 없습니다: $pageId');
    }
    
    final page = _pages[pageId]!;
    // 권한 체크 시뮬레이션
    if (page['userId'] != null && page['userId'] != userId) {
       throw Exception('접근 권한이 없습니다.');
    }

    return page;
  }
  
  @override
  Future<String> createPage(Map<String, dynamic> pageData, String userId) async {
    debugPrint('📡 [Stub API] createPage 호출');
    await _simulateNetworkDelay();
    
    final pageId = pageData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    _pages[pageId] = {
      'id': pageId,
      'title': pageData['title'] ?? '제목 없음',
      'lastEdited': DateTime.now().toIso8601String(),
      'isFavorite': pageData['isFavorite'] ?? false,
      'userId': userId, // ✅ 생성 시 UserID 저장
    };
    
    _blocks[pageId] = [
      {'type': 'title', 'content': pageData['title'] ?? '제목 없음'},
      {'type': 'text', 'content': ''},
    ];
    
    return pageId;
  }
  
  @override
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData, String userId) async {
    await _simulateNetworkDelay();
    if (_pages.containsKey(pageId)) {
      _pages[pageId] = {
        ..._pages[pageId]!,
        ...pageData,
        'lastEdited': DateTime.now().toIso8601String(),
      };
    }
  }
  
  @override
  Future<void> deletePage(String pageId, String userId) async {
    // 실제 삭제 대신 휴지통 이동을 권장하지만, 인터페이스 구현을 위해 남겨둠
    await moveToTrash(pageId, userId);
  }
  
  @override
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId, String userId) async {
    await _simulateNetworkDelay();
    final blocks = _blocks[pageId] ?? [];
    return List<Map<String, dynamic>>.from(blocks);
  }
  
  @override
  Future<void> saveBlocks(String pageId, List<Map<String, dynamic>> blocks, String userId) async {
    await _simulateNetworkDelay();
    _blocks[pageId] = List<Map<String, dynamic>>.from(blocks);
    
    // 제목 동기화
    final titleBlock = blocks.firstWhere((b) => b['type'] == 'title', orElse: () => {});
    if (titleBlock.isNotEmpty && _pages.containsKey(pageId)) {
      _pages[pageId]!['title'] = titleBlock['content'];
      _pages[pageId]!['lastEdited'] = DateTime.now().toIso8601String();
    }
  }
  
  @override
  Future<void> toggleFavorite(String pageId, bool isFavorite, String userId) async {
    await _simulateNetworkDelay();
    if (_pages.containsKey(pageId)) {
      _pages[pageId]!['isFavorite'] = isFavorite;
    }
  }

  // --- 휴지통 관련 ---

  @override
  Future<void> moveToTrash(String pageId, String userId) async {
    await _simulateNetworkDelay();
    if (!_pages.containsKey(pageId)) return;

    _trash[pageId] = {
      ..._pages[pageId]!,
      'deletedAt': DateTime.now().toIso8601String(),
    };
    
    if (_blocks.containsKey(pageId)) {
      _trashBlocks[pageId] = _blocks[pageId]!;
      _blocks.remove(pageId);
    }
    _pages.remove(pageId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchTrash(String userId) async {
    await _simulateNetworkDelay();
    // 해당 유저의 휴지통만 필터링
    return _trash.values.where((p) => p['userId'] == userId || p['userId'] == null).toList();
  }

  @override
  Future<void> restoreFromTrash(String pageId, String userId) async {
    await _simulateNetworkDelay();
    if (!_trash.containsKey(pageId)) return;

    final restoredPage = Map<String, dynamic>.from(_trash[pageId]!);
    restoredPage.remove('deletedAt');
    _pages[pageId] = restoredPage;

    if (_trashBlocks.containsKey(pageId)) {
      _blocks[pageId] = _trashBlocks[pageId]!;
      _trashBlocks.remove(pageId);
    }
    _trash.remove(pageId);
  }

  @override
  Future<void> permanentlyDelete(String pageId, String userId) async {
    await _simulateNetworkDelay();
    _trash.remove(pageId);
    _trashBlocks.remove(pageId);
  }

  @override
  Future<void> emptyTrash(String userId) async {
    await _simulateNetworkDelay();
    // 실제로는 해당 유저의 것만 지워야 하지만 Stub이므로 전체 삭제 혹은 필터링 삭제 구현
    _trash.removeWhere((key, value) => value['userId'] == userId);
  }

  // (이미지 업로드, 로그인 등 기타 메서드는 기존 스텁 유지)
  @override
  Future<String> uploadImage(String localFilePath) async {
     await Future.delayed(const Duration(milliseconds: 500));
     return 'https://picsum.photos/seed/stub/600/400';
  }
  
  @override
  Future<Map<String, dynamic>> register(String email, String password) async {
      // 간단 스텁
      return {'name': 'Stub User'};
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
      // 간단 스텁
      return {'name': 'Stub User'};
  }
}