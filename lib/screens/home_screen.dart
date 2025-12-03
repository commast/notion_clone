import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 위젯들
import '../widgets/common/notion_bottom_bar.dart';
import '../widgets/home/recent_page_card.dart';
import '../widgets/home/personal_page_tile.dart';

// 데이터 및 화면
import '../data/page_data.dart';
import '../screens/page_screen.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/search_screen.dart';

// 메인 및 저장소
import '../main.dart';
import '../repositories/page_repository.dart';
import '../services/auth_service.dart';

// 리스트 확장 함수
extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

class NotionHomeScreen extends StatefulWidget {
  const NotionHomeScreen({super.key});

  @override
  State<NotionHomeScreen> createState() => _NotionHomeScreenState();
}

class _NotionHomeScreenState extends State<NotionHomeScreen> {
  // UI 상태 변수
  final List<Map<String, dynamic>> _recentPages = [];
  final List<PageData> _personalPages = []; // 트리 구조로 정리된 페이지 목록
  final List<PageData> _favoritePages = [];

  bool _isLoading = false;
  String? _errorMessage;
  
  // 현재 로그인한 유저 추적용
  User? _currentUser; 

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 1. 실시간 로그인 상태 감지 (Provider)
    final newUser = Provider.of<User?>(context);

    // 2. 유저가 바뀌었거나(로그인/로그아웃), 처음 로드될 때 실행
    if (newUser?.uid != _currentUser?.uid || (_currentUser == null && _personalPages.isEmpty && !_isLoading)) {
      _currentUser = newUser;
      
      // 3. 기존 데이터 비우고 새로 로드
      // (Repository 내부에서 userId가 없으면 게스트용, 있으면 유저용 데이터를 가져옴)
      _loadPages();
    }
  }

  List<PageData> _getAllPages() {
    List<PageData> result = [];
    // _personalPages는 최상위(루트) 페이지들만 담고 있음
    for (var page in _personalPages) {
      result.add(page);
      // 하위 페이지들도 모두 수집
      _collectAllSubPages(result, page.subPages);
    }
    return result;
  }

  // 2. 재귀적으로 모든 하위 페이지를 수집하는 헬퍼 함수
  void _collectAllSubPages(List<PageData> result, List<PageData> subPages) {
    for (var subPage in subPages) {
      result.add(subPage);
      if (subPage.subPages.isNotEmpty) {
        // 하위의 하위 페이지도 계속 수집 (재귀 호출)
        _collectAllSubPages(result, subPage.subPages);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeepLink();
    });
  }

  // 데이터 불러오기 및 트리 구조 구성
  Future<void> _loadPages() async {
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });
  
  try {
    final repository = Provider.of<PageRepository>(context, listen: false);
    final pages = await repository.getAllPages();
    
    if (!mounted) return;

    debugPrint('📥 Firestore에서 로드된 페이지: ${pages.length}개');

    // ✅ 1단계: 모든 페이지 맵 생성 (parentId 기반)
    final Map<String, PageData> pageMap = {};
    
    for (var page in pages) {
      // ✅ 완전히 새로운 PageData 객체 생성 (기존 참조 버림)
      final newPage = PageData(
        id: page.id,
        title: page.title,
        lastEdited: page.lastEdited,
        isFavorite: page.isFavorite,
        parentId: page.parentId,
      );
      pageMap[page.id] = newPage;
      
      debugPrint('  📄 ${page.title} (parentId: ${page.parentId})');
    }
    
    // ✅ 2단계: 트리 구조 구성
    final List<PageData> roots = [];
    
    for (var page in pageMap.values) {
      final parentId = page.parentId;
      
      if (parentId == null || parentId.isEmpty) {
        // 루트 페이지
        roots.add(page);
        debugPrint('  🌲 루트: ${page.title}');
      } else {
        // 하위 페이지
        final parent = pageMap[parentId];
        
        if (parent != null) {
          page.parentPage = parent;
          parent.subPages.add(page);
          debugPrint('  🔗 연결: ${page.title} -> ${parent.title}');
        } else {
          // 부모를 찾을 수 없으면 루트로 승격
          debugPrint('  ⚠️ 부모 없음: ${page.title} (parentId: $parentId) -> 루트로 변경');
          page.parentId = '';
          roots.add(page);
        }
      }
    }

    // ✅ 3단계: 상태 업데이트 (한 번에 모두 교체)
    setState(() {
      _personalPages.clear();
      _personalPages.addAll(roots);
      
      _favoritePages.clear();
      _favoritePages.addAll(pageMap.values.where((p) => p.isFavorite));
      
      _isLoading = false;
    });
    
    debugPrint('✅ 페이지 트리 구성 완료: 루트 ${roots.length}개, 전체 ${pageMap.length}개');
    _printPageTree();
    
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = '페이지를 불러오는데 실패했습니다: $e';
    });
    debugPrint('❌ _loadPages 실패: $e');
  }
}


  // ✅ 재귀적으로 모든 페이지 수집
  void _collectPagesRecursively(PageData page, Map<String, PageData> map) {
    map[page.id] = page;
    for (var subPage in page.subPages) {
      _collectPagesRecursively(subPage, map);
    }
  }

  // ✅ 디버깅용: 트리 구조 출력
  void _printPageTree() {
    debugPrint('🌳 페이지 트리 구조:');
    for (var root in _personalPages) {
      _printPageRecursively(root, 0);
    }
  }

  void _printPageRecursively(PageData page, int level) {
    final indent = '  ' * level;
    debugPrint('$indent- ${page.title} (id: ${page.id}, parentId: ${page.parentId})');
    for (var sub in page.subPages) {
      _printPageRecursively(sub, level + 1);
    }
  }

  // 계층형 구조를 리스트뷰용 평탄화 리스트로 변환
  List<PageData> _getFlattenedPages() {
    List<PageData> result = [];
    for (var page in _personalPages) {
      result.add(page);
      if (page.isExpanded && page.subPages.isNotEmpty) {
        _addExpandedSubPages(result, page.subPages);
      }
    }
    return result;
  }

  void _addExpandedSubPages(List<PageData> result, List<PageData> subPages) {
    for (var subPage in subPages) {
      result.add(subPage);
      if (subPage.isExpanded && subPage.subPages.isNotEmpty) {
        _addExpandedSubPages(result, subPage.subPages);
      }
    }
  }

  // 딥링크 처리
  void _checkDeepLink() {
    final deepLinkProvider = Provider.of<DeepLinkProvider>(context, listen: false);
    final pageIdToOpen = deepLinkProvider.pageIdToOpen;

    if (pageIdToOpen != null) {
      deepLinkProvider.clearPageIdToOpen();
    }
  }
  
  // 페이지 열기
  void _openPage(PageData page) {
    _updateRecentPages(page);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageScreen(
          page: page,
          onNewPage: () => _createNewPageAndOpen(context),
          onPageChanged: () => setState(() {}),
          onFavoriteToggle: _toggleFavorite,
          onDuplicate: _duplicatePage,
          onMove: (p) => _showMovePageDialog(p),
          onDelete: (p) => _confirmDeletePage(p).then((deleted) {
             if (deleted && mounted) Navigator.pop(context);
          }),
          allPages: _personalPages,
          onPageCreated: (newPage) => setState(() => _personalPages.insert(0, newPage)),
        ),
      ),
    ).then((_) {
       if (mounted) setState(() {});
    });
  }

  void _updateRecentPages(PageData page) {
    setState(() {
      _recentPages.removeWhere((item) => item['pageId'] == page.id);
      _recentPages.insert(0, {
        'pageId': page.id,
        'title': page.title,
        'icon': Icons.edit_note,
        'color': const Color(0xFFF0F0F0),
      });
      if (_recentPages.length > 5) _recentPages.removeLast();
    });
  }

  // --- 액션 메서드들 ---

  Future<void> _goToLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('로그아웃 하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('예')),
        ],
      ),
    );

    if (result == true) {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
    }
  }

  void _addNewPage() async {
    final newPage = PageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '제목 없음',
      lastEdited: DateTime.now(),
      parentId: null,
    );
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.createPage(newPage);
      if (mounted) setState(() => _personalPages.insert(0, newPage));
    } catch (e) {
      debugPrint('페이지 생성 실패: $e');
    }
  }

  void _createNewPageAndOpen(BuildContext ctx) async {
    final newPage = PageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '제목 없음',
      lastEdited: DateTime.now(),
      parentId: null,
    );
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.createPage(newPage);
      
      if (mounted) {
        setState(() => _personalPages.insert(0, newPage));
        _openPage(newPage);
      }
    } catch (e) {
      debugPrint('페이지 생성 실패: $e');
    }
  }
  
  void _addSubPage(PageData parentPage) async {
    final newSubPage = PageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '제목 없음',
      lastEdited: DateTime.now(),
      parentId: parentPage.id,
      parentPage: parentPage,
    );

    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.createPage(newSubPage);

      setState(() {
        parentPage.subPages.add(newSubPage);
        parentPage.isExpanded = true;
      });
    } catch (e) {
      debugPrint('하위 페이지 생성 실패: $e');
    }
  }
  
  void _toggleExpand(PageData page) {
    setState(() => page.isExpanded = !page.isExpanded);
  }

  void _toggleFavorite(PageData page) async {
    final newStatus = !page.isFavorite;
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.toggleFavorite(page.id, newStatus);
      
      if (mounted) {
        setState(() {
          page.isFavorite = newStatus;
          if (newStatus) {
            if (!_favoritePages.contains(page)) _favoritePages.add(page);
          } else {
            _favoritePages.remove(page);
          }
        });
      }
    } catch (e) {
      debugPrint('즐겨찾기 토글 실패: $e');
    }
  }

  void _duplicatePage(PageData page) async {
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);

      // 1. 새 페이지 메타 생성
      final newPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${page.title} 사본',
        lastEdited: DateTime.now(),
        isFavorite: page.isFavorite,
        parentId: page.parentId,
        parentPage: page.parentPage,
      );

      // 2. Firestore에 새 페이지 생성
      await repository.createPage(newPage);

      // 3. 블록 복사
      final originalBlocks = await repository.getBlocks(page.id);
      await repository.saveBlocks(
        newPage.id,
        originalBlocks,
      );

      // 4. 메모리 트리 갱신
      setState(() {
        if (page.parentPage != null) {
          page.parentPage!.subPages.add(newPage);
          page.parentPage!.isExpanded = true;
        } else {
          _personalPages.insert(0, newPage);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('페이지 복제 완료: ${newPage.title}')),
        );
      }
    } catch (e) {
      debugPrint('페이지 복제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('페이지 복제 실패: $e')));
      }
    }
  }

  
  Future<void> _showMovePageDialog(PageData page) async {
    final targetParent = await showDialog<PageData>(
      context: context,
      builder: (_) => _MovePageDialog(
        allPages: _personalPages,
        currentPage: page,
      ),
    );

    if (targetParent == null) return; // 취소한 경우

    try {
      final repository = Provider.of<PageRepository>(context, listen: false);

      // 2) Firestore에 parentId 업데이트
      final updated = page.copyWith(
        parentId: targetParent.id,
        parentPage: targetParent,
      );
      await repository.updatePage(updated);

      // 3) 메모리 트리 갱신
      setState(() {
        // 기존 부모에서 제거
        if (page.parentPage != null) {
          page.parentPage!.subPages.remove(page);
        } else {
          _personalPages.remove(page);
        }

        // 새 부모에 추가
        page.parentPage = targetParent;
        page.parentId = targetParent.id;
        targetParent.subPages.add(page);
        targetParent.isExpanded = true;
      });
    } catch (e) {
      debugPrint('페이지 이동 실패: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('페이지 이동 실패: $e')),
      );
    }
  }


  Future<bool> _confirmDeletePage(PageData page) async {
  final subPageCount = _countAllSubPages(page);
  final message = subPageCount > 0
      ? '이 페이지와 하위 페이지 $subPageCount개를 휴지통으로 이동하시겠습니까?'
      : '휴지통으로 이동하시겠습니까?';
  
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('페이지 삭제'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('삭제'),
        ),
      ],
    ),
  );

  if (result == true) {
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      
      // ✅ 1단계: 삭제될 모든 페이지 ID 수집
      final List<String> allDeletedIds = [];
      _collectAllPageIds(page, allDeletedIds);
      
      debugPrint('🗑️ 삭제할 페이지들: ${allDeletedIds.length}개');
      for (var id in allDeletedIds) {
        debugPrint('  - $id');
      }
      
      // ✅ 2단계: Firestore에서 삭제
      await repository.moveToTrash(page.id);
      
      if (!mounted) return false;
      
      // ✅ 3단계: 즉시 전체 리로드 (UI 동기화)
      await _loadPages();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${allDeletedIds.length}개 페이지를 휴지통으로 이동했습니다')),
      );
      
      return true;
    } catch (e) {
      debugPrint('❌ 삭제 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
      return false;
    }
  }
  return false;
}


