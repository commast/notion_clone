import '../data/page_data.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:flutter/material.dart';
import '../services/firestore_api_service.dart';

class PageRepository {
  final ApiService _apiService;
  final AuthService _authService;

  PageRepository(this._apiService, this._authService);

  // 현재 사용자 ID 가져오기
  String get _userId => _authService.getCurrentUserId();

  /// 모든 페이지 가져오기
  Future<List<PageData>> getAllPages() async {
    final currentUserId = _userId;

    try {
      // 로그아웃 상태면 userId가 ''인 데이터(게스트 데이터)를 가져옴
      // 로그인 상태면 userId가 '내UID'인 데이터를 가져옴
      final pagesJson = await _apiService.fetchPages(currentUserId);

      return pagesJson.map((json) {
        return PageData(
          id: json['id'] as String,
          title: json['title'] as String,
          lastEdited: DateTime.parse(json['lastEdited'] as String),
          isFavorite: json['isFavorite'] as bool? ?? false,
          parentId: json['parentId'] as String?,
          teamSpaceId: json['teamSpaceId'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Repository] getAllPages 실패: $e');
      rethrow;
    }
  }

  /// 특정 페이지 가져오기
  Future<PageData> getPage(String pageId) async {
    try {
      final pageJson = await _apiService.fetchPage(pageId, _userId);
      return PageData(
        id: pageJson['id'] as String,
        title: pageJson['title'] as String,
        lastEdited: DateTime.parse(pageJson['lastEdited'] as String),
        isFavorite: pageJson['isFavorite'] as bool? ?? false,
        teamSpaceId: pageJson['teamSpaceId'] as String?,
      );
    } catch (e) {
      debugPrint('[Repository] getPage 실패: $e');
      rethrow;
    }
  }

  /// 새 페이지 생성
  Future<String> createPage(PageData page) async {
    try {
      
      final pageId = await _apiService.createPage({
        'id': page.id,
        'title': page.title,
        'lastEdited': page.lastEdited.toIso8601String(),
        'isFavorite': page.isFavorite,
        'parentId': page.parentId,
        'teamSpaceId': page.teamSpaceId,
      }, _userId);

      return pageId;
    } catch (e) {
      debugPrint('[Repository] createPage 실패: $e');
      rethrow;
    }
  }

  /// 페이지 업데이트
  Future<void> updatePage(PageData page) async {
    try {
      await _apiService.updatePage(page.id, {
        'title': page.title,
        'lastEdited': page.lastEdited.toIso8601String(),
        'isFavorite': page.isFavorite,
        'parentId': page.parentId,
        'teamSpaceId': page.teamSpaceId,
      }, _userId);
    } catch (e) {
      debugPrint('[Repository] updatePage 실패: $e');
      rethrow;
    }
  }

  /// 페이지 삭제
  Future<void> deletePage(String pageId) async {
    try {
      await _apiService.deletePage(pageId, _userId);
    } catch (e) {
      debugPrint('[Repository] deletePage 실패: $e');
      rethrow;
    }
  }

  /// 페이지의 블록들 가져오기
  Future<List<BlockData>> getBlocks(String pageId) async {
    try {
      final blocksJson = await _apiService.fetchBlocks(pageId, _userId);

      return blocksJson.map((json) {
        Color? textColor;
        Color? backgroundColor;
        if (json['textColor'] != null)
          textColor = Color(json['textColor'] as int);
        if (json['backgroundColor'] != null)
          backgroundColor = Color(json['backgroundColor'] as int);

        return BlockData(
          type: json['type'] as String,
          content: json['content'],
          textColor: textColor,
          backgroundColor: backgroundColor,
          targetPageId: json['targetPageId'] as String?,
          linkedPageId: json['linkedPageId'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Repository] getBlocks 실패: $e');
      rethrow;
    }
  }

  /// 블록들 저장
  Future<void> saveBlocks(String pageId, List<BlockData> blocks) async {
    try {
      final blocksJson = blocks.map((block) {
        dynamic content;

        if (block.type == 'chart') {
  final List<dynamic> items = (block.content as List?) ?? const [];

  content = items.map((e) {
    final map = Map<String, dynamic>.from(e as Map);
    final colorVal = map['color'];

    final result = {
      'label': map['label'],
      'value': map['value'],
      'color': colorVal is Color ? colorVal.value : colorVal,
      if (map['chartTitle'] != null) 'chartTitle': map['chartTitle'],
    };

    return result;
  }).toList();

  
  debugPrint('saveBlocks chart content: $content');
} else {
  content = block.content;
}


        return {
          'type': block.type,
          'content': content,
          'textColor': block.textColor?.value,
          'backgroundColor': block.backgroundColor?.value,
          'targetPageId': block.targetPageId,
          'linkedPageId': block.linkedPageId,
        };
      }).toList();

      await _apiService.saveBlocks(pageId, blocksJson, _userId);
    } catch (e) {
      debugPrint('[Repository] saveBlocks 실패: $e');
      rethrow;
    }
  }

  /// 즐겨찾기 토글
  Future<void> toggleFavorite(String pageId, bool isFavorite) async {
    try {
      await _apiService.toggleFavorite(pageId, isFavorite, _userId);
    } catch (e) {
      debugPrint('[Repository] toggleFavorite 실패: $e');
      rethrow;
    }
  }

  /// 휴지통으로 이동
  Future<void> moveToTrash(String pageId) async {
    try {
      await _apiService.moveToTrash(pageId, _userId);
    } catch (e) {
      debugPrint('[Repository] moveToTrash 실패: $e');
      rethrow;
    }
  }

  /// 휴지통 목록 가져오기
  Future<List<PageData>> getTrash() async {
    try {
      final trashJson = await _apiService.fetchTrash(_userId);
      return trashJson.map((json) {
        return PageData(
          id: json['id'] as String,
          title: json['title'] as String,
          lastEdited: DateTime.parse(json['lastEdited'] as String),
          isFavorite: json['isFavorite'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('[Repository] getTrash 실패: $e');
      return [];
    }
  }

  /// 휴지통에서 복원
  Future<void> restoreFromTrash(String pageId) async {
    try {
      await _apiService.restoreFromTrash(pageId, _userId);
    } catch (e) {
      debugPrint('[Repository] restoreFromTrash 실패: $e');
      rethrow;
    }
  }

  /// 영구 삭제
  Future<void> permanentlyDelete(String pageId) async {
    try {
      await _apiService.permanentlyDelete(pageId, _userId);
    } catch (e) {
      debugPrint('[Repository] permanentlyDelete 실패: $e');
      rethrow;
    }
  }

  /// 휴지통 비우기
  Future<void> emptyTrash() async {
    try {
      await _apiService.emptyTrash(_userId);
    } catch (e) {
      debugPrint('[Repository] emptyTrash 실패: $e');
      rethrow;
    }
  }

  // 이미지 업로드
  Future<String> uploadImage(String localFilePath) async {
    try {
      debugPrint('[Repository] uploadImage 요청: $localFilePath');
      final imageUrl = await _apiService.uploadImage(localFilePath);
      debugPrint('[Repository] 이미지 업로드 성공: $imageUrl');
      return imageUrl;
    } catch (e) {
      debugPrint('[Repository] uploadImage 실패: $e');
      rethrow;
    }
  }

  Future<void> promotePageToTeam({
    required String pageId,
    required List<String> memberUids,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw Exception('로그인 상태에서만 팀 페이지로 전환할 수 있습니다.');
    }

    final firestore = _apiService as FirestoreApiService;

    await firestore.promotePageToTeam(
      pageId: pageId,
      ownerUid: userId,
      memberUids: memberUids,
    );
  }

  Future<void> sharePageToExistingTeam({
    required String pageId,
    required String teamSpaceId,
    required List<String> memberUids,
  }) async {
    final userId = _userId;
    if (userId.isEmpty) {
      throw Exception('로그인 상태에서만 공유할 수 있습니다.');
    }

    final firestore = _apiService as FirestoreApiService;

    await firestore.sharePageToExistingTeam(
      pageId: pageId,
      teamSpaceId: teamSpaceId,
      actingUid: userId, // "실행자"
      memberUids: memberUids,
    );
  }
}
