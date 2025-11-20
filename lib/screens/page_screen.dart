import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// 데이터 모델 import
import '../data/page_data.dart';

// 공통 위젯
import '../widgets/common/notion_bottom_bar.dart';

// 에디터 관련 위젯
import '../widgets/editor/editable_text_block.dart';
import '../widgets/editor/keyboard_accessory_bar.dart';
import '../widgets/editor/block_selector_modal.dart';

// 블록 위젯들
import '../widgets/blocks/notion_table.dart';
import '../widgets/blocks/code_block.dart';
import '../widgets/blocks/notion_chart.dart';
import '../widgets/blocks/image_block.dart';

class NotionPageScreen extends StatefulWidget {
  // ★ 1. 페이지 ID를 필수로 받습니다.
  final PageData page;
  final VoidCallback? onNewPage;
  final VoidCallback? onPageChanged;

  const NotionPageScreen({
    super.key,
    required this.page,
    this.onNewPage,
    this.onPageChanged, // ✅ 추가
  });

  @override
  State<NotionPageScreen> createState() => _NotionPageScreenState();
}

class _NotionPageScreenState extends State<NotionPageScreen> {
  // ★ 2. 현재 페이지의 데이터 리스트를 저장할 변수입니다.
  late List<BlockData> _currentBlocks;

  final FocusNode _focusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // ★ 3. `pageId`를 사용하여 해당 페이지의 데이터를 불러오거나 초기화합니다.
    _currentBlocks = getPageBlocks(widget.page.id);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 필요 시 초기 포커스 설정 로직
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  // ===========================================================================
  // 데이터 관리 및 블록 추가 로직
  // ===========================================================================

  // 이미지 추가
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          // _currentBlocks에 데이터 추가
          _currentBlocks.insert(
            1,
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

  // 블록 추가
  void _addBlock(String blockType) {
    if (blockType == '표') {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return TableSizeSelectorModal(
            onTableCreated: (rows, cols) {
              setState(() {
                _currentBlocks.insert(
                  1,
                  BlockData(
                    type: 'table',
                    content: {'rows': rows, 'cols': cols},
                  ),
                );
              });
              Navigator.pop(context);
              Navigator.pop(context);
            },
          );
        },
      );
    } else if (blockType == '코드') {
      setState(() {
        _currentBlocks.insert(1, BlockData(type: 'code', content: ''));
      });
      Navigator.pop(context);
    } else if (blockType == '막대 차트') {
      setState(() {
        _currentBlocks.insert(1, BlockData(type: 'chart', content: null));
      });
      Navigator.pop(context);
    } else {
      setState(() {
        _currentBlocks.insert(1, BlockData(type: 'text', content: ''));
      });
      Navigator.pop(context);
    }
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

  // ===========================================================================
  // UI 빌드 (데이터 -> 위젯 변환)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardVisible = keyboardHeight > 0;

    // 하단 바 높이 (50) + 시스템 하단 패딩
    final double bottomBarHeight = 50.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
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
        actions: [
          IconButton(icon: const Icon(Icons.upload_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
        ],
      ),

      // ★ ListView.builder에서 _currentBlocks를 사용합니다.
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: _currentBlocks.length + 1,
        itemBuilder: (context, index) {
          // 마지막 아이템은 여백용 SizedBox
          if (index == _currentBlocks.length) {
            return SizedBox(height: isKeyboardVisible ? 0 : bottomBarHeight);
          }

          final block = _currentBlocks[index];

          // 데이터 타입에 따라 적절한 위젯 반환
          switch (block.type) {
            case 'title':
              return EditableTextBlock(
                initialText: block.content as String,
                isTitle: true,
                focusNode: _focusNode,
                onChanged: (val) {
                  block.content = val; // 블록 내용 저장
                  widget.page.title = val; // ⭐ PageData.title 에도 저장
                  widget.page.lastEdited = DateTime.now(); // 수정시간 갱신 (선택)

                  widget.onPageChanged?.call();
                  setState(() {}); // 홈 화면 돌아갔을 때 제목 반영됨
                },
              );
            case 'text':
              return EditableTextBlock(
                key: ValueKey(block), // ★ Key 추가
                initialText: block.content as String,
                isTitle: false,
                onChanged: (val) => block.content = val,
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

      // 하단 시트: 키보드 유무에 따라 액세서리 바 또는 네비게이션 바 표시
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
              // ✅ const 제거
              onNewPage: widget.onNewPage, // ✅ 새 페이지 콜백 전달
            ),
        ],
      ),

      floatingActionButton: isKeyboardVisible
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: bottomBarHeight + 10),
              child: FloatingActionButton(
                onPressed: widget.onNewPage, // ✅ 새 페이지 콜백 실행
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
