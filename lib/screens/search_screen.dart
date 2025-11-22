import 'package:flutter/material.dart';
import '../data/page_data.dart';
import 'page_screen.dart';

class SearchScreen extends StatefulWidget {
  final List<PageData> allPages;
  final Function(BuildContext) onNewPage;

  const SearchScreen({
    super.key,
    required this.allPages,
    required this.onNewPage,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PageData> _filteredPages = [];
  bool _isSearching = false;
  
  // 검색 옵션
  String _sortOption = '결과 상위 일치'; // 정렬 기준
  bool _titleOnly = false; // 제목만 검색
  
  // 검색 기록 (최대 10개)
  static final List<Map<String, dynamic>> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _filteredPages = widget.allPages;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 검색 기록에 추가
  void _addToSearchHistory(String query) {
    if (query.isEmpty) return;
    
    setState(() {
      // 이미 있는 검색어는 제거
      _searchHistory.removeWhere((item) => item['query'] == query);
      
      // 새 검색어를 맨 앞에 추가
      _searchHistory.insert(0, {
        'query': query,
        'timestamp': DateTime.now(),
      });
      
      // 최대 10개만 유지
      if (_searchHistory.length > 10) {
        _searchHistory.removeLast();
      }
    });
  }

  // 검색 필터링
  void _filterPages(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        _filteredPages = widget.allPages;
      } else {
        final lowerQuery = query.toLowerCase();
        
        if (_titleOnly) {
          // 제목만 검색
          _filteredPages = widget.allPages
              .where((page) =>
                  page.title.toLowerCase().contains(lowerQuery))
              .toList();
        } else {
          // 제목 + 내용 + ID 검색
          _filteredPages = widget.allPages.where((page) {
            // 제목에서 검색
            final titleMatch = page.title.toLowerCase().contains(lowerQuery);
            
            // ID에서 검색
            final idMatch = page.id.toLowerCase().contains(lowerQuery);
            
            // 내용에서 검색
            final content = getPageContent(page.id);
            final contentMatch = content.toLowerCase().contains(lowerQuery);
            
            return titleMatch || contentMatch || idMatch;
          }).toList();
        }
        
        // 정렬 적용
        _applySorting();
      }
    });
  }

  // 정렬 적용
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
        // ID 정확히 일치하는 항목 우선
        final lowerQuery = _searchController.text.toLowerCase().trim();
        _filteredPages.sort((a, b) {
          if (a.id == lowerQuery) return -1;
          if (b.id == lowerQuery) return 1;
          return 0;
        });
        break;
    }
  }

  // 검색 옵션 다이얼로그
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
                  
                  // 정렬 기준
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
                  
                  // 제목만 검색
                  SwitchListTile(
                    title: const Text('제목만 검색'),
                    subtitle: const Text('체크 해제 시 내용과 ID도 포함하여 검색'),
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
                  
                  // 완료 버튼
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

  // 페이지 경로 표시
  String _getPagePath(PageData page) {
    List<String> path = [];
    PageData? current = page;
    
    while (current != null) {
      path.insert(0, current.title);
      current = current.parentPage;
    }
    
    return path.join(' > ');
  }

  // 페이지 열기
  void _openPage(PageData page) {
    _addToSearchHistory(_searchController.text);
    
    Navigator.pop(context); // 검색 화면 닫기
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageScreen(
          page: page,
          onNewPage: () => widget.onNewPage(context),
          onPageChanged: () => setState(() {}),
          onFavoriteToggle: (p) => setState(() {}),
          onDuplicate: (p) => setState(() {}), //
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            // 필터 버튼
            IconButton(
              icon: Icon(
                Icons.tune,
                color: _titleOnly || _sortOption != '결과 상위 일치'
                    ? Colors.blue
                    : Colors.grey,
              ),
              onPressed: _showSearchOptionsDialog,
            ),
            
            // 검색 입력란
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
    // 검색어가 없고 검색 기록이 있으면 기록 표시
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
    
    // 검색어가 없으면 기본 화면
    if (!_isSearching && _searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '페이지를 검색하세요',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '제목, 내용, ID로 검색 가능',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    // 검색 결과가 없으면
    if (_filteredPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '"${_searchController.text}"에 대한',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            Text(
              '검색 결과가 없습니다',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    // 검색 결과 표시
    return ListView.builder(
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
