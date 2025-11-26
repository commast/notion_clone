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
}
