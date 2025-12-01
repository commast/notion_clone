import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/page_data.dart';
import '../repositories/page_repository.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<PageData> _deletedPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Firebase에서 휴지통 데이터 불러오기
  Future<void> _loadTrash() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Repository를 통해 현재 로그인된 유저의 휴지통 데이터만 가져옵니다.
      // (PageRepository 내부에서 _userId를 사용하여 필터링함)
      final repository = Provider.of<PageRepository>(context, listen: false);
      final trashPages = await repository.getTrash();

      if (!mounted) return;

      setState(() {
        _deletedPages = trashPages;
        _isLoading = false;
      });

      debugPrint('✅ 휴지통 로드 완료: ${trashPages.length}개');
    } catch (e) {
      debugPrint('❌ 휴지통 로드 실패: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('휴지통 로드 실패: $e')),
        );
      }
    }
  }

  List<PageData> get _filteredPages {
    if (_searchQuery.isEmpty) {
      return _deletedPages;
    }
    return _deletedPages
        .where((page) => page.title.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  /// 페이지 복원
  void _showRestoreDialog(PageData page) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('페이지 복원'),
          content: Text('"${page.title}" 페이지를 복원하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // 다이얼로그 먼저 닫기

                try {
                  final repository = Provider.of<PageRepository>(context, listen: false);
                  
                  // 복원 작업 (repository 내부에서 userId 사용하여 권한 체크)
                  await repository.restoreFromTrash(page.id);
                  
                  // 휴지통 목록 새로고침
                  await _loadTrash();

                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${page.title}" 페이지가 복원되었습니다.')),
                  );

                  debugPrint('✅ [Firestore] 복원 완료: ${page.id}');
                } catch (e) {
                  debugPrint('❌ 페이지 복원 실패: $e');

                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('복원 실패: $e')),
                  );
                }
              },
              child: const Text('복원'),
            ),
          ],
        );
      },
    );
  }

  /// 영구 삭제
  void _showPermanentDeleteDialog(PageData page) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('영구 삭제'),
          content: Text('"${page.title}" 페이지를 영구적으로 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // 다이얼로그 먼저 닫기

                try {
                  final repository = Provider.of<PageRepository>(context, listen: false);
                  await repository.permanentlyDelete(page.id);

                  // 로컬 목록에서도 제거하여 즉시 반영 (UX 향상)
                  if (mounted) {
                    setState(() {
                      _deletedPages.removeWhere((p) => p.id == page.id);
                    });
                  }

                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('"${page.title}" 페이지가 영구 삭제되었습니다.')),
                  );

                  debugPrint('✅ 페이지 영구 삭제 완료: ${page.id}');
                } catch (e) {
                  debugPrint('❌ 페이지 영구 삭제 실패: $e');

                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('영구 삭제 실패: $e')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('영구 삭제'),
            ),
          ],
        );
      },
    );
  }

  /// 휴지통 전체 비우기
  void _showEmptyTrashDialog() {
    if (_deletedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('휴지통이 이미 비어있습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('휴지통 비우기'),
          content: Text('${_deletedPages.length}개의 페이지를 모두 영구 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  final repository = Provider.of<PageRepository>(context, listen: false);
                  await repository.emptyTrash();

                  if (mounted) {
                    setState(() {
                      _deletedPages.clear();
                    });
                  }

                  if (!mounted) return;
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('휴지통이 비워졌습니다.')),
                  );

                  debugPrint('✅ 휴지통 비우기 완료');
                } catch (e) {
                  debugPrint('❌ 휴지통 비우기 실패: $e');

                  if (!mounted) return; 
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('휴지통 비우기 실패: $e')),
                  );
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('전체 삭제'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_deletedPages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: '휴지통 비우기',
              onPressed: _showEmptyTrashDialog,
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('완료', style: TextStyle(fontSize: 16)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '페이지 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredPages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty ? '휴지통이 비어있습니다.' : '검색 결과가 없습니다.',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredPages.length,
                  itemBuilder: (context, index) {
                    final page = _filteredPages[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const Icon(Icons.description_outlined, size: 18),
                      title: Text(page.title, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '삭제됨: ${_formatDate(page.lastEdited)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz, size: 18),
                        onSelected: (value) {
                          if (value == 'restore') {
                            _showRestoreDialog(page);
                          } else if (value == 'delete') {
                            _showPermanentDeleteDialog(page);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(Icons.restore, size: 18),
                                SizedBox(width: 8),
                                Text('복원'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_forever, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('영구 삭제', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month}.${date.day}';
  }
}