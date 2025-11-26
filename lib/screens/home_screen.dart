import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/common/notion_bottom_bar.dart';
import '../widgets/home/recent_page_card.dart';
import '../widgets/home/personal_page_tile.dart';
import '../data/page_data.dart';
import '../screens/page_screen.dart';
import '../screens/login_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/trash_screen.dart';
import '../screens/search_screen.dart';
import '../main.dart';
import '../repositories/page_repository.dart';


// 안전한 firstWhere를 위한 extension
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
  final List<Map<String, dynamic>> _recentPages = [];
  String? _userName;
  final List<PageData> _deletedPages = [];
  final List<PageData> _personalPages = [];
  final List<PageData> _favoritePages = [];


  bool _isLoading = true;
  String? _errorMessage;


  @override
  void initState() {
    super.initState();
    
    // 딥링크로 열어야 할 페이지 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeepLink();
      _loadPages();
    });
  }


  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      final pages = await repository.getAllPages();
      
      setState(() {
        _personalPages.clear();
        _personalPages.addAll(pages);
        
        // 즐겨찾기 페이지 필터링
        _favoritePages.clear();
        _favoritePages.addAll(pages.where((p) => p.isFavorite));
        
        _isLoading = false;
      });
      
      debugPrint('✅ ${pages.length}개 페이지 로드 완료');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '페이지를 불러오는데 실패했습니다: $e';
      });
      
      debugPrint('❌ 페이지 로드 실패: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage!)),
        );
      }
    }
  }


  // 딥링크 확인 및 페이지 열기
  void _checkDeepLink() {
    final deepLinkProvider = Provider.of<DeepLinkProvider>(context, listen: false);
    final pageIdToOpen = deepLinkProvider.pageIdToOpen;


    if (pageIdToOpen != null) {
      debugPrint('딥링크로 페이지 찾기: $pageIdToOpen');
      
      final allPages = _getAllPages();
      final targetPage = allPages.firstWhereOrNull((p) => p.id == pageIdToOpen);


      if (targetPage != null) {
        debugPrint('페이지 발견: ${targetPage.title}');
        
        Future.delayed(const Duration(milliseconds: 500), () {
          _updateRecentPages(targetPage);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotionPageScreen(
                page: targetPage,
                onNewPage: () => _createNewPageAndOpen(context),
                onPageChanged: () => setState(() {}),
                onFavoriteToggle: _toggleFavorite,
                onDuplicate: _duplicatePage,
                onMove: (page) => _showMovePageDialog(page),
                onDelete: (page) {
                  _confirmDeletePage(page).then((deleted) {
                    if (deleted && mounted) {
                      Navigator.pop(context);
                    }
                  });
                },
                allPages: _getAllPages(),
                onPageCreated: (newCreatedPage) {
                  setState(() {
                    _personalPages.insert(0, newCreatedPage);
                  });
                },
              ),
            ),
          ).then((_) {
            setState(() {});
          });
        });


        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📄 "${targetPage.title}" 페이지가 열렸습니다'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        debugPrint('❌ 페이지를 찾을 수 없음: $pageIdToOpen');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ 페이지를 찾을 수 없습니다 (ID: $pageIdToOpen)'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
          ),
        );
      }


      deepLinkProvider.clearPageIdToOpen();
    }
  }


  // 최근 방문한 페이지를 추가/업데이트
  void _updateRecentPages(PageData page) {
    setState(() {
      _recentPages.removeWhere((item) => item['pageId'] == page.id);
      
      _recentPages.insert(0, {
        'pageId': page.id,
        'title': page.title,
        'icon': Icons.edit_note,
        'color': const Color(0xFFF0F0F0),
      });
      
      if (_recentPages.length > 5) {
        _recentPages.removeLast();
      }
    });
  }


  // 검색 화면 열기
  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          allPages: _getAllPages(),
          onNewPage: (ctx) => _createNewPageAndOpen(ctx),
        ),
      ),
    ).then((_) => setState(() {}));
  }


  // 모든 페이지(상위+하위) 리스트 가져오기
  List<PageData> _getAllPages() {
    List<PageData> result = [];
    for (var page in _personalPages.where((p) => p.parentPage == null)) {
      result.add(page);
      _addAllSubPages(result, page.subPages);
    }
    return result;
  }


  // 모든 하위 페이지를 재귀적으로 추가
  void _addAllSubPages(List<PageData> result, List<PageData> subPages) {
    for (var subPage in subPages) {
      result.add(subPage);
      if (subPage.subPages.isNotEmpty) {
        _addAllSubPages(result, subPage.subPages);
      }
    }
  }


  // 로그인 화면 이동
  Future<void> _goToLogin() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );


    if (result != null && result.isNotEmpty) {
      setState(() {
        _userName = result;
      });
    }
  }


  // 로그아웃 확인
  Future<void> _confirmLogout() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니오'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('예'),
            ),
          ],
        );
      },
    );


    if (result == true) {
      setState(() {
        _userName = null;
      });
    }
  }


  // 최종 편집 기준으로 정렬
  void _sortByLastEdited() {
    setState(() {
      _personalPages.sort((a, b) => b.lastEdited.compareTo(a.lastEdited));
    });


    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('최종 편집일 순으로 정렬되었습니다.'),
        duration: Duration(seconds: 1),
      ),
    );
  }


  // 새 페이지 추가
  void _addNewPage() async {
    final newPage = PageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '제목 없음',
      lastEdited: DateTime.now(),
    );
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.createPage(newPage);
      
      setState(() {
        _personalPages.insert(0, newPage);
      });
      
      debugPrint('✅ 새 페이지 생성 완료: ${newPage.id}');
    } catch (e) {
      debugPrint('❌ 페이지 생성 실패: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('페이지 생성 실패: $e')),
        );
      }
    }
  }


  // 새 페이지를 만들고 해당 페이지 화면으로 이동
  void _createNewPageAndOpen(BuildContext ctx) async {
    final newPage = PageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '제목 없음',
      lastEdited: DateTime.now(),
    );
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.createPage(newPage);
      
      setState(() {
        _personalPages.insert(0, newPage);
      });
      
      _updateRecentPages(newPage);
      
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => NotionPageScreen(
            page: newPage,
            onNewPage: () => _createNewPageAndOpen(ctx),
            onPageChanged: () => setState(() {}),
            onFavoriteToggle: _toggleFavorite,
            onDuplicate: _duplicatePage,
            onMove: (p) => _showMovePageDialog(p),
            onDelete: (p) {
              _confirmDeletePage(p).then((deleted) {
                if (deleted && mounted) {
                  Navigator.pop(ctx);
                }
              });
            },
            allPages: _getAllPages(),
            onPageCreated: (newCreatedPage) {
              setState(() {
                _personalPages.insert(0, newCreatedPage);
              });
            },
          ),
        ),
      );
      
      debugPrint('✅ 새 페이지 생성 및 열기 완료');
    } catch (e) {
      debugPrint('❌ 페이지 생성 실패: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('페이지 생성 실패: $e')),
        );
      }
    }
  }


  // 하위 페이지 추가
  void _addSubPage(PageData parentPage) {
    setState(() {
      final subPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '제목 없음',
        lastEdited: DateTime.now(),
        parentPage: parentPage,
      );
      
      parentPage.subPages.add(subPage);
      parentPage.isExpanded = true;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${parentPage.title}"의 하위 페이지가 생성되었습니다.')),
      );
    });
  }


  // 페이지 확장/축소 토글
  void _toggleExpand(PageData page) {
    setState(() {
      page.isExpanded = !page.isExpanded;
    });
  }


  // 평면화된 페이지 리스트 가져오기
  List<PageData> _getFlattenedPages() {
    List<PageData> result = [];
    for (var page in _personalPages.where((p) => p.parentPage == null)) {
      result.add(page);
      if (page.isExpanded && page.subPages.isNotEmpty) {
        _addExpandedSubPages(result, page.subPages);
      }
    }
    return result;
  }


  // 확장된 하위 페이지들을 재귀적으로 추가
  void _addExpandedSubPages(List<PageData> result, List<PageData> subPages) {
    for (var subPage in subPages) {
      result.add(subPage);
      if (subPage.isExpanded && subPage.subPages.isNotEmpty) {
        _addExpandedSubPages(result, subPage.subPages);
      }
    }
  }


  // 즐겨찾기 토글
  void _toggleFavorite(PageData page) async {
    final newFavoriteStatus = !page.isFavorite;
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.toggleFavorite(page.id, newFavoriteStatus);
      
      setState(() {
        page.isFavorite = newFavoriteStatus;
        
        if (page.isFavorite) {
          if (!_favoritePages.contains(page)) {
            _favoritePages.add(page);
          }
        } else {
          _favoritePages.remove(page);
        }
      });
      
      debugPrint('✅ 즐겨찾기 토글 완료: ${page.title} -> $newFavoriteStatus');
    } catch (e) {
      debugPrint('❌ 즐겨찾기 토글 실패: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('즐겨찾기 변경 실패: $e')),
        );
      }
    }
  }


  // 페이지 복제
  void _duplicatePage(PageData page) {
    setState(() {
      // 1. 중복된 이름 확인 및 번호 생성
      String newTitle = _generateDuplicateTitle(page);
      
      // 2. 페이지 블록 복사
      final originalBlocks = getPageBlocks(page.id);
      
      // 3. 새 페이지 생성
      final duplicatedPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: newTitle,
        lastEdited: DateTime.now(),
        isFavorite: false,
        parentPage: page.parentPage,
      );
      
      // 4. 블록 복사
      final newBlocks = originalBlocks.map((block) {
        if (block.type == 'title') {
          return BlockData(type: 'title', content: newTitle);
        } else if (block.type == 'table') {
          return BlockData(
            type: 'table',
            content: Map<String, int>.from(block.content as Map<String, int>),
          );
        } else {
          return BlockData(
            type: block.type,
            content: block.content,
          );
        }
      }).toList();
      
      // 5. 새 페이지의 블록 저장
      savePageBlocks(duplicatedPage.id, newBlocks);
      
      // 6. 상위 페이지인지 하위 페이지인지 확인하여 위치 결정
      if (page.parentPage == null) {
        // 상위 페이지 -> 개인 페이지 목록 맨 밑에 추가
        _personalPages.add(duplicatedPage);
      } else {
        // 하위 페이지 -> 같은 부모의 하위 페이지 목록에 추가
        final parentPage = page.parentPage!;
        final currentIndex = parentPage.subPages.indexOf(page);
        
        if (currentIndex != -1) {
          parentPage.subPages.insert(currentIndex + 1, duplicatedPage);
        } else {
          parentPage.subPages.add(duplicatedPage);
        }
      }
      
      // 7. 알림 표시
      final locationText = page.parentPage == null 
          ? '개인 페이지 맨 밑' 
          : '"${page.parentPage!.title}"의 하위 페이지';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ "${page.title}" → "$newTitle" 페이지가 $locationText에 복제되었습니다.'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue,
          action: SnackBarAction(
            label: '열기',
            textColor: Colors.white,
            onPressed: () {
              _updateRecentPages(duplicatedPage);
              
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotionPageScreen(
                    page: duplicatedPage,
                    onNewPage: () => _createNewPageAndOpen(context),
                    onPageChanged: () => setState(() {}),
                    onFavoriteToggle: _toggleFavorite,
                    onDuplicate: _duplicatePage,
                    onMove: (p) => _showMovePageDialog(p),
                    onDelete: (p) {
                      _confirmDeletePage(p).then((deleted) {
                        if (deleted && mounted) {
                          Navigator.pop(context);
                        }
                      });
                    },
                    allPages: _getAllPages(),
                    onPageCreated: (newCreatedPage) {
                      setState(() {
                        _personalPages.insert(0, newCreatedPage);
                      });
                    },
                  ),
                ),
              ).then((_) => setState(() {}));
            },
          ),
        ),
      );
    });
  }


  // 중복 제목 생성 함수
  String _generateDuplicateTitle(PageData originalPage) {
    final baseTitle = _removeNumberSuffix(originalPage.title);
    
    List<PageData> sameLevelPages;
    
    if (originalPage.parentPage == null) {
      sameLevelPages = _personalPages.where((p) => p.parentPage == null).toList();
    } else {
      sameLevelPages = originalPage.parentPage!.subPages;
    }
    
    final existingTitles = sameLevelPages.map((p) => p.title).toSet();
    
    int number = 1;
    String newTitle;
    
    do {
      newTitle = '$baseTitle ($number)';
      number++;
    } while (existingTitles.contains(newTitle));
    
    return newTitle;
  }


  // 제목에서 번호 접미사 제거
  String _removeNumberSuffix(String title) {
    final regex = RegExp(r'\s*\(\d+\)$');
    return title.replaceAll(regex, '');
  }


  // 페이지 옮기기 다이얼로그
  Future<void> _showMovePageDialog(PageData pageToMove) async {
    final result = await showDialog<PageData?>(
      context: context,
      builder: (context) {
        return _MovePageDialog(
          allPages: _getAllPages(),
          currentPage: pageToMove,
        );
      },
    );


    if (result != null) {
      _movePageTo(pageToMove, result);
    }
  }


  // 페이지를 다른 페이지의 하위로 이동
  void _movePageTo(PageData pageToMove, PageData targetParent) {
    setState(() {
      if (pageToMove.parentPage != null) {
        pageToMove.parentPage!.subPages.remove(pageToMove);
      } else {
        _personalPages.remove(pageToMove);
      }


      pageToMove.parentPage = targetParent;
      targetParent.subPages.add(pageToMove);
      targetParent.isExpanded = true;


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${pageToMove.title}" 페이지가 "${targetParent.title}"의 하위 페이지로 이동되었습니다.'),
        ),
      );
    });
  }


  // 페이지 삭제 (휴지통으로 이동)
  Future<bool> _confirmDeletePage(PageData page) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('페이지 삭제'),
          content: const Text('휴지통으로 이동하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );


    if (result == true) {
      try {
        final repository = Provider.of<PageRepository>(context, listen: false);
        await repository.moveToTrash(page.id);
        
        setState(() {
          _personalPages.remove(page);
          _favoritePages.remove(page);
          _deletedPages.insert(0, page);
          _recentPages.removeWhere((item) => item['pageId'] == page.id);
        });


        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${page.title}" 페이지가 휴지통으로 이동되었습니다.'),
            action: SnackBarAction(
              label: '실행 취소',
              onPressed: () async {
                try {
                  await repository.restoreFromTrash(page.id);
                  setState(() {
                    _deletedPages.remove(page);
                    _personalPages.insert(0, page);
                    if (page.isFavorite) {
                      _favoritePages.add(page);
                    }
                  });
                } catch (e) {
                  debugPrint('❌ 복원 실패: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('복원 실패: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
        
        debugPrint('✅ 페이지 휴지통 이동 완료: ${page.id}');
        return true;
      } catch (e) {
        debugPrint('❌ 페이지 삭제 실패: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('페이지 삭제 실패: $e')),
          );
        }
        
        return false;
      }
    }
    
    return false;
  }


  // 페이지 복원
  void _restorePage(PageData page) {
    setState(() {
      _deletedPages.remove(page);
      _personalPages.insert(0, page);
      page.lastEdited = DateTime.now();
      if (page.isFavorite) {
        _favoritePages.add(page);
      }
    });
  }


  // 페이지 영구 삭제
  void _permanentlyDeletePage(PageData page) {
    setState(() {
      _deletedPages.remove(page);
    });
  }


  // 설정 화면 열기
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }


  // 휴지통 화면 열기
  void _openTrash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TrashScreen(),
      ),
    ).then((_) => setState(() {}));
  }


  @override
  Widget build(BuildContext context) {
    // 로딩 중일 때
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('페이지를 불러오는 중...'),
            ],
          ),
        ),
      );
    }
    
    // 에러 발생 시
    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPages,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: _userName == null
            ? GestureDetector(
                onTap: _goToLogin,
                child: const Text(
                  '로그인',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              )
            : InkWell(
                onTap: _confirmLogout,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade400,
                      child: Text(
                        _userName!.isNotEmpty
                            ? _userName![0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_userName!}의 Notion',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'settings') {
                _openSettings();
              } else if (value == 'trash') {
                _openTrash();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 12),
                    Text('설정'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'trash',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: 12),
                    Text('휴지통'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),


      body: CustomScrollView(
        slivers: [
          // 최근 방문한 페이지
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(left: 16.0, top: 10.0, bottom: 8.0),
              child: Text(
                '최근 방문한 페이지',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
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
                  final pageId = recent['pageId'] as String;


                  final allPages = _getAllPages();
                  final pageData = allPages.firstWhereOrNull(
                    (p) => p.id == pageId,
                  );


                  if (pageData == null) {
                    return const SizedBox.shrink();
                  }


                  return RecentPageCard(
                    title: pageData.title,
                    icon: recent['icon'] as IconData,
                    color: recent['color'] as Color,
                    onTap: () async {
                      _updateRecentPages(pageData);
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NotionPageScreen(
                            page: pageData,
                            onNewPage: () => _createNewPageAndOpen(context),
                            onPageChanged: () => setState(() {}),
                            onFavoriteToggle: _toggleFavorite,
                            onDuplicate: _duplicatePage,
                            onMove: (page) => _showMovePageDialog(page),
                            onDelete: (page) {
                              _confirmDeletePage(page).then((deleted) {
                                if (deleted && mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            },
                            allPages: _getAllPages(),
                            onPageCreated: (newCreatedPage) {
                              setState(() {
                                _personalPages.insert(0, newCreatedPage);
                              });
                            },
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  );
                },
              ),
            ),
          ),


          // 즐겨찾기
          if (_favoritePages.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 20.0,
                  bottom: 8.0,
                ),
                child: Text(
                  '즐겨찾기',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final page = _favoritePages[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const Icon(Icons.star, size: 18, color: Colors.amber),
                    title: Text(page.title, style: const TextStyle(fontSize: 14)),
                    onTap: () async {
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
                            onDelete: (p) {
                              _confirmDeletePage(p).then((deleted) {
                                if (deleted && mounted) {
                                  Navigator.pop(context);
                                }
                              });
                            },
                            allPages: _getAllPages(),
                            onPageCreated: (newCreatedPage) {
                              setState(() {
                                _personalPages.insert(0, newCreatedPage);
                              });
                            },
                          ),
                        ),
                      );
                      setState(() {});
                    },
                  );
                },
                childCount: _favoritePages.length,
              ),
            ),
          ],


          // 개인 페이지
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 20.0,
                bottom: 8.0,
              ),
              child: Row(
                children: [
                  const Text(
                    '개인 페이지',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.more_horiz, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _sortByLastEdited,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _addNewPage,
                  ),
                ],
              ),
            ),
          ),


          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final flattenedPages = _getFlattenedPages();
              final page = flattenedPages[index];
              
              return PersonalPageTile(
                title: page.title,
                isFavorite: page.isFavorite,
                isExpanded: page.isExpanded,
                hasSubPages: page.subPages.isNotEmpty,
                level: page.level,
                onTap: () async {
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
                        onDelete: (p) {
                          _confirmDeletePage(p).then((deleted) {
                            if (deleted && mounted) {
                              Navigator.pop(context);
                            }
                          });
                        },
                        allPages: _getAllPages(),
                        onPageCreated: (newCreatedPage) {
                          setState(() {
                            _personalPages.insert(0, newCreatedPage);
                          });
                        },
                      ),
                    ),
                  );
                  setState(() {});
                },
                onAddSubPage: () => _addSubPage(page),
                onToggleExpand: page.subPages.isNotEmpty ? () => _toggleExpand(page) : null,
                onFavorite: () => _toggleFavorite(page),
                onMove: () => _showMovePageDialog(page),
                onDuplicate: () => _duplicatePage(page),
                onDelete: () => _confirmDeletePage(page),
              );
            }, childCount: _getFlattenedPages().length),
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


  const _MovePageDialog({
    required this.allPages,
    required this.currentPage,
  });


  @override
  State<_MovePageDialog> createState() => _MovePageDialogState();
}


