// lib/services/firestore_realtime_operations.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreRealtimeOperations {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 1. 페이지 목록 실시간 감지
  Stream<List<Map<String, dynamic>>> watchAllPages() {
    return _firestore
        .collection('pages')
        .orderBy('lastEdited', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('🔄 실시간 페이지 업데이트: ${snapshot.docs.length}개');
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  /// 2. 특정 페이지 실시간 감지
  Stream<Map<String, dynamic>> watchPage(String pageId) {
    return _firestore
        .collection('pages')
        .doc(pageId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) {
        throw Exception('페이지를 찾을 수 없습니다: $pageId');
      }
      debugPrint('🔄 실시간 페이지 업데이트: $pageId');
      return {
        'id': doc.id,
        ...doc.data()!,
      };
    });
  }

  /// 3. 블록 목록 실시간 감지
  Stream<List<Map<String, dynamic>>> watchBlocks(String pageId) {
    return _firestore
        .collection('pages')
        .doc(pageId)
        .collection('blocks')
        .orderBy('order')
        .snapshots()
        .map((snapshot) {
      debugPrint('🔄 실시간 블록 업데이트: ${snapshot.docs.length}개');
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  /// 4. 즐겨찾기 페이지 실시간 감지
  Stream<List<Map<String, dynamic>>> watchFavoritePages() {
    return _firestore
        .collection('pages')
        .where('isFavorite', isEqualTo: true)
        .orderBy('lastEdited', descending: true)
        .snapshots()
        .map((snapshot) {
      debugPrint('🔄 실시간 즐겨찾기 업데이트: ${snapshot.docs.length}개');
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }
}
