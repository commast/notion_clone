// lib/repositories/page_repository.dart
import '../data/page_data.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';

class PageRepository {
  final ApiService _apiService;
  
  PageRepository(this._apiService);
  
  /// 모든 페이지 가져오기
  Future<List<PageData>> getAllPages() async {
    try {
      final pagesJson = await _apiService.fetchPages();
      
      return pagesJson.map((json) {
        return PageData(
          id: json['id'] as String,
          title: json['title'] as String,
          lastEdited: DateTime.parse(json['lastEdited'] as String),
          isFavorite: json['isFavorite'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ [Repository] getAllPages 실패: $e');
      rethrow;
    }
  }
  
  /// 특정 페이지 가져오기
  Future<PageData> getPage(String pageId) async {
    try {
      final pageJson = await _apiService.fetchPage(pageId);
      
      return PageData(
        id: pageJson['id'] as String,
        title: pageJson['title'] as String,
        lastEdited: DateTime.parse(pageJson['lastEdited'] as String),
        isFavorite: pageJson['isFavorite'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('❌ [Repository] getPage 실패: $e');
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
      });
      
      return pageId;
    } catch (e) {
      debugPrint('❌ [Repository] createPage 실패: $e');
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
      });
    } catch (e) {
      debugPrint('❌ [Repository] updatePage 실패: $e');
      rethrow;
    }
  }
  
  /// 페이지 삭제
  Future<void> deletePage(String pageId) async {
    try {
      await _apiService.deletePage(pageId);
    } catch (e) {
      debugPrint('❌ [Repository] deletePage 실패: $e');
      rethrow;
    }
  }
  
  /// 페이지의 블록들 가져오기
  Future<List<BlockData>> getBlocks(String pageId) async {
    try {
      final blocksJson = await _apiService.fetchBlocks(pageId);
      
      return blocksJson.map((json) {
        return BlockData(
          type: json['type'] as String,
          content: json['content'],
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ [Repository] getBlocks 실패: $e');
      rethrow;
    }
  }
  
  /// 블록들 저장
  Future<void> saveBlocks(String pageId, List<BlockData> blocks) async {
    try {
      final blocksJson = blocks.map((block) {
        return {
          'type': block.type,
          'content': block.content,
        };
      }).toList();
      
      await _apiService.saveBlocks(pageId, blocksJson);
    } catch (e) {
      debugPrint('❌ [Repository] saveBlocks 실패: $e');
      rethrow;
    }
  }
  
  /// 즐겨찾기 토글
  Future<void> toggleFavorite(String pageId, bool isFavorite) async {
    try {
      await _apiService.toggleFavorite(pageId, isFavorite);
    } catch (e) {
      debugPrint('❌ [Repository] toggleFavorite 실패: $e');
      rethrow;
    }
  }
  /// 휴지통으로 이동
  Future<void> moveToTrash(String pageId) async {
    try {
      await _apiService.moveToTrash(pageId);
    } catch (e) {
      debugPrint('❌ [Repository] moveToTrash 실패: $e');
      rethrow;
    }
  }

  /// 휴지통 목록 가져오기
  Future<List<PageData>> getTrash() async {
    try {
      final trashJson = await _apiService.fetchTrash();
      
      return trashJson.map((json) {
        return PageData(
          id: json['id'] as String,
          title: json['title'] as String,
          lastEdited: DateTime.parse(json['lastEdited'] as String),
          isFavorite: json['isFavorite'] as bool? ?? false,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ [Repository] getTrash 실패: $e');
      return [];
    }
  }

  /// 휴지통에서 복원
  Future<void> restoreFromTrash(String pageId) async {
    try {
      await _apiService.restoreFromTrash(pageId);
    } catch (e) {
      debugPrint('❌ [Repository] restoreFromTrash 실패: $e');
      rethrow;
    }
  }

  /// 영구 삭제
  Future<void> permanentlyDelete(String pageId) async {
    try {
      await _apiService.permanentlyDelete(pageId);
    } catch (e) {
      debugPrint('❌ [Repository] permanentlyDelete 실패: $e');
      rethrow;
    }
  }

  /// 휴지통 비우기
  Future<void> emptyTrash() async {
    try {
      await _apiService.emptyTrash();
    } catch (e) {
      debugPrint('❌ [Repository] emptyTrash 실패: $e');
      rethrow;
    }
  }
}
