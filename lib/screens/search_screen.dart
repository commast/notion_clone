import 'package:flutter/material.dart';
import '../data/page_data.dart';
import 'page_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<PageData> allPages;
  final Function(BuildContext) onNewPage;
  final void Function(PageData)? onPageChanged;

  const SearchScreen({
    super.key,
    required this.allPages,
    required this.onNewPage,
    this.onPageChanged,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PageData> _filteredPages = [];
  bool _isSearching = false;
  
  String _sortOption = '결과 상위 일치';
  bool _titleOnly = false;
  
  static final List<Map<String, dynamic>> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    // 초기 상태에서 모든 페이지 표시 
    _filteredPages = _getAllPagesFlattened();
    debugPrint('검색 화면 초기화: ${_filteredPages.length}개 페이지');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 모든 페이지를 평탄화하여 반환 (부모-자식 구분 없이)
  List<PageData> _getAllPagesFlattened() {
    List<PageData> result = [];
    
    void addRecursively(List<PageData> pages) {
      for (var page in pages) {
        result.add(page);
        if (page.subPages.isNotEmpty) {
          addRecursively(page.subPages);
        }
      }
    }
    
    addRecursively(widget.allPages);
    
    debugPrint('평탄화된 페이지: ${result.length}개');
    for (var page in result) {
      debugPrint('  - ${page.title} (id: ${page.id}, parentId: ${page.parentId})');
    }
    
    return result;
  }

  void _addToSearchHistory(String query) {
    if (query.isEmpty) return;
    
    setState(() {
      _searchHistory.removeWhere((item) => item['query'] == query);
      
      _searchHistory.insert(0, {
        'query': query,
        'timestamp': DateTime.now(),
      });
      
      if (_searchHistory.length > 10) {
        _searchHistory.removeLast();
      }
    });
  }

  void _filterPages(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        // 검색어가 없으면 모든 페이지 표시
        _filteredPages = _getAllPagesFlattened();
        debugPrint('검색어 없음: 전체 ${_filteredPages.length}개 표시');
      } else {
        final lowerQuery = query.toLowerCase();
        final allFlattened = _getAllPagesFlattened();
        
        if (_titleOnly) {
          _filteredPages = allFlattened
              .where((page) => page.title.toLowerCase().contains(lowerQuery))
              .toList();
        } else {
          _filteredPages = allFlattened.where((page) {
            final titleMatch = page.title.toLowerCase().contains(lowerQuery);
            final idMatch = page.id.toLowerCase().contains(lowerQuery);
            
            // 블록 내용 검색 제거
            return titleMatch || idMatch;
          }).toList();
        }
        
        debugPrint('검색 결과: "${query}" -> ${_filteredPages.length}개');
        _applySorting();
      }
    });
  }

  void _applySorting() {
    switch (_sortOption) {
      case '최종편집: 최신순':
        _filteredPages.sort((a, b) => b.lastEdited.compareTo(a.lastEdited));
        break;
      case '최종편집: 오래된 순':
        _filteredPages.sort((a, b) => a.lastEdited.compareTo(b.lastEdited));
        break;
      case '생성 일시: 최신순':
        _filteredPages.sort((a, b) => b.id.compareTo(a.id));
        break;
      case '생성 일시: 오래된 순':
        _filteredPages.sort((a, b) => a.id.compareTo(b.id));
        break;
      case '결과 상위 일치':
      default:
        final lowerQuery = _searchController.text.toLowerCase().trim();
        _filteredPages.sort((a, b) {
          if (a.id == lowerQuery) return -1;
          if (b.id == lowerQuery) return 1;
          return 0;
        });
        break;
    }
  }

  void _showSearchOptionsDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '검색 옵션',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  const Text(
                    '정렬 기준',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      '결과 상위 일치',
                      '최종편집: 최신순',
                      '최종편집: 오래된 순',
                      '생성 일시: 최신순',
                      '생성 일시: 오래된 순',
                    ].map((option) {
                      final isSelected = _sortOption == option;
                      return ChoiceChip(
                        label: Text(option, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (selected) {
                          setModalState(() {
                            _sortOption = option;
                          });
                          setState(() {
                            _sortOption = option;
                            _filterPages(_searchController.text);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('제목만 검색'),
                    subtitle: const Text('체크 해제 시 ID도 포함하여 검색'),
                    value: _titleOnly,
                    onChanged: (value) {
                      setModalState(() {
                        _titleOnly = value;
                      });
                      setState(() {
                        _titleOnly = value;
                        _filterPages(_searchController.text);
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('완료'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getPagePath(PageData page) {
    List<String> path = [];
    PageData? current = page;
    
    while (current != null) {
      path.insert(0, current.title);
      current = current.parentPage;
    }
    
    return path.join(' > ');
  }

  void _openPage(PageData page) {
    _addToSearchHistory(_searchController.text);
    
    Navigator.pop(context);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageScreen(
          page: page,
          onNewPage: () => widget.onNewPage(context),
          onPageChanged: (updatedPage) => setState(() {}),
          onFavoriteToggle: (p) => setState(() {}),
          onDuplicate: (p) {},
          onMove: (p) {},
          onDelete: (p) async => false,
          allPages: widget.allPages,
          onPageCreated: (newPage) {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SearchScreen build: ${_filteredPages.length}개 페이지');
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.tune,
                color: _titleOnly || _sortOption != '결과 상위 일치'
                    ? Colors.blue
                    : Colors.grey,
              ),
              onPressed: _showSearchOptionsDialog,
            ),
            
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '페이지 검색...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: _filterPages,
                onSubmitted: (query) {
                  _addToSearchHistory(query);
                },
              ),
            ),
          ],
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _filterPages('');
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 검색 기록 표시 
    if (!_isSearching && _searchController.text.isEmpty && _searchHistory.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              '최근 검색',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final history = _searchHistory[index];
                final query = history['query'] as String;
                final timestamp = history['timestamp'] as DateTime;
                
                return ListTile(
                  leading: const Icon(Icons.history, size: 18),
                  title: Text(query, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    _formatTimestamp(timestamp),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _searchHistory.removeAt(index);
                      });
                    },
                  ),
                  onTap: () {
                    _searchController.text = query;
                    _filterPages(query);
                  },
                );
              },
            ),
          ),
        ],
      );
    }
    
    // 페이지 목록 표시 
    if (_filteredPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? '"${_searchController.text}"에 대한\n검색 결과가 없습니다'
                  : '페이지가 없습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 페이지 개수 표시
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _searchController.text.isEmpty
                ? '전체 페이지 (${_filteredPages.length}개)'
                : '검색 결과 (${_filteredPages.length}개)',
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredPages.length,
            itemBuilder: (context, index) {
              final page = _filteredPages[index];
              final pagePath = _getPagePath(page);
              final isExactIdMatch = page.id == _searchController.text.toLowerCase().trim();
              
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(
                  page.isFavorite ? Icons.star : Icons.description_outlined,
                  size: 18,
                  color: page.isFavorite ? Colors.amber : Colors.grey,
                ),
                title: Text(
                  page.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isExactIdMatch ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 계층 구조 표시 (부모 > 자식)
                    if (pagePath != page.title)
                      Text(
                        pagePath,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    if (isExactIdMatch)
                      Text(
                        'ID: ${page.id}',
                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                  ],
                ),
                trailing: isExactIdMatch
                    ? const Chip(
                        label: Text('ID 일치', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.blue,
                        labelStyle: TextStyle(color: Colors.white),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      )
                    : null,
                onTap: () => _openPage(page),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      return '${timestamp.year}.${timestamp.month}.${timestamp.day}';
    }
  }
}
