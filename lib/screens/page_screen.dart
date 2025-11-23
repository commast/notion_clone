import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/page_data.dart';
import '../utils/font_provider.dart';

import '../widgets/common/notion_bottom_bar.dart';

import '../widgets/editor/editable_text_block.dart';
import '../widgets/editor/keyboard_accessory_bar.dart';
import '../widgets/editor/block_selector_modal.dart';

import '../widgets/blocks/notion_table.dart';
import '../widgets/blocks/code_block.dart';
import '../widgets/blocks/notion_chart.dart';
import '../widgets/blocks/image_block.dart';
import '../widgets/blocks/heading_block.dart';
import '../widgets/blocks/bulleted_list_block.dart';
import '../widgets/blocks/numbered_list_block.dart';
import '../widgets/blocks/todo_list_block.dart';
import '../widgets/blocks/toggle_list_block.dart';
import '../widgets/blocks/callout_block.dart';
import '../widgets/blocks/quote_block.dart';
import '../widgets/blocks/divider_block.dart';
import '../widgets/blocks/page_link_block.dart';

class NotionPageScreen extends StatefulWidget {
  final PageData page;
  final VoidCallback? onNewPage;
  final VoidCallback? onPageChanged;
  final Function(PageData)? onFavoriteToggle;
  final Function(PageData)? onDuplicate;
  final Function(PageData)? onMove;
  final Function(PageData)? onDelete;
  final List<PageData>? allPages;
  final Function(PageData)? onPageCreated; // ✅ 새 페이지 생성 콜백

  const NotionPageScreen({
    super.key,
    required this.page,
    this.onNewPage,
    this.onPageChanged,
    this.onFavoriteToggle,
    this.onDuplicate,
    this.onMove,
    this.onDelete,
    this.allPages,
    this.onPageCreated, // ✅ 추가
  });

  @override
  State<NotionPageScreen> createState() => _NotionPageScreenState();
}

