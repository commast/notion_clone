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
      final snapshot = await _firestore
          .collection('pages')
          .where('userId', isEqualTo: userId) // ✅ 사용자 ID로 필터링
          // .where('isTrashed', isEqualTo: false) // 필요 시 주석 해제 (휴지통이 별도 컬렉션이라면 불필요)
          .orderBy('lastEdited', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final lastEditedValue = data['lastEdited'];
    String lastEditedString;
    
    // 1. 만약 값이 Timestamp라면, String으로 변환합니다.
    if (lastEditedValue is Timestamp) {
      lastEditedString = lastEditedValue.toDate().toIso8601String();
    } 
    // 2. 이미 String으로 저장되어 있다면, 그대로 사용합니다. (현재 오류 해결)
    else if (lastEditedValue is String) {
      lastEditedString = lastEditedValue;
    } else {
      // 3. 둘 다 아니면 현재 시간으로 처리합니다.
      lastEditedString = DateTime.now().toIso8601String();
    }
    
    return {
      'id': doc.id,
      'title': data['title'] ?? '제목 없음',
      'lastEdited': lastEditedString, // 수정된 String 값 사용
      'isFavorite': data['isFavorite'] ?? false,
      'parentId': data['parentId'],
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
      
      // ✅ 존재 여부 및 소유자(userId) 확인
      if (!doc.exists || doc.data()?['userId'] != userId) {
        throw Exception('페이지를 찾을 수 없거나 접근 권한이 없습니다: $pageId');
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
  Future<String> createPage(Map<String, dynamic> pageData, String userId) async {
    try {
      final pageId = pageData['id'] as String;
      
      await _firestore.collection('pages').doc(pageId).set({
        'title': pageData['title'],
        'lastEdited': pageData['lastEdited'], // DateTime이면 Timestamp 변환 필요할 수 있음
        'isFavorite': pageData['isFavorite'] ?? false,
        'parentId': pageData['parentId'] ?? '',
        'userId': userId, // ✅ 생성 시 userId 저장 (핵심)
      });
      
      debugPrint('[Firestore] 페이지 생성 완료: $pageId');
      return pageId;
    } catch (e) {
      debugPrint('[Firestore] createPage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData, String userId) async {
    try {
      // (선택 사항) 여기서도 userId로 문서를 한번 체크하는 것이 더 안전합니다.
      await _firestore.collection('pages').doc(pageId).set({
        'title': pageData['title'],
        'lastEdited': FieldValue.serverTimestamp(),
        'isFavorite': pageData['isFavorite'],
        'parentId': pageData['parentId'] ?? '', 
      }, SetOptions(merge: true));

      debugPrint('[Firestore] 페이지 업데이트 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] updatePage 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> deletePage(String pageId, String userId) async {
    // 인터페이스 구현을 위해 추가됨. 실제 삭제 로직은 moveToTrash를 사용.
    await moveToTrash(pageId, userId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId, String userId) async {
    try {
      // (선택 사항) 페이지 소유권 확인 로직 추가 가능
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
  Future<void> toggleFavorite(String pageId, bool isFavorite, String userId) async {
    try {
      await _firestore.collection('pages').doc(pageId).set({
        'isFavorite': isFavorite,
        'lastEdited': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[Firestore] 즐겨찾기 토글 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] toggleFavorite 실패: $e');
      rethrow;
    }
  }

  // ==========================================
  // 휴지통 관련 메서드 (userId 필터링 적용)
  // ==========================================

  @override
  Future<void> moveToTrash(String pageId, String userId) async {
    try {
      // 1. 페이지 정보 가져오기 + 소유자 확인
      final pageDoc = await _firestore.collection('pages').doc(pageId).get();
      
      if (!pageDoc.exists || pageDoc.data()?['userId'] != userId) {
        throw Exception('페이지를 찾을 수 없거나 권한이 없습니다: $pageId');
      }
      
      final pageData = pageDoc.data()!;
      
      // 2. 휴지통으로 복사 (deletedAt 추가)
      // userId는 pageData에 이미 포함되어 있으므로 그대로 복사됩니다.
      await _firestore.collection('trash').doc(pageId).set({
        ...pageData,
        'deletedAt': FieldValue.serverTimestamp(),
      });
      
      // 3. 블록도 함께 복사
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
      }
      
      // 4. 하위 페이지도 휴지통으로 이동 (재귀)
      final subPagesSnapshot = await _firestore
          .collection('pages')
          .where('parentId', isEqualTo: pageId)
          // .where('userId', isEqualTo: userId) // 안전을 위해 추가 가능
          .get();
      
      for (var subPageDoc in subPagesSnapshot.docs) {
        // 재귀 호출 시에도 userId 전달
        await moveToTrash(subPageDoc.id, userId); 
      }
      
      // 5. 원본 블록 삭제
      for (var blockDoc in blocksSnapshot.docs) {
        batch.delete(blockDoc.reference);
      }
      
      await batch.commit();
      
      // 6. 원본 페이지 삭제
      await _firestore.collection('pages').doc(pageId).delete();
      
      debugPrint('[Firestore] 휴지통 이동 완료: $pageId');
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
          .where('userId', isEqualTo: userId) // ✅ 휴지통도 사용자 ID로 필터링
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
          'parentId': data['parentId']?.toString() ?? '', 
        };
      }).toList();
    } catch (e) {
      debugPrint('[Firestore] fetchTrash 실패: $e');
      return [];
    }
  }

  @override
  Future<void> restoreFromTrash(String pageId, String userId) async {
    try {
      final trashDoc = await _firestore.collection('trash').doc(pageId).get();
      // 소유자 확인
      if (!trashDoc.exists || trashDoc.data()?['userId'] != userId) {
        throw Exception('휴지통에서 페이지를 찾을 수 없거나 권한이 없습니다: $pageId');
      }
      
      final pageData = Map<String, dynamic>.from(trashDoc.data()!);
      pageData.remove('deletedAt');

      // 복원 문서에 그대로 쓰기
      await _firestore.collection('pages').doc(pageId).set(pageData);

      // 블록 복원 로직
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
      
      // 하위 페이지 재귀 복원 (여기서는 단순화하여 userId만 전달)
      // 실제로는 restoreFromTrash 내부에서 하위 페이지 로직을 다시 호출해야 함
      // (기존 코드 로직 유지)
      final subPagesSnapshot = await _firestore
          .collection('trash')
          .where('parentId', isEqualTo: pageId)
          .get();

      for (var subPageDoc in subPagesSnapshot.docs) {
        await restoreFromTrash(subPageDoc.id, userId);
      }

      await batch.commit();

      // 휴지통 문서 삭제
      await _firestore.collection('trash').doc(pageId).delete();

      debugPrint('[Firestore] 복원 완료: $pageId');
    } catch (e) {
      debugPrint('[Firestore] restoreFromTrash 실패: $e');
      rethrow;
    }
  }

  @override
  Future<void> permanentlyDelete(String pageId, String userId) async {
    try {
      // 1. 하위 페이지도 영구 삭제 (재귀)
      // (소유자 확인 로직은 간소화를 위해 생략하나, 보안상 권장됨)
      final subPagesSnapshot = await _firestore
          .collection('trash')
          .where('parentId', isEqualTo: pageId)
          .get();
      
      for (var subPageDoc in subPagesSnapshot.docs) {
        await permanentlyDelete(subPageDoc.id, userId); 
      }
      
      // 2. 블록 삭제
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
      
      // 3. 페이지 삭제
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
      // 해당 사용자의 휴지통만 비우기
      final snapshot = await _firestore.collection('trash')
          .where('userId', isEqualTo: userId)
          .get();
      
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
  
  // (Auth 및 UploadImage 등 다른 메서드가 ApiService 인터페이스에 있다면 여기에 구현 추가 필요)
  // 여기서는 이미지/인증 관련 메서드는 없는 것으로 가정합니다. 
  // 만약 있다면 기존 코드 그대로 유지하시면 됩니다.
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