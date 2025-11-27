import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDeepLink();
      _loadPages();
    });
  }

  // ✅ git pull 코드의 개선된 트리 구조 로딩 로직 사용
  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      final pages = await repository.getAllPages();
      
      // 1) id → PageData 매핑
      final Map<String, PageData> pageMap = {
        for (final p in pages) p.id: p,
      };

      // 2) 트리 구조 재구성
      final List<PageData> roots = [];
      
      for (final page in pages) {
        if (page.parentId == null || page.parentId!.isEmpty) {
          page.parentPage = null;
          page.subPages.clear();
          roots.add(page);
        } else {
          final parent = pageMap[page.parentId!];
          if (parent != null) {
            page.parentPage = parent;
            parent.subPages.add(page);
          } else {
            page.parentPage = null;
            roots.add(page);
          }
        }
      }

      setState(() {
        _personalPages
          ..clear()
          ..addAll(roots);

        _favoritePages
          ..clear()
          ..addAll(pages.where((p) => p.isFavorite));

        _isLoading = false;
      });
      
      debugPrint('✅ ${pages.length}개 페이지 로드 + 트리 구성 완료');
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

  List<PageData> _getAllPages() {
    List<PageData> result = [];
    for (var page in _personalPages.where((p) => p.parentPage == null)) {
      result.add(page);
      _addAllSubPages(result, page.subPages);
    }
    return result;
  }

  void _addAllSubPages(List<PageData> result, List<PageData> subPages) {
    for (var subPage in subPages) {
      result.add(subPage);
      if (subPage.subPages.isNotEmpty) {
        _addAllSubPages(result, subPage.subPages);
      }
    }
  }

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

  // ✅ 사용자 코드의 Firebase Auth 로그아웃 로직 사용
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
      try {
        await FirebaseAuth.instance.signOut();
        
        if (mounted) {
          setState(() {
            _userName = null;
          });
          
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그아웃되었습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        debugPrint('로그아웃 실패: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('로그아웃 실패: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

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
      
      final defaultBlocks = [
        BlockData(type: 'title', content: '제목 없음'),
        BlockData(type: 'text', content: ''),
      ];
      
      await repository.saveBlocks(newPage.id, defaultBlocks);
      savePageBlocks(newPage.id, defaultBlocks);
      
      if (mounted) {
        setState(() {
          _personalPages.insert(0, newPage);
        });
      }
      
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
      
      final defaultBlocks = [
        BlockData(type: 'title', content: '제목 없음'),
        BlockData(type: 'text', content: ''),
      ];
      
      await repository.saveBlocks(newPage.id, defaultBlocks);
      savePageBlocks(newPage.id, defaultBlocks);
      
      if (mounted) {
        setState(() {
          _personalPages.insert(0, newPage);
        });
      }
      
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

  void _addSubPage(PageData parentPage) {
    setState(() {
      final subPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '제목 없음',
        lastEdited: DateTime.now(),
        parentPage: parentPage,
        parentId: parentPage.id,
      );
      
      parentPage.subPages.add(subPage);
      parentPage.isExpanded = true;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${parentPage.title}"의 하위 페이지가 생성되었습니다.')),
      );
    });
  }

  void _toggleExpand(PageData page) {
    setState(() {
      page.isExpanded = !page.isExpanded;
    });
  }

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

  void _addExpandedSubPages(List<PageData> result, List<PageData> subPages) {
    for (var subPage in subPages) {
      result.add(subPage);
      if (subPage.isExpanded && subPage.subPages.isNotEmpty) {
        _addExpandedSubPages(result, subPage.subPages);
      }
    }
  }

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

  void _duplicatePage(PageData page) async {
    setState(() {
      String newTitle = _generateDuplicateTitle(page);
      final originalBlocks = getPageBlocks(page.id);
      
      final duplicatedPage = PageData(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: newTitle,
        lastEdited: DateTime.now(),
        isFavorite: false,
        parentId: page.parentId,
        parentPage: page.parentPage,
      );
      
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
      
      savePageBlocks(duplicatedPage.id, newBlocks);
      
      if (page.parentPage == null) {
        _personalPages.add(duplicatedPage);
      } else {
        final parentPage = page.parentPage!;
        final currentIndex = parentPage.subPages.indexOf(page);
        
        if (currentIndex != -1) {
          parentPage.subPages.insert(currentIndex + 1, duplicatedPage);
        } else {
          parentPage.subPages.add(duplicatedPage);
        }
      }
      
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

  String _removeNumberSuffix(String title) {
    final regex = RegExp(r'\s*\(\d+\)$');
    return title.replaceAll(regex, '');
  }

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

  void _permanentlyDeletePage(PageData page) {
    setState(() {
      _deletedPages.remove(page);
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  void _openTrash() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TrashScreen(),
      ),
    ).then((_) {
      _loadPages();
    });
  }

  @override
  Widget build(BuildContext context) {
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
