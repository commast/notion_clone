import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/page_repository.dart';
import '../screens/search_screen.dart';
import '../data/page_data.dart';
import '../utils/font_provider.dart';

import '../widgets/common/notion_bottom_bar.dart';
import '../widgets/common/move_page_dialog.dart';

import '../widgets/editor/editable_text_block.dart';
import '../widgets/editor/keyboard_accessory_bar.dart';
import '../widgets/editor/block_selector_modal.dart';
import '../widgets/editor/color_picker_modal.dart';

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

  final void Function(PageData)? onPageChanged;
  final Function(PageData)? onFavoriteToggle;
  final Function(PageData)? onDuplicate;
  final Function(PageData)? onMove;
  final Function(PageData)? onDelete;
  final List<PageData>? allPages;
  final Function(PageData)? onPageCreated;

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
    this.onPageCreated,
  });

  @override
  State<NotionPageScreen> createState() => _NotionPageScreenState();
}

class _NotionPageScreenState extends State<NotionPageScreen> {
  late List<BlockData> _currentBlocks;
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  final List<List<BlockData>> _undoStack = [];
  int _currentFocusedBlockIndex = -1;

  bool _isLoading = true;

  PageRepository? _repository;

  bool get canUndo => _undoStack.isNotEmpty;

  Future<List<String>> _getTeamMemberUids(String teamSpaceId) async {
    final snap = await FirebaseFirestore.instance
        .collection('teamMembers')
        .where('teamSpaceId', isEqualTo: teamSpaceId)
        .get();

    return snap.docs
        .map((d) => (d.data()['userUid'] ?? '').toString())
        .where((uid) => uid.isNotEmpty)
        .toList();
  }

  Future<void> _sharePageToCurrentTeam(PageData targetPage) async {
    final currentTeamSpaceId = widget.page.teamSpaceId;
    if (currentTeamSpaceId == null) return;

    final repo = Provider.of<PageRepository>(context, listen: false);

    // 현재 팀스페이스의 멤버 목록 가져오기
    final memberUids = await _getTeamMemberUids(currentTeamSpaceId);

    // ✅ 링크 대상 페이지를 "현재 팀스페이스" 소속으로 맞추기
    await FirebaseFirestore.instance
        .collection('pages')
        .doc(targetPage.id)
        .update({'teamSpaceId': currentTeamSpaceId});

    // ✅ 기존 공유 로직(멤버 권한 부여)
    await repo.promotePageToTeam(pageId: targetPage.id, memberUids: memberUids);

    // 로컬 객체도 반영
    targetPage.teamSpaceId = currentTeamSpaceId;
  }

  Future<void> _createSubPageAndOpen() async {
    final repository = Provider.of<PageRepository>(context, listen: false);
    final newPage = PageData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '제목 없음',
      lastEdited: DateTime.now(),
      parentId: widget.page.id, // 현재 페이지를 부모로
      parentPage: widget.page,
    );

