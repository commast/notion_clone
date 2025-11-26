// lib/services/firestore_operations.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreOperations {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. 모든 페이지 조회 (READ)
  Future<List<Map<String, dynamic>>> getAllPages() async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .orderBy('lastEdited', descending: true)
          .get();

      debugPrint('📖 전체 페이지 조회: ${snapshot.docs.length}개');
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getAllPages 실패: $e');
      rethrow;
    }
  }

  /// 2. 특정 페이지 조회 (READ)
  Future<Map<String, dynamic>> getPageById(String pageId) async {
    try {
      final doc = await _firestore
          .collection('pages')
          .doc(pageId)
          .get();

      if (!doc.exists) {
        throw Exception('페이지를 찾을 수 없습니다: $pageId');
      }

      debugPrint('📖 페이지 조회 성공: $pageId');
      return {
        'id': doc.id,
        ...doc.data()!,
      };
    } catch (e) {
      debugPrint('❌ getPageById 실패: $e');
      rethrow;
    }
  }

  /// 3. 새 페이지 생성 (CREATE)
  Future<String> createPage({
    required String title,
    bool isFavorite = false,
  }) async {
    try {
      final docRef = await _firestore.collection('pages').add({
        'title': title,
        'lastEdited': FieldValue.serverTimestamp(),
        'isFavorite': isFavorite,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 페이지 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ createPage 실패: $e');
      rethrow;
    }
  }

  /// 4. 페이지 제목 수정 (UPDATE)
  Future<void> updatePageTitle(String pageId, String newTitle) async {
    try {
      await _firestore.collection('pages').doc(pageId).update({
        'title': newTitle,
        'lastEdited': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 페이지 제목 수정 완료: $pageId');
    } catch (e) {
      debugPrint('❌ updatePageTitle 실패: $e');
      rethrow;
    }
  }

  /// 5. 즐겨찾기 토글 (UPDATE)
  Future<void> toggleFavorite(String pageId, bool isFavorite) async {
    try {
      await _firestore.collection('pages').doc(pageId).update({
        'isFavorite': isFavorite,
        'lastEdited': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 즐겨찾기 토글 완료: $pageId → $isFavorite');
    } catch (e) {
      debugPrint('❌ toggleFavorite 실패: $e');
      rethrow;
    }
  }

  /// 6. 페이지 삭제 (DELETE)
  Future<void> deletePage(String pageId) async {
    try {
      // 하위 블록도 함께 삭제
      final blocksSnapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .get();

      final batch = _firestore.batch();

      // 블록 삭제
      for (var doc in blocksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 페이지 삭제
      batch.delete(_firestore.collection('pages').doc(pageId));

      await batch.commit();
      debugPrint('✅ 페이지 삭제 완료: $pageId (블록 ${blocksSnapshot.docs.length}개 포함)');
    } catch (e) {
      debugPrint('❌ deletePage 실패: $e');
      rethrow;
    }
  }

  /// 7. 즐겨찾기 페이지만 조회 (QUERY)
  Future<List<Map<String, dynamic>>> getFavoritePages() async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .where('isFavorite', isEqualTo: true)
          .orderBy('lastEdited', descending: true)
          .get();

      debugPrint('⭐ 즐겨찾기 페이지 조회: ${snapshot.docs.length}개');
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getFavoritePages 실패: $e');
      rethrow;
    }
  }

  /// 8. 제목으로 페이지 검색 (QUERY)
  Future<List<Map<String, dynamic>>> searchPagesByTitle(String keyword) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .orderBy('title')
          .startAt([keyword])
          .endAt(['$keyword\uf8ff'])
          .get();

      debugPrint('🔍 페이지 검색 결과: ${snapshot.docs.length}개 (키워드: $keyword)');
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ searchPagesByTitle 실패: $e');
      rethrow;
    }
  }

  /// 9. 최근 수정된 페이지 조회 (QUERY)
  Future<List<Map<String, dynamic>>> getRecentPages({int limit = 5}) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .orderBy('lastEdited', descending: true)
          .limit(limit)
          .get();

      debugPrint('🕒 최근 페이지 조회: ${snapshot.docs.length}개');
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getRecentPages 실패: $e');
      rethrow;
    }
  }

  /// 10. 페이지 개수 조회 (AGGREGATE)
  Future<int> getTotalPageCount() async {
    try {
      final snapshot = await _firestore.collection('pages').count().get();
      final count = snapshot.count ?? 0;
      
      debugPrint('📊 전체 페이지 개수: $count개');
      return count;
    } catch (e) {
      debugPrint('❌ getTotalPageCount 실패: $e');
      rethrow;
    }
  }
}