// ✅ 페이지와 모든 하위 페이지의 ID를 수집
void _collectAllPageIds(PageData page, List<String> result) {
  result.add(page.id);
  for (var sub in page.subPages) {
    _collectAllPageIds(sub, result);  // 재귀
  }
}

// ✅ 하위 페이지 개수 계산
int _countAllSubPages(PageData page) {
  int count = page.subPages.length;
  for (var sub in page.subPages) {
    count += _countAllSubPages(sub);
  }
  return count;
}

  void _openSettings() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => const SettingsScreen())
    );
  }

  void _openTrash() {
  Navigator.push(
    context, 
    MaterialPageRoute(builder: (_) => const TrashScreen())
  ).then((_) {
    // ✅ 휴지통에서 돌아오면 무조건 전체 리로드
    if (mounted) _loadPages();
  });
}

  // ✅ 새로운 메서드: 휴지통 이후 최소한의 갱신
  // ✅ 새로운 메서드: 휴지통 이후 최소한의 갱신
Future<void> _refreshPagesAfterTrash() async {
  try {
    final repository = Provider.of<PageRepository>(context, listen: false);
    final freshPages = await repository.getAllPages();
    
    if (!mounted) return;

    // ✅ Firestore의 최신 페이지 ID 목록
    final freshPageIds = freshPages.map((p) => p.id).toSet();
    
    // ✅ 현재 메모리에 있는 모든 페이지 수집
    final Map<String, PageData> currentPageMap = {};
    for (var root in _personalPages) {
      _collectPagesRecursively(root, currentPageMap);
    }
    
    // ✅ 삭제된 페이지 + 고아 페이지(부모가 삭제된 하위) 제거
    final deletedPageIds = currentPageMap.keys.toSet().difference(freshPageIds);
    
    debugPrint('🗑️ 휴지통 이후 삭제된 페이지: ${deletedPageIds.length}개');
    
    for (var deletedId in deletedPageIds) {
      final deletedPage = currentPageMap[deletedId]!;
      
      if (deletedPage.parentPage != null) {
        // 자식 페이지면 부모의 subPages에서 제거
        deletedPage.parentPage!.subPages.remove(deletedPage);
      } else {
        // 루트 페이지면 _personalPages에서 제거
        _personalPages.remove(deletedPage);
      }
      
      _favoritePages.remove(deletedPage);
      _recentPages.removeWhere((item) => item['pageId'] == deletedId);
    }
    
    // ✅ 복원된 페이지 OR 고아 페이지가 발견되면 전체 리로드
    final newPageIds = freshPageIds.difference(currentPageMap.keys.toSet());
    
    // ✅ 추가 체크: 기존 페이지 중에 부모가 사라진 페이지가 있는지 확인
    bool hasOrphanPages = false;
    for (var currentPage in currentPageMap.values) {
      if (currentPage.parentId != null && currentPage.parentId!.isNotEmpty) {
        // 부모 ID가 있는데 현재 메모리에 부모가 없으면 고아 페이지
        if (!currentPageMap.containsKey(currentPage.parentId!)) {
          hasOrphanPages = true;
          debugPrint('👶 고아 페이지 발견: ${currentPage.title} (부모 ID: ${currentPage.parentId})');
          break;
        }
      }
    }
    
    if (newPageIds.isNotEmpty || hasOrphanPages) {
      // 복원된 페이지가 있거나 고아 페이지가 있으면 전체 리로드
      debugPrint('✅ 복원 ${newPageIds.length}개 또는 고아 페이지 발견 -> 전체 리로드');
      await _loadPages();
    } else {
      // 삭제만 있었으면 setState만
      if (mounted) {
        setState(() {});
        debugPrint('✅ 휴지통 이후 갱신: 삭제 ${deletedPageIds.length}개만 반영');
      }
    }
    
  } catch (e) {
    debugPrint('❌ 휴지통 이후 갱신 실패: $e');
    // 실패하면 안전하게 전체 리로드
    if (mounted) await _loadPages();
  }
}

  
  void _openSearch() {
    Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          allPages: _personalPages, 
          onNewPage: (ctx) => _createNewPageAndOpen(ctx)
        )
      )
    );
  }

  // ===========================================================================
  // UI 빌드
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    // 사용자 이름 표시
    final userEmail = _currentUser?.email;
    final userName = userEmail != null ? userEmail.split('@')[0] : '게스트';
    
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              Text(_errorMessage!),
              ElevatedButton(onPressed: _loadPages, child: const Text("재시도"))
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _currentUser == null ? _goToLogin : _confirmLogout,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.grey.shade400,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text('$userName의 Notion', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') _openSettings();
              else if (value == 'trash') _openTrash();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'settings', child: Text('설정')),
              const PopupMenuItem(value: 'trash', child: Text('휴지통')),
            ],
          ),
        ],
      ),

      body: CustomScrollView(
        slivers: [
          // 최근 페이지
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('최근 방문한 페이지', style: TextStyle(fontSize: 14, color: Colors.black54)),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 180,
              child:ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentPages.length,
                itemBuilder: (context, index) {
                  final recent = _recentPages[index];
                  final pageId = recent['pageId'] as String;

                  final allPages = _getAllPages(); 
                  final targetPage = allPages.firstWhereOrNull((p) => p.id == pageId);

                  if (targetPage == null) return const SizedBox.shrink();

                  return Container(
                     width: 150, margin: const EdgeInsets.only(left: 16), 
                     child: RecentPageCard(
                        title: recent['title'], 
                        icon: recent['icon'], 
                        color: recent['color'],
                        onTap: () => _openPage(targetPage),
                     ),
                  );
                },
              ),
            ),
          ),

          // 즐겨찾기
          if (_favoritePages.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Text('즐겨찾기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                   final page = _favoritePages[index];
                   return ListTile(
                     title: Text(page.title),
                     leading: const Icon(Icons.star, color: Colors.amber, size: 18),
                     onTap: () => _openPage(page),
                   );
                },
                childCount: _favoritePages.length,
              ),
            ),
          ],

          // 개인 페이지 목록
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Text('개인 페이지', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.add, size: 20), onPressed: _addNewPage),
                ],
              ),
            ),
          ),
          
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final flattenedPages = _getFlattenedPages();
                final page = flattenedPages[index];
                
                return PersonalPageTile(
                  title: page.title,
                  isFavorite: page.isFavorite,
                  isExpanded: page.isExpanded,
                  hasSubPages: page.subPages.isNotEmpty,
                  level: page.level,
                  onTap: () => _openPage(page),
                  onAddSubPage: () => _addSubPage(page),
                  onToggleExpand: page.subPages.isNotEmpty ? () => _toggleExpand(page) : null,
                  onFavorite: () => _toggleFavorite(page),
                  onMove: () => _showMovePageDialog(page),
                  onDuplicate: () => _duplicatePage(page),
                  onDelete: () => _confirmDeletePage(page),
                );
              },
              childCount: _getFlattenedPages().length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      bottomSheet: NotionBottomBar(
        onNewPage: () => _createNewPageAndOpen(context),
        onSearch: _openSearch,
      ),
    );
  }
}

// 페이지 이동 다이얼로그
class _MovePageDialog extends StatefulWidget {
  final List<PageData> allPages;
  final PageData currentPage;

  const _MovePageDialog({required this.allPages, required this.currentPage});

  @override
  State<_MovePageDialog> createState() => _MovePageDialogState();
}

class _MovePageDialogState extends State<_MovePageDialog> {
  PageData? _selectedPage;

  List<PageData> get _selectablePages {
    return widget.allPages.where((page) => page.id != widget.currentPage.id).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('페이지 이동'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _selectablePages.length,
          itemBuilder: (context, index) {
            final page = _selectablePages[index];
            final isSelected = _selectedPage?.id == page.id;
            
            return ListTile(
              title: Text(page.title),
              selected: isSelected,
              onTap: () => setState(() => _selectedPage = page),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
            onPressed: _selectedPage == null ? null : () => Navigator.pop(context, _selectedPage),
            child: const Text('이동')),
      ],
    );
  }
}
