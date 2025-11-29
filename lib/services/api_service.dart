// lib/services/api_service.dart

abstract class ApiService {
  // ==========================================
  // 페이지 및 블록 관리: userId 추가됨
  // ==========================================
  
  /// 모든 페이지 목록 가져오기
  Future<List<Map<String, dynamic>>> fetchPages(String userId); 
  
  /// 특정 페이지 가져오기
  Future<Map<String, dynamic>> fetchPage(String pageId, String userId); 
  
  /// 새 페이지 생성
  Future<String> createPage(Map<String, dynamic> pageData, String userId); 
  
  /// 페이지 업데이트
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData, String userId); 
  
  /// 페이지 삭제
  Future<void> deletePage(String pageId, String userId); 
  
  /// 특정 페이지의 블록들 가져오기
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId, String userId); 
  
  /// 블록 저장
  Future<void> saveBlocks(String pageId, List<Map<String, dynamic>> blocks, String userId); 
  
  /// 즐겨찾기 토글
  Future<void> toggleFavorite(String pageId, bool isFavorite, String userId); 


  // ==========================================
  // 휴지통 관련 메서드: userId 추가됨
  // ==========================================
  Future<void> moveToTrash(String pageId, String userId);
  Future<List<Map<String, dynamic>>> fetchTrash(String userId);
  Future<void> restoreFromTrash(String pageId, String userId);
  Future<void> permanentlyDelete(String pageId, String userId);
  Future<void> emptyTrash(String userId);
  
  // ==========================================
  // 기타 기능 (기존 유지)
  // ==========================================
  Future<String> uploadImage(String localFilePath);
  Future<Map<String, dynamic>> register(String email, String password);
  Future<Map<String, dynamic>> login(String email, String password);
}