import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../repositories/page_repository.dart';
import '../data/page_data.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<PageData> _trashedPages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);

    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      final pages = await repository.getTrash();

      if (!mounted) return;

      setState(() {
        _trashedPages = pages;
        _isLoading = false;
      });

      debugPrint('휴지통 로드: ${pages.length}개');
      for (var page in pages) {
        debugPrint('  - ${page.title} (parentId: ${page.parentId})');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('휴지통을 불러오는데 실패했습니다: $e')),
        );
      }
    }
  }

  Future<void> _restorePage(PageData page) async {
    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      
      debugPrint('복원 시작: ${page.title} (id: ${page.id}, parentId: ${page.parentId})');
      
      await repository.restoreFromTrash(page.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${page.title} 복원 완료')),
      );

      // 휴지통 새로고침
      await _loadTrash();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('복원 실패: $e')),
      );
    }
  }

  Future<void> _permanentlyDelete(PageData page) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영구 삭제'),
        content: Text('${page.title}을(를) 영구적으로 삭제하시겠습니까?'),
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

    if (confirm != true) return;

    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.permanentlyDelete(page.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${page.title} 영구 삭제됨')),
      );

      await _loadTrash();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('영구 삭제 실패: $e')),
      );
    }
  }

  Future<void> _emptyTrash() async {
    if (_trashedPages.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('휴지통 비우기'),
        content: const Text('모든 항목을 영구적으로 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('비우기'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repository = Provider.of<PageRepository>(context, listen: false);
      await repository.emptyTrash();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('휴지통이 비워졌습니다')),
      );

      await _loadTrash();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('휴지통 비우기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('휴지통'),
        actions: [
          if (_trashedPages.isNotEmpty)
            TextButton(
              onPressed: _emptyTrash,
              child: const Text('비우기', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashedPages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '휴지통이 비어있습니다',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _trashedPages.length,
                  itemBuilder: (context, index) {
                    final page = _trashedPages[index];
                    return ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(page.title),
                      subtitle: Text(
                        '삭제일: ${_formatDate(page.lastEdited)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore, color: Colors.blue),
                            onPressed: () => _restorePage(page),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: () => _permanentlyDelete(page),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}
