import 'package:cloud_firestore/cloud_firestore.dart';
import 'api_service.dart';
import 'package:flutter/material.dart';

class FirestoreApiService implements ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==========================================
  // 페이지 및 블록 관리: userId 필터링 적용
  // ==========================================

  @override
  Future<List<Map<String, dynamic>>> fetchPages(String userId) async {
    try {
      final fs = _firestore;

      // 1) 내가 멤버로 속한 팀 스페이스 ID들
      final memberSnap = await fs
          .collection('teamMembers')
          .where('userUid', isEqualTo: userId)
          .get();

      final teamSpaceIds = memberSnap.docs
          .map((d) => d['teamSpaceId'] as String)
          .toSet()
          .toList();

      // 2) 개인 페이지 (userId == 나, teamSpaceId == null)
      final personalSnap = await fs
          .collection('pages')
          .where('userId', isEqualTo: userId)
          .where('teamSpaceId', isNull: true)
          .orderBy('lastEdited', descending: true)
          .get();

      // 3) 팀 페이지 (내가 멤버인 teamSpace들)
      QuerySnapshot<Map<String, dynamic>>? teamSnap;
      if (teamSpaceIds.isNotEmpty) {
        teamSnap = await fs
            .collection('pages')
            .where('teamSpaceId', whereIn: teamSpaceIds)
            .orderBy('lastEdited', descending: true)
            .get();
      }

      // 4) 개인 + 팀 페이지 합치기
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
        ...personalSnap.docs,
        if (teamSnap != null) ...teamSnap.docs,
      ];

      return docs.map((doc) {
        final data = doc.data();
        final lastEditedValue = data['lastEdited'];
        String lastEditedString;

        if (lastEditedValue is Timestamp) {
          lastEditedString = lastEditedValue.toDate().toIso8601String();
        } else if (lastEditedValue is String) {
          lastEditedString = lastEditedValue;
        } else {
          lastEditedString = DateTime.now().toIso8601String();
        }

        return {
          'id': doc.id,
          'title': data['title'] ?? '제목 없음',
          'lastEdited': lastEditedString,
          'isFavorite': data['isFavorite'] ?? false,
          'parentId': data['parentId'] ?? '',
          'teamSpaceId': data['teamSpaceId'],
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] fetchPages 실패: $e');
      rethrow;
    }
  }


  @override
  Future<Map<String, dynamic>> fetchPage(String pageId, String userId) async {
    try {
      final doc = await _firestore.collection('pages').doc(pageId).get();
      
      if (!doc.exists || doc.data()?['userId'] != userId) {
        throw Exception('페이지를 찾을 수 없거나 접근 권한이 없습니다: $pageId');
      }

      final data = doc.data()!;
      final lastEditedValue = data['lastEdited'];
      String lastEditedString;
      
      if (lastEditedValue is Timestamp) {
        lastEditedString = lastEditedValue.toDate().toIso8601String();
      } else if (lastEditedValue is String) {
        lastEditedString = lastEditedValue;
      } else {
        lastEditedString = DateTime.now().toIso8601String();
      }
      
      return {
        'id': doc.id,
        'title': data['title'] ?? '제목 없음',
        'lastEdited': lastEditedString,
        'isFavorite': data['isFavorite'] ?? false,
        'parentId': data['parentId'] ?? '',
        'teamSpaceId': data['teamSpaceId'],
      };
    } catch (e) {
      debugPrint('[Firestore] fetchPage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<String> createPage(Map<String, dynamic> pageData, String userId) async {
    try {
      final pageId = pageData['id'] as String;
      
      await _firestore.collection('pages').doc(pageId).set({
        'title': pageData['title'],
        'lastEdited': pageData['lastEdited'],
        'isFavorite': pageData['isFavorite'] ?? false,
        'parentId': pageData['parentId'] ?? '',
        'teamSpaceId': pageData['teamSpaceId'],
        'userId': userId,
      });
      
      debugPrint('✅ [Firestore] 페이지 생성 완료: $pageId (parentId: ${pageData['parentId']})');
      return pageId;
    } catch (e) {
      debugPrint('[Firestore] createPage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData, String userId) async {
    try {
      final updateData = <String, dynamic>{
        'title': pageData['title'],
        'lastEdited': FieldValue.serverTimestamp(),
        'isFavorite': pageData['isFavorite'],
      };
      
      // ✅ parentId가 제공된 경우에만 업데이트
      if (pageData.containsKey('parentId')) {
        updateData['parentId'] = pageData['parentId'] ?? '';
      }
      if (pageData.containsKey('teamSpaceId')) {
        updateData['teamSpaceId'] = pageData['teamSpaceId'];
      }
      
      await _firestore.collection('pages').doc(pageId).update(updateData);
      
      debugPrint('[Firestore] 페이지 업데이트 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] updatePage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePage(String pageId, String userId) async {
    await moveToTrash(pageId, userId);
  }
  
  Future<void> promotePageToTeam({
    required String pageId,
    required String ownerUid,
    required List<String> memberUids,
  }) async {
    debugPrint('🔥 promotePageToTeam start: pageId=$pageId, owner=$ownerUid, members=$memberUids');
    final batch = _firestore.batch();

    final teamDoc = _firestore.collection('teamSpaces').doc();
    batch.set(teamDoc, {
      'name': '팀 페이지',
      'ownerUid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final membersCol = _firestore.collection('teamMembers');

    batch.set(membersCol.doc(), {
      'teamSpaceId': teamDoc.id,
      'userUid': ownerUid,
      'role': 'owner',
      'createdAt': FieldValue.serverTimestamp(),
    });

    for (final uid in memberUids) {
      batch.set(membersCol.doc(), {
        'teamSpaceId': teamDoc.id,
        'userUid': uid,
        'role': 'editor',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(_firestore.collection('pages').doc(pageId), {
      'teamSpaceId': teamDoc.id,
    });

    await batch.commit();
    debugPrint('🔥 promotePageToTeam batch committed');
  }


  @override
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId, String userId) async {
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
      return [];
    }
  }

  @override
  Future<void> saveBlocks(String pageId, List<Map<String, dynamic>> blocks, String userId) async {
    try {
      final batch = _firestore.batch();
      final blocksRef = _firestore.collection('pages').doc(pageId).collection('blocks');

      final existingBlocks = await blocksRef.get();
      for (var doc in existingBlocks.docs) {
        batch.delete(doc.reference);
      }

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
  Future<void> toggleFavorite(String pageId, bool isFavorite, String userId) async {
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

  // ==========================================
  // 휴지통 관련 메서드 (부모-자식 관계 유지)
  // ==========================================

  @override
Future<void> moveToTrash(String pageId, String userId) async {
  try {
    final pageDoc = await _firestore.collection('pages').doc(pageId).get();
    
    if (!pageDoc.exists || pageDoc.data()?['userId'] != userId) {
      throw Exception('페이지를 찾을 수 없거나 권한이 없습니다: $pageId');
    }
    
    final pageData = pageDoc.data()!;
    
    debugPrint('🗑️ [Firestore] 휴지통 이동 시작: $pageId (title: ${pageData['title']})');
    
    // ✅ 1단계: 먼저 하위 페이지를 재귀적으로 휴지통 이동 (중요!)
    final subPagesSnapshot = await _firestore
        .collection('pages')
        .where('parentId', isEqualTo: pageId)
        .where('userId', isEqualTo: userId)
        .get();
    
    debugPrint('  📦 하위 페이지 ${subPagesSnapshot.docs.length}개 발견');
    
    for (var subPageDoc in subPagesSnapshot.docs) {
      await moveToTrash(subPageDoc.id, userId);  // 재귀 호출
    }
    
    // ✅ 2단계: 현재 페이지를 휴지통으로 복사
    await _firestore.collection('trash').doc(pageId).set({
      ...pageData,
      'deletedAt': FieldValue.serverTimestamp(),
      'parentId': pageData['parentId'] ?? '',
    });
    
    debugPrint('  ✅ 휴지통에 복사: $pageId');
    
    // ✅ 3단계: 블록 복사 및 삭제
    final blocksSnapshot = await _firestore
        .collection('pages')
        .doc(pageId)
        .collection('blocks')
        .get();
    
    final batch = _firestore.batch();
    
    for (var blockDoc in blocksSnapshot.docs) {
      batch.set(
        _firestore.collection('trash').doc(pageId).collection('blocks').doc(blockDoc.id),
        blockDoc.data(),
      );
      batch.delete(blockDoc.reference);
    }
    
    await batch.commit();
    
    // ✅ 4단계: 원본 페이지 삭제
    await _firestore.collection('pages').doc(pageId).delete();
    
    debugPrint('  ✅ 원본 삭제 완료: $pageId');
    
  } catch (e) {
    debugPrint('[Firestore] moveToTrash 실패: $e');
    rethrow;
  }
}


  @override
Future<List<Map<String, dynamic>>> fetchTrash(String userId) async {
  try {
    final snapshot = await _firestore
        .collection('trash')
        .where('userId', isEqualTo: userId)
        .orderBy('deletedAt', descending: true)
        .get();

    debugPrint('📖 휴지통 전체 조회: ${snapshot.docs.length}개');
    
    // ✅ 최상위 부모만 필터링
    final allTrashIds = snapshot.docs.map((doc) => doc.id).toSet();
    final rootPages = <Map<String, dynamic>>[];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final parentId = data['parentId'] ?? '';
      
      if (parentId.isEmpty || !allTrashIds.contains(parentId)) {
        String safeDate(dynamic value) {
          if (value is Timestamp) return value.toDate().toIso8601String();
          if (value is String) return value;
          return DateTime.now().toIso8601String();
        }
        
        rootPages.add({
          'id': doc.id,
          'title': data['title'] ?? '제목 없음',
          'deletedAt': safeDate(data['deletedAt']),
          'lastEdited': safeDate(data['lastEdited']),
          'isFavorite': data['isFavorite'] ?? false,
          'parentId': parentId,
        });
      }
    }
    
    debugPrint('✅ 휴지통 최상위 페이지: ${rootPages.length}개');
    return rootPages;
  } catch (e) {
    debugPrint('[Firestore] fetchTrash 실패: $e');
    return [];
  }
}


  @override
  Future<void> restoreFromTrash(String pageId, String userId) async {
    try {
      final trashDoc = await _firestore.collection('trash').doc(pageId).get();
      
      if (!trashDoc.exists || trashDoc.data()?['userId'] != userId) {
        throw Exception('휴지통에서 페이지를 찾을 수 없거나 권한이 없습니다: $pageId');
      }
      
      final pageData = Map<String, dynamic>.from(trashDoc.data()!);
      pageData.remove('deletedAt');
      
      // ✅ parentId 명시적 보존
      final parentId = pageData['parentId'] ?? '';

      // 복원
      await _firestore.collection('pages').doc(pageId).set({
        ...pageData,
        'parentId': parentId,  // ✅ 부모 관계 유지
      });

      // 블록 복원
      final blocksSnapshot = await _firestore
          .collection('trash')
          .doc(pageId)
          .collection('blocks')
          .get();

      final batch = _firestore.batch();

      for (var blockDoc in blocksSnapshot.docs) {
        batch.set(
          _firestore.collection('pages').doc(pageId).collection('blocks').doc(blockDoc.id),
          blockDoc.data(),
        );
        batch.delete(blockDoc.reference);
      }
      
      // ✅ 하위 페이지 재귀 복원
      final subPagesSnapshot = await _firestore
          .collection('trash')
          .where('parentId', isEqualTo: pageId)
          .where('userId', isEqualTo: userId)
          .get();

      for (var subPageDoc in subPagesSnapshot.docs) {
        await restoreFromTrash(subPageDoc.id, userId);
      }

      await batch.commit();

      // 휴지통 문서 삭제
      await _firestore.collection('trash').doc(pageId).delete();

      debugPrint('✅ [Firestore] 복원 완료: $pageId (parentId: $parentId, 하위 페이지 포함)');
    } catch (e) {
      debugPrint('[Firestore] restoreFromTrash 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> permanentlyDelete(String pageId, String userId) async {
    try {
      // 하위 페이지 영구 삭제
      final subPagesSnapshot = await _firestore
          .collection('trash')
          .where('parentId', isEqualTo: pageId)
          .where('userId', isEqualTo: userId)
          .get();
      
      for (var subPageDoc in subPagesSnapshot.docs) {
        await permanentlyDelete(subPageDoc.id, userId);
      }
      
      // 블록 삭제
      final blocksSnapshot = await _firestore
          .collection('trash')
          .doc(pageId)
          .collection('blocks')
          .get();
      
      final batch = _firestore.batch();
      
      for (var blockDoc in blocksSnapshot.docs) {
        batch.delete(blockDoc.reference);
      }
      
      await batch.commit();
      
      // 페이지 삭제
      await _firestore.collection('trash').doc(pageId).delete();
      
      debugPrint('[Firestore] 영구 삭제 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] permanentlyDelete 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> emptyTrash(String userId) async {
    try {
      final snapshot = await _firestore.collection('trash')
          .where('userId', isEqualTo: userId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
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
  
  @override
  Future<String> uploadImage(String localFilePath) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'https://picsum.photos/seed/stub/600/400';
  }
  
  @override
  Future<Map<String, dynamic>> register(String email, String password) async {
    throw UnimplementedError(); 
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    throw UnimplementedError(); 
  }
}
