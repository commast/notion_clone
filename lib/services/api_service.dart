// lib/services/api_service.dart
abstract class ApiService {
  /// 모든 페이지 목록 가져오기
  Future<List<Map<String, dynamic>>> fetchPages();
  
  /// 특정 페이지 가져오기
  Future<Map<String, dynamic>> fetchPage(String pageId);
  
  /// 새 페이지 생성
  Future<String> createPage(Map<String, dynamic> pageData);
  
  /// 페이지 업데이트
  Future<void> updatePage(String pageId, Map<String, dynamic> pageData);
  
  /// 페이지 삭제
  Future<void> deletePage(String pageId);
  
  /// 특정 페이지의 블록들 가져오기
  Future<List<Map<String, dynamic>>> fetchBlocks(String pageId);
  
  /// 블록 저장
  Future<void> saveBlocks(String pageId, List<Map<String, dynamic>> blocks);
  
  /// 즐겨찾기 토글
  Future<void> toggleFavorite(String pageId, bool isFavorite);
}