class _NotionPageScreenState extends State<NotionPageScreen> {
  late List<BlockData> _currentBlocks;
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentBlocks = getPageBlocks(widget.page.id);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _currentBlocks.add(BlockData(type: 'image', content: pickedFile.path));
        });
      }
    } catch (e) {
      debugPrint("이미지 불러오기 실패: $e");
    }
    if (mounted) Navigator.pop(context);
  }

  void _showImagePickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "이미지 추가",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.black87),
                title: const Text("갤러리에서 선택"),
                onTap: () => _pickImage(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.black87),
                title: const Text("사진 촬영"),
                onTap: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _addBlock(String blockType) {
    setState(() {
      switch (blockType) {
        case 'text':
          _currentBlocks.add(BlockData(type: 'text', content: ''));
          break;
        case 'heading1':
          _currentBlocks.add(BlockData(type: 'heading1', content: ''));
          break;
        case 'heading2':
          _currentBlocks.add(BlockData(type: 'heading2', content: ''));
          break;
        case 'heading3':
          _currentBlocks.add(BlockData(type: 'heading3', content: ''));
          break;
        case 'bulleted_list':
          _currentBlocks.add(BlockData(type: 'bulleted_list', content: ''));
          break;
        case 'numbered_list':
          int nextNumber = 1;
          for (var block in _currentBlocks) {
            if (block.type == 'numbered_list') {
              final data = block.content as Map<String, dynamic>;
              int num = data['number'] ?? 1;
              if (num >= nextNumber) {
                nextNumber = num + 1;
              }
            }
          }
          _currentBlocks.add(BlockData(
            type: 'numbered_list',
            content: {'number': nextNumber, 'text': ''},
          ));
          break;
        case 'todo_list':
          _currentBlocks.add(BlockData(
            type: 'todo_list',
            content: {'checked': false, 'text': ''},
          ));
          break;
        case 'toggle_list':
          _currentBlocks.add(BlockData(
            type: 'toggle_list',
            content: {'title': '', 'content': ''},
          ));
          break;
        case 'page':
          // ✅ 새 페이지 생성 및 홈 화면에 추가
          final newPageId = DateTime.now().millisecondsSinceEpoch.toString();
          final newPageTitle = '제목 없음';
          
          final newPage = PageData(
            id: newPageId,
            title: newPageTitle,
            lastEdited: DateTime.now(),
          );
          
          // ✅ 홈 화면에 페이지 추가
          if (widget.onPageCreated != null) {
            widget.onPageCreated!(newPage);
          }
          
          _currentBlocks.add(BlockData(
            type: 'page',
            content: '$newPageId|$newPageTitle',
          ));
          break;
        case 'callout':
          _currentBlocks.add(BlockData(type: 'callout', content: ''));
          break;
        case 'quote':
          _currentBlocks.add(BlockData(type: 'quote', content: ''));
          break;
        case 'divider':
          _currentBlocks.add(BlockData(type: 'divider', content: null));
          break;
        case '표':
          Navigator.pop(context);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (BuildContext context) {
              return TableSizeSelectorModal(
                onTableCreated: (rows, cols) {
                  setState(() {
                    _currentBlocks.add(BlockData(type: 'table', content: {'rows': rows, 'cols': cols}));
                  });
                  Navigator.pop(context);
                },
              );
            },
          );
          return;
        case '코드':
          _currentBlocks.add(BlockData(type: 'code', content: ''));
          break;
        case '막대 차트':
          _currentBlocks.add(BlockData(type: 'chart', content: null));
          break;
        default:
          _currentBlocks.add(BlockData(type: 'text', content: ''));
      }
    });
    Navigator.pop(context);
  }

  void _showBlockSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return BlocSelectorModal(onBlockSelected: _addBlock);
      },
    );
  }

  void _showPageActionsMenu() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: _PageActionsDialog(
          page: widget.page,
          onFontChanged: () => setState(() {}),
          onFavoriteToggle: () {
            if (widget.onFavoriteToggle != null) {
              widget.onFavoriteToggle!(widget.page);
            }
            setState(() {});
          },
          onDuplicate: () {
            if (widget.onDuplicate != null) {
              widget.onDuplicate!(widget.page);
              Navigator.pop(context);
            }
          },
          onMove: () {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (widget.onMove != null) {
                widget.onMove!(widget.page);
              }
            });
          },
          onDelete: () {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              if (widget.onDelete != null) {
                widget.onDelete!(widget.page);
              }
            });
          },
        ),
      ),
    );
  }

  void _showPageNavigationDialog() {
    if (widget.allPages == null || widget.allPages!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이동 가능한 페이지가 없습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: _PageNavigationDialog(
          allPages: widget.allPages!,
          currentPage: widget.page,
          onPageSelected: (selectedPage) {
            Navigator.pop(context);
            
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NotionPageScreen(
                  page: selectedPage,
                  onNewPage: widget.onNewPage,
                  onPageChanged: widget.onPageChanged,
                  onFavoriteToggle: widget.onFavoriteToggle,
                  onDuplicate: widget.onDuplicate,
                  onMove: widget.onMove,
                  onDelete: widget.onDelete,
                  allPages: widget.allPages,
                  onPageCreated: widget.onPageCreated,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardVisible = keyboardHeight > 0;
    final double bottomBarHeight = 50.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _showPageNavigationDialog,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.description_outlined, size: 18),
              SizedBox(width: 4),
              Text(
                '개인 페이지',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
              Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showPageActionsMenu(),
          ),
        ],
      ),

      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _currentBlocks.length + 1,
        itemBuilder: (context, index) {
          if (index == _currentBlocks.length) {
            return SizedBox(height: isKeyboardVisible ? 0 : bottomBarHeight);
          }

          final block = _currentBlocks[index];

          switch (block.type) {
            case 'title':
              return EditableTextBlock(
                initialText: block.content as String,
                isTitle: true,
                focusNode: _focusNode,
                pageId: widget.page.id,
                onChanged: (val) {
                  block.content = val;
                  widget.page.title = val;
                  widget.page.lastEdited = DateTime.now();
                  widget.onPageChanged?.call();
                  setState(() {});
                },
              );
            
            case 'text':
              return EditableTextBlock(
                key: ValueKey(block),
                initialText: block.content as String,
                isTitle: false,
                pageId: widget.page.id,
                onChanged: (val) => block.content = val,
              );
            
            case 'heading1':
              return HeadingBlock(
                key: ValueKey(block),
                level: 1,
                content: block.content as String,
                pageId: widget.page.id,
                onChanged: (val) {
                  block.content = val;
                  widget.page.lastEdited = DateTime.now();
                },
              );
            
            case 'heading2':
              return HeadingBlock(
                key: ValueKey(block),
                level: 2,
                content: block.content as String,
                pageId: widget.page.id,
                onChanged: (val) {
                  block.content = val;
                  widget.page.lastEdited = DateTime.now();
                },
              );
            
            case 'heading3':
              return HeadingBlock(
                key: ValueKey(block),
                level: 3,
                content: block.content as String,
                pageId: widget.page.id,
                onChanged: (val) {
                  block.content = val;
                  widget.page.lastEdited = DateTime.now();
                },
              );
            
            case 'bulleted_list':
              return BulletedListBlock(
                key: ValueKey(block),
                content: block.content as String,
                pageId: widget.page.id,
                onChanged: (val) => block.content = val,
                onEnterPressed: () {
                  setState(() {
                    final idx = _currentBlocks.indexOf(block);
                    _currentBlocks.insert(idx + 1, BlockData(type: 'bulleted_list', content: ''));
                  });
                },
              );
            
            case 'numbered_list':
              final data = block.content as Map<String, dynamic>;
              return NumberedListBlock(
                key: ValueKey(block),
                number: data['number'] ?? 1,
                content: data['text'] ?? '',
                pageId: widget.page.id,
                onChanged: (val) {
                  data['text'] = val;
                  block.content = data;
                },
                onEnterPressed: () {
                  setState(() {
                    final idx = _currentBlocks.indexOf(block);
                    final nextNumber = (data['number'] ?? 1) + 1;
                    _currentBlocks.insert(
                      idx + 1,
                      BlockData(
                        type: 'numbered_list',
                        content: {'number': nextNumber, 'text': ''},
                      ),
                    );
                  });
                },
              );
            
            case 'todo_list':
              final data = block.content as Map<String, dynamic>;
              return TodoListBlock(
                key: ValueKey(block),
                isChecked: data['checked'] ?? false,
                content: data['text'] ?? '',
                pageId: widget.page.id,
                onCheckedChanged: (checked) {
                  setState(() {
                    data['checked'] = checked;
                    block.content = data;
                  });
                },
                onContentChanged: (val) {
                  data['text'] = val;
                  block.content = data;
                },
                onEnterPressed: () {
                  setState(() {
                    final idx = _currentBlocks.indexOf(block);
                    _currentBlocks.insert(
                      idx + 1,
                      BlockData(
                        type: 'todo_list',
                        content: {'checked': false, 'text': ''},
                      ),
                    );
                  });
                },
              );
            
            case 'toggle_list':
              final data = block.content as Map<String, dynamic>;
              return ToggleListBlock(
                key: ValueKey(block),
                title: data['title'] ?? '',
                content: data['content'] ?? '',
                pageId: widget.page.id,
                onTitleChanged: (val) {
                  data['title'] = val;
                  block.content = data;
                },
                onContentChanged: (val) {
                  data['content'] = val;
                  block.content = data;
                },
                onEnterPressed: () {
                  setState(() {
                    final idx = _currentBlocks.indexOf(block);
                    _currentBlocks.insert(
                      idx + 1,
                      BlockData(
                        type: 'toggle_list',
                        content: {'title': '', 'content': ''},
                      ),
                    );
                  });
                },
              );
            
            case 'callout':
              return CalloutBlock(
                key: ValueKey(block),
                content: block.content as String,
                pageId: widget.page.id,
                onChanged: (val) => block.content = val,
              );
            
            case 'quote':
              return QuoteBlock(
                key: ValueKey(block),
                content: block.content as String,
                pageId: widget.page.id,
                onChanged: (val) => block.content = val,
              );
            
            case 'divider':
              return const DividerBlock();
            
            case 'page':
              final contentStr = block.content as String;
              final parts = contentStr.split('|');
              final pageId = parts[0];
              final pageTitle = parts.length > 1 ? parts[1] : '제목 없음';
              
              return PageLinkBlock(
                key: ValueKey(block),
                pageTitle: pageTitle,
                onTap: () {
                  // ✅ 페이지 찾기 (widget.allPages에서)
                  PageData? targetPage;
                  if (widget.allPages != null) {
                    for (var p in widget.allPages!) {
                      if (p.id == pageId) {
                        targetPage = p;
                        break;
                      }
                    }
                  }
                  
                  if (targetPage != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NotionPageScreen(
                          page: targetPage!,
                          onNewPage: widget.onNewPage,
                          onPageChanged: widget.onPageChanged,
                          onFavoriteToggle: widget.onFavoriteToggle,
                          onDuplicate: widget.onDuplicate,
                          onMove: widget.onMove,
                          onDelete: widget.onDelete,
                          allPages: widget.allPages,
                          onPageCreated: widget.onPageCreated,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('페이지를 찾을 수 없습니다')),
                    );
                  }
                },
              );
            
            case 'code':
              return CodeBlock(key: ValueKey(block));
            
            case 'chart':
              return NotionChart(key: ValueKey(block));
            
            case 'table':
              final Map<String, int> size = block.content as Map<String, int>;
              return NotionTable(
                rows: size['rows']!,
                cols: size['cols']!,
                key: ValueKey(block),
              );
            
            case 'image':
              return ImageBlock(imageFile: File(block.content as String));
            
            default:
              return const SizedBox.shrink();
          }
        },
      ),

      bottomSheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isKeyboardVisible)
            KeyboardAccessoryBar(
              onPlusPressed: _showBlockSelector,
              onImagePressed: _showImagePickerModal,
            )
          else
            NotionBottomBar(
              onNewPage: widget.onNewPage,
            ),
        ],
      ),

      floatingActionButton: isKeyboardVisible
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: bottomBarHeight + 10),
              child: FloatingActionButton(
                onPressed: widget.onNewPage,
                backgroundColor: Colors.white,
                shape: const CircleBorder(),
                elevation: 6.0,
                child: const Icon(Icons.mode_edit_outline, color: Colors.black),
              ),
            ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ... (나머지 Dialog 클래스들은 동일)


