// lib/services/firestore_block_operations.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreBlockOperations {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. 특정 페이지의 모든 블록 조회 (READ)
  Future<List<Map<String, dynamic>>> getBlocks(String pageId) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .orderBy('order')
          .get();

      debugPrint('📖 블록 조회: ${snapshot.docs.length}개 (페이지: $pageId)');
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getBlocks 실패: $e');
      return [];
    }
  }

  /// 2. 블록 추가 (CREATE)
  Future<String> addBlock({
    required String pageId,
    required String type,
    required dynamic content,
    int? order,
  }) async {
    try {
      final blocksRef = _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks');

      // order가 없으면 마지막 순서 계산
      if (order == null) {
        final snapshot = await blocksRef.get();
        order = snapshot.docs.length;
      }

      final docRef = await blocksRef.add({
        'type': type,
        'content': content,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 블록 추가 완료: ${docRef.id} (타입: $type)');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ addBlock 실패: $e');
      rethrow;
    }
  }

  /// 3. 블록 내용 수정 (UPDATE)
  Future<void> updateBlockContent({
    required String pageId,
    required String blockId,
    required dynamic newContent,
  }) async {
    try {
      await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .doc(blockId)
          .update({
        'content': newContent,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ 블록 수정 완료: $blockId');
    } catch (e) {
      debugPrint('❌ updateBlockContent 실패: $e');
      rethrow;
    }
  }

  /// 4. 블록 삭제 (DELETE)
  Future<void> deleteBlock(String pageId, String blockId) async {
    try {
      await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .doc(blockId)
          .delete();

      debugPrint('✅ 블록 삭제 완료: $blockId');
    } catch (e) {
      debugPrint('❌ deleteBlock 실패: $e');
      rethrow;
    }
  }

  /// 5. 모든 블록 일괄 저장 (BATCH WRITE)
  Future<void> saveAllBlocks({
    required String pageId,
    required List<Map<String, dynamic>> blocks,
  }) async {
    try {
      final batch = _firestore.batch();
      final blocksRef = _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks');

      // 기존 블록 전체 삭제
      final existingBlocks = await blocksRef.get();
      for (var doc in existingBlocks.docs) {
        batch.delete(doc.reference);
      }

      // 새 블록 저장
      for (int i = 0; i < blocks.length; i++) {
        final newDocRef = blocksRef.doc();
        batch.set(newDocRef, {
          ...blocks[i],
          'order': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('✅ 블록 일괄 저장 완료: ${blocks.length}개');
    } catch (e) {
      debugPrint('❌ saveAllBlocks 실패: $e');
      rethrow;
    }
  }

  /// 6. 특정 타입의 블록만 조회 (QUERY)
  Future<List<Map<String, dynamic>>> getBlocksByType({
    required String pageId,
    required String blockType,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .where('type', isEqualTo: blockType)
          .orderBy('order')
          .get();

      debugPrint('📖 블록 타입별 조회: ${snapshot.docs.length}개 (타입: $blockType)');
      
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      debugPrint('❌ getBlocksByType 실패: $e');
      return [];
    }
  }

  /// 7. 블록 개수 조회 (AGGREGATE)
  Future<int> getBlockCount(String pageId) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .count()
          .get();
      
      final count = snapshot.count ?? 0;
      debugPrint('📊 블록 개수: $count개 (페이지: $pageId)');
      return count;
    } catch (e) {
      debugPrint('❌ getBlockCount 실패: $e');
      return 0;
    }
  }
}
