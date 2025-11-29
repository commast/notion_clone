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
      _personalPages.clear();
      _favoritePages.clear();
    });
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      final pages = await repository.getAllPages();
      
      if (!mounted) return;

      // 1) id -> PageData 매핑 (빠른 검색용)
      final Map<String, PageData> pageMap = { for (final p in pages) p.id: p };
      
      // 2) 트리 구조 재구성 (부모-자식 연결)
      final List<PageData> roots = [];
      
      for (final page in pages) {
        // 초기화 (중복 추가 방지)
        page.subPages.clear(); 
        
        if (page.parentId == null || page.parentId!.isEmpty) {
          page.parentPage = null;
          roots.add(page);
        } else {
          final parent = pageMap[page.parentId!];
          if (parent != null) {
            page.parentPage = parent;
            parent.subPages.add(page);
          } else {
            // 부모를 못 찾으면 루트로 취급 (예외 처리)
            page.parentPage = null;
            roots.add(page);
          }
        }
      }

      setState(() {
        _personalPages.addAll(roots);
        _favoritePages.addAll(pages.where((p) => p.isFavorite));
        _isLoading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = '페이지를 불러오는데 실패했습니다: $e';
      });
    }
  }

  // 계층형 구조를 리스트뷰용 평탄화 리스트로 변환 (에러 해결된 부분)
  List<PageData> _getFlattenedPages() {
    List<PageData> result = [];
    for (var page in _personalPages) { // 이미 roots만 들어있음
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
      // 여기서는 전체 페이지 리스트에서 검색해야 함 (트리 구조 무시하고 검색 필요)
      // 편의상 현재 로드된 페이지 내에서 검색한다고 가정
      // 실제로는 repository.getPage(id)를 호출하는 것이 정확함
      
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
          allPages: _personalPages, // 전체 리스트 전달 필요 (여기서는 roots만 전달됨, 개선 필요시 수정)
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
      // signOut -> didChangeDependencies 감지 -> _loadPages(Guest) 자동 실행
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
    } catch (e) {}
  }

  void _duplicatePage(PageData page) { /* 복제 로직 */ }
  
  Future<void> _showMovePageDialog(PageData page) async {
      await showDialog(
        context: context, 
        builder: (_) => _MovePageDialog(allPages: _personalPages, currentPage: page)
      );
  }

  Future<bool> _confirmDeletePage(PageData page) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('페이지 삭제'),
        content: const Text('휴지통으로 이동하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );

    if (result == true) {
      try {
        final repository = Provider.of<PageRepository>(context, listen: false);
        await repository.moveToTrash(page.id);
        if (mounted) {
          setState(() {
             // 트리 구조에서 제거
             if(page.parentPage != null) {
                page.parentPage!.subPages.remove(page);
             } else {
                _personalPages.remove(page);
             }
             _favoritePages.remove(page);
             _recentPages.removeWhere((item) => item['pageId'] == page.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('휴지통으로 이동됨')));
        }
        return true;
      } catch (e) {
        return false;
      }
    }
    return false;
  }
  
  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  void _openTrash() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TrashScreen())).then((_) => _loadPages());
  }
  
  void _openSearch() {
     Navigator.push(context, MaterialPageRoute(
        builder: (_) => SearchScreen(allPages: _personalPages, onNewPage: (ctx) => _createNewPageAndOpen(ctx))
     ));
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
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recentPages.length,
                itemBuilder: (context, index) {
                  final recent = _recentPages[index];
                  return Container(
                     width: 150, margin: const EdgeInsets.only(left: 16), 
                     child: RecentPageCard(
                        title: recent['title'], 
                        icon: recent['icon'], 
                        color: recent['color'],
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
    // 트리 구조를 평탄화하거나, 루트 페이지만 보여주는 등 선택 로직 필요
    // 여기서는 간단히 루트 페이지만 보여줌
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