//페이지 이동 다이얼로그
class _PageNavigationDialog extends StatefulWidget {
  final List<PageData> allPages;
  final PageData currentPage;
  final Function(PageData) onPageSelected;

  const _PageNavigationDialog({
    required this.allPages,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  State<_PageNavigationDialog> createState() => _PageNavigationDialogState();
}

class _PageNavigationDialogState extends State<_PageNavigationDialog> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<PageData> get _filteredPages {
    if (_searchQuery.isEmpty) {
      return widget.allPages;
    }
    
    return widget.allPages.where((page) {
      return page.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 제목
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '페이지 이동',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          // 검색창
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '페이지 검색...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // 페이지 목록
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: _filteredPages.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          '검색 결과가 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredPages.length,
                      itemBuilder: (context, index) {
                        final page = _filteredPages[index];
                        final isCurrentPage = page.id == widget.currentPage.id;
                        
                        return ListTile(
                          contentPadding: EdgeInsets.only(
                            left: 20.0 + (page.level * 20.0),
                            right: 20.0,
                          ),
                          leading: Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: isCurrentPage ? Colors.blue : Colors.black54,
                          ),
                          title: Text(
                            page.title,
                            style: TextStyle(
                              fontSize: 14,
                              color: isCurrentPage ? Colors.blue : Colors.black,
                              fontWeight: isCurrentPage ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isCurrentPage
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                  size: 18,
                                )
                              : null,
                          enabled: !isCurrentPage,
                          onTap: isCurrentPage
                              ? null
                              : () => widget.onPageSelected(page),
                        );
                      },
                    ),
            ),
          ),
          
          const SizedBox(height: 10),

          // 닫기 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '닫기',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 페이지 작업 다이얼로그
class _PageActionsDialog extends StatefulWidget {
  final PageData page;
  final VoidCallback onFontChanged;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onDuplicate;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  const _PageActionsDialog({
    required this.page,
    required this.onFontChanged,
    required this.onFavoriteToggle,
    required this.onDuplicate,
    required this.onMove,
    required this.onDelete,
  });

  @override
  State<_PageActionsDialog> createState() => _PageActionsDialogState();
}

class _PageActionsDialogState extends State<_PageActionsDialog> {
  void _copyPageLink() async {
    final pageId = widget.page.id;
    
    await Clipboard.setData(ClipboardData(text: pageId));
    
    if (mounted) Navigator.pop(context);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    '페이지 ID가 복사되었습니다',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                pageId,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              const Text(
                '💡 검색창에 붙여넣기하여 페이지를 찾으세요',
                style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
@override
Widget build(BuildContext context) {
  final fontProvider = Provider.of<FontProvider>(context);
  final currentFont = fontProvider.getFontFamily(widget.page.id);
  final bool isFavorite = widget.page.isFavorite;

  return Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            '작업',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _FontButton(
                label: '기본',
                isSelected: currentFont == FontFamily.basic,
                onTap: () {
                  fontProvider.setFontFamily(widget.page.id, FontFamily.basic);
                  widget.onFontChanged();
                },
              ),
              const SizedBox(width: 8),
              _FontButton(
                label: '세리프',
                isSelected: currentFont == FontFamily.serif,
                onTap: () {
                  fontProvider.setFontFamily(widget.page.id, FontFamily.serif);
                  widget.onFontChanged();
                },
              ),
              const SizedBox(width: 8),
              _FontButton(
                label: '모노',
                isSelected: currentFont == FontFamily.mono,
                onTap: () {
                  fontProvider.setFontFamily(widget.page.id, FontFamily.mono);
                  widget.onFontChanged();
                },
              ),
            ],
          ),
        ),
        
        const Divider(height: 32),

        _ActionMenuItem(
          icon: isFavorite ? Icons.star : Icons.star_border,
          title: isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가',
          iconColor: Colors.amber,
          onTap: () {
            widget.onFavoriteToggle();
            Navigator.pop(context);
          },
        ),
        
        _ActionMenuItem(
          icon: Icons.link,
          title: '링크 복사',
          onTap: _copyPageLink,
        ),
        
        _ActionMenuItem(
          icon: Icons.content_copy,
          title: '복제',
          onTap: widget.onDuplicate,
        ),
        
        _ActionMenuItem(
          icon: Icons.drive_file_move_outline,
          title: '옮기기',
          onTap: widget.onMove,
        ),
        
        _ActionMenuItem(
          icon: Icons.delete_outline,
          title: '휴지통으로 이동',
          iconColor: Colors.red,
          textColor: Colors.red,
          onTap: widget.onDelete,
        ),
      ],
    ),
  );
}
  
}

class _FontButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FontButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blue : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  const _ActionMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: iconColor),
      title: Text(
        title,
        style: TextStyle(fontSize: 15, color: textColor),
      ),
      onTap: onTap,
    );
  }
}