class _MovePageDialogState extends State<_MovePageDialog> {
  PageData? _selectedPage;


  List<PageData> get _selectablePages {
    return widget.allPages.where((page) {
      if (page.id == widget.currentPage.id) return false;
      if (_isDescendant(page, widget.currentPage)) return false;
      return true;
    }).toList();
  }


  bool _isDescendant(PageData page, PageData potentialAncestor) {
    PageData? current = page.parentPage;
    while (current != null) {
      if (current.id == potentialAncestor.id) return true;
      current = current.parentPage;
    }
    return false;
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('페이지 이동'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _selectablePages.isEmpty
            ? const Center(
                child: Text(
                  '이동 가능한 페이지가 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: _selectablePages.length,
                itemBuilder: (context, index) {
                  final page = _selectablePages[index];
                  final isSelected = _selectedPage?.id == page.id;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.only(
                      left: 16.0 + (page.level * 20.0),
                      right: 16.0,
                    ),
                    leading: Icon(
                      Icons.description_outlined,
                      size: 18,
                      color: isSelected ? Colors.blue : null,
                    ),
                    title: Text(
                      page.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.blue : Colors.black,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedPage = page;
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: _selectedPage == null
              ? null
              : () => Navigator.pop(context, _selectedPage),
          child: const Text('이동'),
        ),
      ],
    );
  }
}
