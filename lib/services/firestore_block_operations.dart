import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreBlockOperations {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. 특정 페이지의 모든 블록 조회
  Future<List<Map<String, dynamic>>> getBlocks(String pageId) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .orderBy('order')
          .get();

      debugPrint('블록 조회: ${snapshot.docs.length}개 (페이지: $pageId)');

      // ✅ chart / pagelink 등 특수 타입은 여기서 한 번 변환해서 올려보낸다.
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final type = data['type'] as String?;
        final content = data['content'];

        dynamic fixedContent = content;

        if (type == 'chart' && content is List) {
          // Firestore에서 넘어오는 Map<String, dynamic> 리스트로 정제
          fixedContent = content
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        if (type == 'pagelink' && content is Map) {
          fixedContent = Map<String, dynamic>.from(content);
        }

        return {
          'id': doc.id,
          ...data,
          if (fixedContent != null) 'content': fixedContent,
        };
      }).toList();
    } catch (e) {
      debugPrint('getBlocks 실패: $e');
      return [];
    }
  }

  /// 2. 블록 추가
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

      // ✅ type 에 따라 content 를 Firestore-friendly 형태로 직렬화
      final serializedContent = _serializeContent(type, content);

      final docRef = await blocksRef.add({
        'type': type,
        'content': serializedContent,
        'order': order,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('블록 추가 완료: ${docRef.id} (타입: $type)');
      return docRef.id;
    } catch (e) {
      debugPrint('addBlock 실패: $e');
      rethrow;
    }
  }

  /// 3. 블록 내용 수정
  Future<void> updateBlockContent({
    required String pageId,
    required String blockId,
    required dynamic newContent,
    required String type, // ✅ 호출 쪽에서 type 같이 넘기도록
  }) async {
    try {
      final serializedContent = _serializeContent(type, newContent);

      await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .doc(blockId)
          .update({
        'content': serializedContent,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('블록 수정 완료: $blockId');
    } catch (e) {
      debugPrint('updateBlockContent 실패: $e');
      rethrow;
    }
  }

  /// 4. 블록 삭제
  Future<void> deleteBlock(String pageId, String blockId) async {
    try {
      await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .doc(blockId)
          .delete();

      debugPrint('블록 삭제 완료: $blockId');
    } catch (e) {
      debugPrint('deleteBlock 실패: $e');
      rethrow;
    }
  }

  /// 5. 모든 블록 일괄 저장
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
        final type = blocks[i]['type'] as String? ?? '';
        final rawContent = blocks[i]['content'];

        final serializedContent = _serializeContent(type, rawContent);

        batch.set(newDocRef, {
          ...blocks[i],
          'content': serializedContent,
          'order': i,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint('블록 일괄 저장 완료: ${blocks.length}개');
    } catch (e) {
      debugPrint('saveAllBlocks 실패: $e');
      rethrow;
    }
  }

  /// 6. 특정 타입의 블록만 조회
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

      debugPrint('블록 타입별 조회: ${snapshot.docs.length}개 (타입: $blockType)');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final content = data['content'];

        dynamic fixedContent = content;

        if (blockType == 'chart' && content is List) {
          fixedContent = content
              .whereType<Map>()
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        if (blockType == 'pagelink' && content is Map) {
          fixedContent = Map<String, dynamic>.from(content);
        }

        return {
          'id': doc.id,
          ...data,
          if (fixedContent != null) 'content': fixedContent,
        };
      }).toList();
    } catch (e) {
      debugPrint('getBlocksByType 실패: $e');
      return [];
    }
  }

  /// 7. 블록 개수 조회
  Future<int> getBlockCount(String pageId) async {
    try {
      final snapshot = await _firestore
          .collection('pages')
          .doc(pageId)
          .collection('blocks')
          .count()
          .get();

      final count = snapshot.count ?? 0;
      debugPrint('블록 개수: $count개 (페이지: $pageId)');
      return count;
    } catch (e) {
      debugPrint('getBlockCount 실패: $e');
      return 0;
    }
  }

  /// ✅ 타입별 content 직렬화 로직
  dynamic _serializeContent(String type, dynamic content) {
    if (type == 'chart' && content is List) {
      // NotionChart 의 onChanged 에서 이미 Color -> int 로 바뀐 리스트를 넘겨주도록 맞추는 게 베스트이지만,
      // 혹시 Color 가 남아 있으면 여기서 한 번 더 보정.
      return content.map((item) {
        if (item is Map<String, dynamic>) {
          final copy = Map<String, dynamic>.from(item);
          if (copy['color'] is Color) {
            copy['color'] = (copy['color'] as Color).value;
          }
          return copy;
        }
        return item;
      }).toList();
    }

    if (type == 'pagelink' && content is Map<String, dynamic>) {
      // { linkedPageId: ..., title: ... } 형태로 저장
      return Map<String, dynamic>.from(content);
    }

    // 그 외 타입은 그대로
    return content;
  }
}