    try {
      await repository.createPage(newPage);

      final defaultBlocks = [
        BlockData(type: 'title', content: newPage.title),
        BlockData(type: 'text', content: ''),
      ];
      await repository.saveBlocks(newPage.id, defaultBlocks);
      savePageBlocks(newPage.id, defaultBlocks);

      if (widget.onPageCreated != null) {
        widget.onPageCreated!(newPage);
      }

      _openPage(newPage); // 새 페이지로 이동
    } catch (e) {
      debugPrint('하위 페이지 생성 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('페이지 생성 실패: $e')));
      }
    }
  }

  void _showBlockMenu(int index) {
    if (index < 0 || index >= _currentBlocks.length) return;

    final block = _currentBlocks[index];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('복제'),
                onTap: () {
                  Navigator.pop(context);
                  _saveState();

                  final original = _currentBlocks[index];
                  final duplicated = BlockData(
                    type: original.type,
                    content: _copyContent(original.content),
                    textColor: original.textColor,
                    backgroundColor: original.backgroundColor,
                    targetPageId: original.targetPageId,
                    linkedPageId: original.linkedPageId,
                  );

                  setState(() {
                    _currentBlocks.insert(index + 1, duplicated);
                  });
                },
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _saveState();
                  setState(() {
                    _currentBlocks.removeAt(index);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<PageData> _getAllPages() {
    final roots = widget.allPages ?? [];
    final result = <PageData>[];

    void collect(PageData page) {
      result.add(page);
      for (final sub in page.subPages) {
        collect(sub);
      }
    }

    for (final root in roots) {
      collect(root);
    }

    return result;
  }

  void _openPage(PageData page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageScreen(
          page: page,
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
  }

  @override
  void initState() {
    super.initState();
    _loadPageData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    //repository를 미리 저장
    _repository = Provider.of<PageRepository>(context, listen: false);
  }

  @override
  void dispose() {
    _savePageData();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // _repository 사용
      final repository =
          _repository ?? Provider.of<PageRepository>(context, listen: false);
      final blocks = await repository.getBlocks(widget.page.id);

      if (blocks.isNotEmpty) {
        setState(() {
          _currentBlocks = blocks;
          _isLoading = false;
        });
        debugPrint('Firebase에서 블록 로드: ${blocks.length}개');
      } else {
        setState(() {
          _currentBlocks = getPageBlocks(widget.page.id);
          _isLoading = false;
        });
        debugPrint('로컬 메모리에서 블록 로드');
      }
    } catch (e) {
      debugPrint('블록 로드 실패: $e');
      setState(() {
        _currentBlocks = getPageBlocks(widget.page.id);
        _isLoading = false;
      });
    }
  }

  Future<void> _savePageData() async {
    // _repository가 없으면 저장 안 함
    if (_repository == null) {
      debugPrint('Repository가 없어 저장 건너뜀');
      return;
    }

    try {
      // 페이지 제목 저장
      await _repository!.updatePage(widget.page);

      // 블록 내용 저장
      await _repository!.saveBlocks(widget.page.id, _currentBlocks);

      // 로컬 메모리에도 저장
      savePageBlocks(widget.page.id, _currentBlocks);

      debugPrint('페이지 데이터 저장 완료: ${widget.page.title}');
    } catch (e) {
      debugPrint('페이지 데이터 저장 실패: $e');
    }
  }

  // 같은 부모를 가진 형제 페이지들 가져오기
  List<PageData> get _siblingPages {
    if (widget.allPages == null) return [];

    return widget.allPages!
        .where((p) => p.parentId == widget.page.parentId)
        .toList()
      ..sort((a, b) => a.lastEdited.compareTo(b.lastEdited));
  }

  // 이전 페이지 가져오기
  PageData? get _previousPage {
    final siblings = _siblingPages;
    if (siblings.isEmpty) return null;

    final currentIndex = siblings.indexWhere((p) => p.id == widget.page.id);
    if (currentIndex > 0) {
      return siblings[currentIndex - 1];
    }
    return null;
  }

  // 다음 페이지 가져오기
  PageData? get _nextPage {
    final siblings = _siblingPages;
    if (siblings.isEmpty) return null;

    final currentIndex = siblings.indexWhere((p) => p.id == widget.page.id);
    if (currentIndex >= 0 && currentIndex < siblings.length - 1) {
      return siblings[currentIndex + 1];
    }
    return null;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final path = file.path;
        if (path == null) return;

        _saveState();
        setState(() {
          // 원하는 타입으로 저장
          _currentBlocks.add(
            BlockData(
              type: 'file',
              content: path, // 파일 경로 저장
            ),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${file.name}" 파일이 추가되었습니다.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("파일 불러오기 실패: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('파일을 불러오지 못했습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // 페이지 이동
  void _navigateToPage(PageData page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NotionPageScreen(
          page: page,
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
  }

  void _saveState() {
    final stateCopy = _currentBlocks.map((block) {
      return BlockData(
        type: block.type,
        content: _copyContent(block.content),
        textColor: block.textColor,
        backgroundColor: block.backgroundColor,
        targetPageId: block.targetPageId,
        linkedPageId: block.linkedPageId,
      );
    }).toList();

    _undoStack.add(stateCopy);

    if (_undoStack.length > 20) {
      _undoStack.removeAt(0);
    }
  }

  dynamic _copyContent(dynamic content) {
    if (content is Map) {
      return Map.from(content);
    } else if (content is List) {
      return List.from(content);
    }
    return content;
  }

  void _undo() {
    if (canUndo) {
      setState(() {
        _currentBlocks = _undoStack.removeLast();
      });
    }
  }

  void _deleteCurrentLine() {
    if (_currentFocusedBlockIndex >= 0 &&
        _currentFocusedBlockIndex < _currentBlocks.length) {
      _saveState(); // 실행 취소(Undo)를 위해 상태 저장
      setState(() {
        _currentBlocks.removeAt(_currentFocusedBlockIndex);
        _currentFocusedBlockIndex = -1;
        FocusScope.of(context).unfocus();
      });
    }
  }

  void _showColorPicker() {
    if (_currentFocusedBlockIndex < 0 ||
        _currentFocusedBlockIndex >= _currentBlocks.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('색상을 적용할 블록을 먼저 선택해주세요'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ColorPickerModal(
          onColorSelected: (textColor, bgColor) {
            _saveState();
            setState(() {
              final block = _currentBlocks[_currentFocusedBlockIndex];
              if (textColor != null) {
                block.textColor = textColor;
              }
              if (bgColor != null) {
                block.backgroundColor = bgColor;
              }
            });
          },
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        _saveState();
        setState(() {
          _currentBlocks.add(
            BlockData(type: 'image', content: pickedFile.path),
          );
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
                "추가",
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
              ListTile(
                leading: const Icon(Icons.attach_file, color: Colors.black87),
                title: const Text("파일 추가"),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _addBlock(String blockType) async {
    //삽입할 위치 계산
    int insertIndex = _currentBlocks.length;
    if (_currentFocusedBlockIndex >= 0 &&
        _currentFocusedBlockIndex < _currentBlocks.length) {
      insertIndex = _currentFocusedBlockIndex + 1;
    }

    void insertNewBlock(BlockData newBlock) {
  setState(() {
    if (insertIndex > _currentBlocks.length) {
      insertIndex = _currentBlocks.length;
    }
    _currentBlocks.insert(insertIndex, newBlock);
    _currentFocusedBlockIndex = insertIndex;
  });
}

// 예: 페이지 선택 다이얼로그에서 PageData를 하나 고른 뒤
void _insertChartBlock() {
  insertNewBlock(
    BlockData(
      type: 'chart',
      content: [
        {
          'label': '1분기',
          'value': 80.0,
          'color': const Color(0xFF676EFF).value,
          'chartTitle': '분기별 성과 (막대 차트)',
        },
        {
          'label': '2분기',
          'value': 60.0,
          'color': const Color(0xFFF06543).value,
          'chartTitle': '분기별 성과 (막대 차트)',
        },
        {
          'label': '3분기',
          'value': 95.0,
          'color': const Color(0xFF43A047).value,
          'chartTitle': '분기별 성과 (막대 차트)',
        },
        {
          'label': '4분기',
          'value': 40.0,
          'color': const Color(0xFFFFCC00).value,
          'chartTitle': '분기별 성과 (막대 차트)',
        },
      ],
    ),
  );
}



    _saveState();

    switch (blockType) {
      case 'text':
        setState(() {
          insertNewBlock(BlockData(type: 'text', content: ''));
        });
        break;

      case 'heading1':
        setState(() {
          insertNewBlock(BlockData(type: 'heading1', content: ''));
        });
        break;

      case 'heading2':
        setState(() {
          insertNewBlock(BlockData(type: 'heading2', content: ''));
        });
        break;

      case 'heading3':
        setState(() {
          insertNewBlock(BlockData(type: 'heading3', content: ''));
        });
        break;

      case 'bulleted_list':
        setState(() {
          insertNewBlock(BlockData(type: 'bulleted_list', content: ''));
        });
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
        insertNewBlock(
          BlockData(
            type: 'numbered_list',
            content: {'number': nextNumber, 'text': ''},
          ),
        );
        break;

      case 'todo_list':
        insertNewBlock(
          BlockData(type: 'todo_list', content: {'checked': false, 'text': ''}),
        );
        break;

      case 'toggle_list':
        insertNewBlock(
          BlockData(type: 'toggle_list', content: {'title': '', 'content': ''}),
        );
        break;

      case 'page':
        final newPageId = DateTime.now().millisecondsSinceEpoch.toString();
        final newPageTitle = '제목 없음';

        final newPage = PageData(
          id: newPageId,
          title: newPageTitle,
          lastEdited: DateTime.now(),
          parentId: widget.page.id,
          parentPage: widget.page,
        );

        final repository = Provider.of<PageRepository>(context, listen: false);

        try {
          await repository.createPage(newPage);

          final defaultBlocks = [
            BlockData(type: 'title', content: newPageTitle),
            BlockData(type: 'text', content: ''),
          ];

          await repository.saveBlocks(newPageId, defaultBlocks);
          savePageBlocks(newPageId, defaultBlocks);

          debugPrint('하위 페이지 생성 완료: $newPageId');

          if (widget.onPageCreated != null) {
            widget.onPageCreated!(newPage);
          }

          insertNewBlock(
            BlockData(type: 'page', content: '$newPageId|$newPageTitle'),
          );
        } catch (e) {
          debugPrint('하위 페이지 생성 실패: $e');

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('페이지 생성 실패: $e')));
          }
        }
        break;

      case 'callout':
        insertNewBlock(BlockData(type: 'callout', content: ''));
        break;

      case 'quote':
        insertNewBlock(BlockData(type: 'quote', content: ''));
        break;

      case 'divider':
        insertNewBlock(BlockData(type: 'divider', content: null));
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
                _saveState();
                // [수정] insertNewBlock 사용
                insertNewBlock(
                  BlockData(
                    type: 'table',
                    content: {'rows': rows, 'cols': cols},
                  ),
                );
                Navigator.pop(context);
              },
            );
          },
        );
        return;

      case '코드':
        insertNewBlock(BlockData(type: 'code', content: ''));
        break;

      case '막대 차트':
        insertNewBlock(
          BlockData(
            type: 'chart',
            // 🔹 처음엔 비어 있는 리스트만 저장 (차트 위젯이 기본 예시 데이터를 채움)
            content: <Map<String, dynamic>>[],
          ),
        );
        break;

      case 'page_link':
        // 1) 링크할 페이지 선택
        if (widget.allPages == null || widget.allPages!.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('링크할 수 있는 페이지가 없습니다.')));
          break;
        }

        final selectedPage = await showDialog<PageData>(
          context: context,
          builder: (_) => MovePageDialog(
            allPages: widget.allPages!,
            currentPage: widget.page,
          ),
        );

        if (selectedPage == null) break;

        // ✅ 현재 페이지가 "공유(팀) 페이지"인지 확인
        final String? currentTeamSpaceId = widget.page.teamSpaceId;
        final bool isTeamPage = currentTeamSpaceId != null;

        if (isTeamPage) {
          final bool selectedAlreadySharedToSameTeam =
              (selectedPage.teamSpaceId != null &&
              selectedPage.teamSpaceId == currentTeamSpaceId);

          // 링크 대상이 아직 팀에 공유되지 않았으면 "같이 공유" 옵션 띄우기
          if (!selectedAlreadySharedToSameTeam) {
            final action = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('링크 페이지 공유'),
                content: const Text(
                  '이 페이지는 아직 팀에 공유되지 않았습니다.\n'
                  '팀원들도 링크를 열 수 있게 하려면\n'
                  '이 페이지도 같이 공유해야 합니다.\n\n'
                  '지금 같이 공유할까요?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'cancel'),
                    child: const Text('취소'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, 'link_only'),
                    child: const Text('링크만 추가'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, 'share_and_link'),
                    child: const Text('공유하고 링크'),
                  ),
                ],
              ),
            );

            if (action == 'cancel' || action == null) break;

            if (action == 'share_and_link') {
              try {
                await _sharePageToCurrentTeam(selectedPage);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('공유 실패: $e')));
                }
                break;
              }
            }
            // link_only면 그냥 링크는 추가되지만, 팀원은 못 열 수 있음
          }
        }

        // 2) 링크 블록 추가
        insertNewBlock(
          BlockData(
            type: 'page_link',
            content: selectedPage.title,
            linkedPageId: selectedPage.id,
            targetPageId: selectedPage.id,
          ),
        );
        break;

      default:
        setState(() {
          _currentBlocks.add(BlockData(type: 'text', content: ''));
        });
    }

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  void _showMembersDialog() async {
    final controller = TextEditingController();
    final repo = Provider.of<PageRepository>(context, listen: false);
    final firestore = FirebaseFirestore.instance;

    // 항상 최신 페이지 문서를 Firestore에서 읽어서 teamSpaceId 가져오기
    final pageSnap = await firestore
        .collection('pages')
        .doc(widget.page.id)
        .get();
    final data = pageSnap.data();
    final String? teamSpaceId = data?['teamSpaceId'] as String?;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('팀원 초대'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (teamSpaceId != null)
                    SizedBox(
                      height: 120,
                      child: StreamBuilder<QuerySnapshot>(
                        stream: firestore
                            .collection('teamMembers')
                            .where('teamSpaceId', isEqualTo: teamSpaceId)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Center(child: Text('아직 팀원이 없습니다.'));
                          }
                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final m =
                                  docs[index].data() as Map<String, dynamic>;
                              final role = m['role'] ?? 'member';
                              final uid = m['userUid'] ?? '';

                              return FutureBuilder<DocumentSnapshot>(
                                future: firestore
                                    .collection('users')
                                    .doc(uid)
                                    .get(),
                                builder: (context, userSnap) {
                                  String emailText = uid; // fallback
                                  if (userSnap.hasData &&
                                      userSnap.data!.data() != null) {
                                    final u =
                                        userSnap.data!.data()
                                            as Map<String, dynamic>;
                                    emailText = u['email'] ?? uid;
                                  }

                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.person, size: 20),
                                    title: Text(emailText),
                                    subtitle: Text(role),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: '이메일 입력'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final email = controller.text.trim();
                debugPrint('invite pressed: $email');
                if (email.isEmpty) return;

                try {
                  final snap = await firestore
                      .collection('users')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();
                  debugPrint('users query docs: ${snap.docs.length}');

                  if (snap.docs.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('해당 이메일 사용자를 찾을 수 없습니다.')),
                      );
                    }
                    return;
                  }

                  final invitedUid = snap.docs.first.id;
                  debugPrint('invitedUid: $invitedUid');

                  await repo.promotePageToTeam(
                    pageId: widget.page.id,
                    memberUids: [invitedUid],
                  );
                  debugPrint('promotePageToTeam done (invite)');

                  widget.page.teamSpaceId =
                      teamSpaceId ?? 'some-team-id'; // 실제 값으로 세팅
                  if (widget.onPageChanged != null) {
                    widget.onPageChanged!(widget.page); // updatedPage 넘기기
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          teamSpaceId == null
                              ? '팀 페이지로 전환 및 초대 완료'
                              : '초대 처리 완료',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('invite error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('초대 실패: $e')));
                  }
                }
              },
              child: const Text('초대'),
            ),
          ],
        );
      },
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

    final allPagesFlat = _getAllPages();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: _PageNavigationDialog(
          allPages: allPagesFlat,
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

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('페이지 로딩 중...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                '페이지 탐색',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
              ),
              Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showMembersDialog,
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: _showPageActionsMenu,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            padding: EdgeInsets.only(left: 16.0, right: 16.0),
            itemCount: _currentBlocks.length + 1,
            itemBuilder: (context, index) {
              if (index == _currentBlocks.length) {
                // 키보드 / 바텀바 높이만큼 여백
                return SizedBox(
                  height: isKeyboardVisible ? 0 : bottomBarHeight,
                );
              }

              final block = _currentBlocks[index];
              Widget blockWidget;

              switch (block.type) {
                case 'title':
                  blockWidget = EditableTextBlock(
                    initialText: block.content as String,
                    isTitle: true,
                    focusNode: _focusNode,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) async {
                      block.content = val;
                      widget.page.title = val;
                      widget.page.lastEdited = DateTime.now();

                      // 제목이 바뀔 때마다 홈에 알림
                      widget.onPageChanged?.call(widget.page);

                      setState(() {});
                      if (_repository != null) {
                        try {
                          await _repository!.updatePage(widget.page);
                        } catch (e) {
                          debugPrint('update title error: $e');
                        }
                      }
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'text':
                  blockWidget = EditableTextBlock(
                    key: ValueKey(block),
                    initialText: block.content as String,
                    isTitle: false,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) => block.content = val,
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'file':
                  blockWidget = ListTile(
                    leading: const Icon(Icons.attach_file, size: 20),
                    title: Text(
                      (block.content as String).split('/').last, // 파일명만 표시
                      style: const TextStyle(fontSize: 14),
                    ),
                    onTap: () {},
                  );
                  break;

                case 'heading1':
                  blockWidget = HeadingBlock(
                    key: ValueKey(block),
                    level: 1,
                    content: block.content as String,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) {
                      block.content = val;
                      widget.page.lastEdited = DateTime.now();
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'heading2':
                  blockWidget = HeadingBlock(
                    key: ValueKey(block),
                    level: 2,
                    content: block.content as String,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) {
                      block.content = val;
                      widget.page.lastEdited = DateTime.now();
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'heading3':
                  blockWidget = HeadingBlock(
                    key: ValueKey(block),
                    level: 3,
                    content: block.content as String,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) {
                      block.content = val;
                      widget.page.lastEdited = DateTime.now();
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'bulleted_list':
                  blockWidget = BulletedListBlock(
                    key: ValueKey(block),
                    content: block.content as String,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) {
                      setState(() {
                        block.content = val;
                      });
                    },
                    onEnterPressed: () {
                      _saveState();
                      setState(() {
                        final idx = _currentBlocks.indexOf(block);
                        _currentBlocks.insert(
                          idx + 1,
                          BlockData(type: 'bulleted_list', content: ''),
                        );
                      });
                    },
                    onBackspacePressed: () {
                      setState(() {
                        if ((block.content as String).isEmpty) {
                          _saveState();
                          final idx = _currentBlocks.indexOf(block);
                          _currentBlocks[idx] = BlockData(
                            type: 'text',
                            content: '',
                          );
                        }
                      });
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'numbered_list':
                  final data = block.content as Map<String, dynamic>;

                  final currentIndex = _currentBlocks.indexOf(block);

                  int displayNumber = 1;
                  for (int i = 0; i < currentIndex; i++) {
                    if (_currentBlocks[i].type == 'numbered_list') {
                      displayNumber++;
                    }
                  }

                  blockWidget = NumberedListBlock(
                    key: ValueKey(block),
                    number: displayNumber,
                    content: data['text'] ?? '',
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) {
                      setState(() {
                        data['text'] = val;
                        block.content = data;
                      });
                    },
                    onEnterPressed: () {
                      _saveState();
                      setState(() {
                        final idx = _currentBlocks.indexOf(block);
                        _currentBlocks.insert(
                          idx + 1,
                          BlockData(
                            type: 'numbered_list',
                            content: {'number': displayNumber + 1, 'text': ''},
                          ),
                        );
                      });
                    },
                    onBackspacePressed: () {
                      setState(() {
                        if ((data['text'] ?? '').isEmpty) {
                          _saveState();
                          final idx = _currentBlocks.indexOf(block);
                          _currentBlocks[idx] = BlockData(
                            type: 'text',
                            content: '',
                          );
                        }
                      });
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'todo_list':
                  final data = block.content as Map<String, dynamic>;
                  blockWidget = TodoListBlock(
                    key: ValueKey(block),
                    isChecked: data['checked'] ?? false,
                    content: data['text'] ?? '',
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onCheckedChanged: (checked) {
                      setState(() {
                        data['checked'] = checked;
                        block.content = data;
                      });
                    },
                    onContentChanged: (val) {
                      setState(() {
                        data['text'] = val;
                        block.content = data;
                      });
                    },
                    onEnterPressed: () {
                      _saveState();
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
                    onBackspacePressed: () {
                      setState(() {
                        if ((data['text'] ?? '').isEmpty) {
                          _saveState();
                          final idx = _currentBlocks.indexOf(block);
                          _currentBlocks[idx] = BlockData(
                            type: 'text',
                            content: '',
                          );
                        }
                      });
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'toggle_list':
                  final data = block.content as Map<String, dynamic>;
                  blockWidget = ToggleListBlock(
                    key: ValueKey(block),
                    title: data['title'] ?? '',
                    content: data['content'] ?? '',
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onTitleChanged: (val) {
                      setState(() {
                        data['title'] = val;
                        block.content = data;
                      });
                    },
                    onContentChanged: (val) {
                      setState(() {
                        data['content'] = val;
                        block.content = data;
                      });
                    },
                    onEnterPressed: () {
                      _saveState();
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
                    onBackspacePressed: () {
                      setState(() {
                        if ((data['title'] ?? '').isEmpty) {
                          _saveState();
                          final idx = _currentBlocks.indexOf(block);
                          _currentBlocks[idx] = BlockData(
                            type: 'text',
                            content: '',
                          );
                        }
                      });
                    },
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'callout':
                  blockWidget = CalloutBlock(
                    key: ValueKey(block),
                    content: block.content as String,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) => block.content = val,
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'quote':
                  blockWidget = QuoteBlock(
                    key: ValueKey(block),
                    content: block.content as String,
                    pageId: widget.page.id,
                    textColor: block.textColor,
                    onChanged: (val) => block.content = val,
                    onTap: () {
                      setState(() {
                        _currentFocusedBlockIndex = index;
                      });
                    },
                  );
                  break;

                case 'divider':
                  blockWidget = const DividerBlock();
                  break;

                case 'page':
                  final contentStr = block.content as String;
                  final parts = contentStr.split('|');
                  final pageId = parts[0];

                  // 항상 최신 PageData에서 제목을 찾기
                  String pageTitle = '제목 없음';

                  if (widget.allPages != null) {
                    try {
                      // 트리 전체에서 해당 id 페이지 찾기
                      final allPages = _getAllPages(); // 이미 위에 정의된 헬퍼
                      final target = allPages.firstWhere((p) => p.id == pageId);
                      pageTitle = target.title; // 최신 제목
                    } catch (_) {
                      // 못 찾으면 기존 content 안의 제목 사용
                      if (parts.length > 1 && parts[1].isNotEmpty) {
                        pageTitle = parts[1];
                      }
                    }
                  } else {
                    // allPages가 없을 때는 기존 방식 유지
                    if (parts.length > 1 && parts[1].isNotEmpty) {
                      pageTitle = parts[1];
                    }
                  }

                  blockWidget = PageLinkBlock(
                    key: ValueKey(block),
                    pageTitle: pageTitle,
                    onTap: () {
                      // 항상 트리 전체에서 검색
                      final allPages = _getAllPages();
                      PageData? targetPage;
                      try {
                        targetPage = allPages.firstWhere((p) => p.id == pageId);
                      } catch (_) {
                        targetPage = null;
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
                  break;

                case 'code':
                  blockWidget = CodeBlock(
                    key: ValueKey(block),
                    initialCode: (block.content as String?) ?? '',
                    onChanged: (val) {
                      setState(() {
                        block.content = val;
                      });
                    },
                  );
                  break;

                case 'chart':
  // Firestore나 로컬에서 읽어온 원본 content
  final rawContent = block.content;
  final List<Map<String, dynamic>> data = [];

  if (rawContent is List) {
    // 정상 케이스: 이미 리스트 형태로 저장된 경우
    for (final item in rawContent) {
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final colorVal = map['color'];

        // color가 int면 Color로 복원
        if (colorVal is int) {
          map['color'] = Color(colorVal);
        }

        // chartTitle 은 그대로 둠 (있으면 NotionChart 가 사용)
        data.add(map);
      }
    }
  } else {
    // 예전 데이터는 그냥 빈 데이터로 처리
    // NotionChart 가 기본 더미 데이터로 채워줌
  }

  blockWidget = GestureDetector(
    onLongPress: () => _showBlockMenu(index),
    child: NotionChart(
      key: ValueKey(block),
      initialData: data,
      onChanged: (serializedData) {
  debugPrint('Chart serialized: $serializedData');

  setState(() {
    block.content = serializedData;
    widget.page.lastEdited = DateTime.now();
  });
},
    ),
  );
  break;

                case 'table':
                  final Map<String, dynamic> tableData =
                      (block.content as Map?)?.cast<String, dynamic>() ??
                      {'rows': 3, 'cols': 3, 'cells': <String, String>{}};

                  blockWidget = GestureDetector(
                    onLongPress: () => _showBlockMenu(index),
                    child: NotionTable(
                      key: ValueKey(block),
                      data: tableData,
                      onChanged: (newData) {
                        setState(() {
                          block.content = newData;
                        });
                      },
                    ),
                  );
                  break;

                case 'image':
                  blockWidget = ImageBlock(
                    imageFile: File(block.content as String),
                  );
                  break;
                                case 'page_link':
                  // content: { linkedPageId: ..., title: ... } 형태라고 가정
                  String? linkedId;
                  String fallbackTitle = '링크된 페이지';

                  if (block.content is Map) {
                    final map =
                        Map<String, dynamic>.from(block.content as Map);
                    linkedId = map['linkedPageId'] as String?;
                    if (map['title'] is String &&
                        (map['title'] as String).isNotEmpty) {
                      fallbackTitle = map['title'] as String;
                    }
                  } else if (block.content is String) {
                    // 예전 데이터 호환: content 에 제목만 있는 경우
                    fallbackTitle = block.content as String;
                  }

                  final targetId = block.linkedPageId ??
                      block.targetPageId ??
                      linkedId;

                  String pageTitleToShow = fallbackTitle;

                  if (targetId != null && targetId.isNotEmpty) {
                    final all = _getAllPages();
                    final found = all
                        .where((p) => p.id == targetId)
                        .toList();
                    if (found.isNotEmpty) {
                      pageTitleToShow = found.first.title;
                    }
                  }

                  blockWidget = PageLinkBlock(
                    pageTitle: pageTitleToShow,
                    onTap: () {
                      if (targetId == null || targetId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('대상 페이지를 찾을 수 없습니다.'),
                          ),
                        );
                        return;
                      }

                      final allPages = _getAllPages();
                      PageData? targetPage;
                      try {
                        targetPage = allPages.firstWhere(
                          (p) => p.id == targetId,
                        );
                      } catch (_) {
                        targetPage = null;
                      }

                      if (targetPage == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('대상 페이지를 찾을 수 없습니다.'),
                          ),
                        );
                        return;
                      }

                      _openPage(targetPage);
                    },
                  );
                  break;


                default:
                  blockWidget = const SizedBox.shrink();
              }
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  // ✅ 롱프레스만 처리 (탭은 자식 위젯이 받게 됨)
                  onLongPress: () => _showBlockMenu(index),
                  // ✅ 탭을 부모가 먹지 않도록
                  onTap: null,
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2.0),
                    child: blockWidget,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      bottomSheet: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isKeyboardVisible)
            KeyboardAccessoryBar(
              onPlusPressed: _showBlockSelector,
              onImagePressed: _showImagePickerModal,
              onUndoPressed: _undo,
              onDeletePressed: _deleteCurrentLine,
              onColorPressed: _showColorPicker,
              canUndo: canUndo,
            )
          else
            NotionBottomBar(
              onHome: () => Navigator.pop(context),
              onSearch: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => SearchScreen(
                      allPages: widget.allPages ?? [],
                      onNewPage: (_) => _createSubPageAndOpen(),
                    ),
                  ),
                );
              },
              onNewPage: _createSubPageAndOpen,
            ),
        ],
      ),
    );
  }
}

// 나머지 Dialog 클래스들
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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '페이지 이동',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

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
                              fontWeight: isCurrentPage
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
              Text(pageId, style: const TextStyle(fontSize: 12)),
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
    final bool isTeamPage = widget.page.teamSpaceId != null;

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
                    fontProvider.setFontFamily(
                      widget.page.id,
                      FontFamily.basic,
                    );
                    widget.onFontChanged();
                  },
                ),
                const SizedBox(width: 8),
                _FontButton(
                  label: '세리프',
                  isSelected: currentFont == FontFamily.serif,
                  onTap: () {
                    fontProvider.setFontFamily(
                      widget.page.id,
                      FontFamily.serif,
                    );
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

          if (!isTeamPage)
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
      title: Text(title, style: TextStyle(fontSize: 15, color: textColor)),
      onTap: onTap,
    );
  }
}
