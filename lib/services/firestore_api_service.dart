// lib/services/firestore_api_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'package:flutter/material.dart';

class FirestoreApiService implements ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<List<Map<String, dynamic>>> fetchPages() async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .orderBy('lastEdited', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '제목 없음',
          'lastEdited': (data['lastEdited'] as Timestamp).toDate().toIso8601String(),
          'isFavorite': data['isFavorite'] ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] fetchPages 실패: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> fetchPage(String pageId) async {
    try {
      final doc = await _firestore.collection('pages').doc(pageId).get();
      
      if (!doc.exists) {
        throw Exception('페이지를 찾을 수 없습니다: $pageId');
      }

      final data = doc.data()!;
      return {
        'id': doc.id,
        'title': data['title'] ?? '제목 없음',
        'lastEdited': (data['lastEdited'] as Timestamp).toDate().toIso8601String(),
        'isFavorite': data['isFavorite'] ?? false,
      };
    } catch (e) {
      debugPrint('[Firestore] fetchPage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<String> createPage(Map<String, dynamic> pageData) async {
    try {
      final docRef = await _firestore.collection('pages').add({
        'title': pageData['title'] ?? '제목 없음',
        'lastEdited': FieldValue.serverTimestamp(),
        'isFavorite': pageData['isFavorite'] ?? false,
      });

      debugPrint('[Firestore] 페이지 생성 완료: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      debugPrint('[Firestore] createPage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData) async {
    try {
      await _firestore.collection('pages').doc(pageId).update({
        'title': pageData['title'],
        'lastEdited': FieldValue.serverTimestamp(),
        'isFavorite': pageData['isFavorite'],
      });

      debugPrint('[Firestore] 페이지 업데이트 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] updatePage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePage(String pageId) async {
    try {
      // 페이지 삭제
      await _firestore.collection('pages').doc(pageId).delete();
      
      // 해당 페이지의 블록들도 삭제
      final blocksSnapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .get();

      for (var doc in blocksSnapshot.docs) {
        await doc.reference.delete();
      }

      debugPrint('[Firestore] 페이지 삭제 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] deletePage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .orderBy('order')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'type': data['type'] ?? 'text',
          'content': data['content'] ?? '',
          'textColor': data['textColor'],
          'backgroundColor': data['backgroundColor'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] fetchBlocks 실패: $e');
      // 블록이 없으면 빈 리스트 반환
      return [];
    }
  }

  @override
  Future<void> saveBlocks(String pageId, List<Map<String, dynamic>> blocks) async {
    try {
      final batch = _firestore.batch();
      final blocksRef = _firestore.collection('pages').doc(pageId).collection('blocks');

      // 기존 블록 전체 삭제
      final existingBlocks = await blocksRef.get();
      for (var doc in existingBlocks.docs) {
        batch.delete(doc.reference);
      }

      // 새 블록 저장
      for (int i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        final newDocRef = blocksRef.doc();
        batch.set(newDocRef, {
          'type': block['type'],
          'content': block['content'],
          'textColor': block['textColor'],
          'backgroundColor': block['backgroundColor'],
          'order': i,
        });
      }

      await batch.commit();
      debugPrint('[Firestore] 블록 저장 완료: $pageId (${blocks.length}개)');
    } catch (e) {
      debugPrint('[Firestore] saveBlocks 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> toggleFavorite(String pageId, bool isFavorite) async {
    try {
      await _firestore.collection('pages').doc(pageId).update({
        'isFavorite': isFavorite,
        'lastEdited': FieldValue.serverTimestamp(),
      });

      debugPrint('[Firestore] 즐겨찾기 토글 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] toggleFavorite 실패: $e');
      rethrow;
    }
  }
  // FirestoreApiService 클래스에 추가

  /// 페이지를 휴지통으로 이동 (삭제 대신)
  Future<void> moveToTrash(String pageId) async {
    try {
      // 1. 원본 페이지 데이터 가져오기
      final pageDoc = await _firestore.collection('pages').doc(pageId).get();
      
      if (!pageDoc.exists) {
        throw Exception('페이지를 찾을 수 없습니다: $pageId');
      }

      final pageData = pageDoc.data()!;

      // 2. 휴지통에 복사
      await _firestore.collection('trash').doc(pageId).set({
        ...pageData,
        'deletedAt': FieldValue.serverTimestamp(),
        'originalId': pageId,
      });

      // 3. 원본 페이지 삭제
      await _firestore.collection('pages').doc(pageId).delete();

      // 4. 블록도 함께 이동
      final blocksSnapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .get();

      final batch = _firestore.batch();
      for (var blockDoc in blocksSnapshot.docs) {
        // 휴지통에 블록 복사
        final trashBlockRef = _firestore
            .collection('trash')
            .doc(pageId)
            .collection('blocks')
            .doc(blockDoc.id);
        batch.set(trashBlockRef, blockDoc.data());
        
        // 원본 블록 삭제
        batch.delete(blockDoc.reference);
      }
      await batch.commit();

      debugPrint('[Firestore] 휴지통 이동 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] moveToTrash 실패: $e');
      rethrow;
    }
  }

  /// 휴지통 목록 조회
  Future<List<Map<String, dynamic>>> fetchTrash() async {
    try {
      final snapshot = await _firestore
          .collection('trash')
          .orderBy('deletedAt', descending: true)
          .get();

      debugPrint('📖 휴지통 조회: ${snapshot.docs.length}개');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? '제목 없음',
          'deletedAt': (data['deletedAt'] as Timestamp).toDate().toIso8601String(),
          'lastEdited': (data['lastEdited'] as Timestamp).toDate().toIso8601String(),
          'isFavorite': data['isFavorite'] ?? false,
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] fetchTrash 실패: $e');
      return [];
    }
  }

  /// 휴지통에서 복원
  Future<void> restoreFromTrash(String pageId) async {
    try {
      // 1. 휴지통에서 데이터 가져오기
      final trashDoc = await _firestore.collection('trash').doc(pageId).get();
      
      if (!trashDoc.exists) {
        throw Exception('휴지통에서 페이지를 찾을 수 없습니다: $pageId');
      }

      final pageData = trashDoc.data()!;
      pageData.remove('deletedAt');
      pageData.remove('originalId');

      // 2. pages 컬렉션에 복원
      await _firestore.collection('pages').doc(pageId).set({
        ...pageData,
        'lastEdited': FieldValue.serverTimestamp(),
      });

      // 3. 블록도 복원
      final trashBlocksSnapshot = await _firestore
          .collection('trash')
          .doc(pageId)
          .collection('blocks')
          .get();

      final batch = _firestore.batch();
      for (var blockDoc in trashBlocksSnapshot.docs) {
        final pageBlockRef = _firestore
            .collection('pages')
            .doc(pageId)
            .collection('blocks')
            .doc(blockDoc.id);
        batch.set(pageBlockRef, blockDoc.data());
        
        // 휴지통 블록 삭제
        batch.delete(blockDoc.reference);
      }

      // 4. 휴지통에서 삭제
      batch.delete(_firestore.collection('trash').doc(pageId));
      
      await batch.commit();

      debugPrint('[Firestore] 복원 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] restoreFromTrash 실패: $e');
      rethrow;
    }
  }

  /// 휴지통에서 영구 삭제
  Future<void> permanentlyDelete(String pageId) async {
    try {
      // 블록 삭제
      final blocksSnapshot = await _firestore
          .collection('trash')
          .doc(pageId)
          .collection('blocks')
          .get();

      final batch = _firestore.batch();
      for (var doc in blocksSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 페이지 삭제
      batch.delete(_firestore.collection('trash').doc(pageId));
      
      await batch.commit();

      debugPrint('[Firestore] 영구 삭제 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] permanentlyDelete 실패: $e');
      rethrow;
    }
  }

  /// 휴지통 전체 비우기
  Future<void> emptyTrash() async {
    try {
      final snapshot = await _firestore.collection('trash').get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        // 각 페이지의 블록도 삭제
        final blocksSnapshot = await _firestore
            .collection('trash')
            .doc(doc.id)
            .collection('blocks')
            .get();
        
        for (var blockDoc in blocksSnapshot.docs) {
          batch.delete(blockDoc.reference);
        }
        
        batch.delete(doc.reference);
      }
      
      await batch.commit();

      debugPrint('[Firestore] 휴지통 비우기 완료: ${snapshot.docs.length}개 삭제');
    } catch (e) {
      debugPrint('[Firestore] emptyTrash 실패: $e');
      rethrow;
    }
  }
}
