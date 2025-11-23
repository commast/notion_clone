import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';


class ToggleListBlock extends StatefulWidget {
  final String title;
  final String content;
  final String pageId;
  final Function(String) onTitleChanged;
  final Function(String) onContentChanged;
  final Function()? onEnterPressed;
  final Function()? onBackspacePressed;
  final Color? textColor;
  final VoidCallback? onTap;

  const ToggleListBlock({
    super.key,
    required this.title,
    required this.content,
    required this.pageId,
    required this.onTitleChanged,
    required this.onContentChanged,
    this.onEnterPressed,
    this.onBackspacePressed,
    this.textColor,
    this.onTap,
  });

  @override
  State<ToggleListBlock> createState() => _ToggleListBlockState();
}

class _ToggleListBlockState extends State<ToggleListBlock> {
  bool _isExpanded = false;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  late FocusNode _contentFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _contentController = TextEditingController(text: widget.content);
    _titleFocusNode = FocusNode(
      onKeyEvent: _handleKeyEvent,
    );
    _contentFocusNode = FocusNode();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (widget.onEnterPressed != null) {
          widget.onEnterPressed!();
        }
        return KeyEventResult.handled;
      }
      
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_titleController.text.isEmpty && widget.onBackspacePressed != null) {
          widget.onBackspacePressed!();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(widget.pageId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  focusNode: _titleFocusNode,
                  style: fontProvider.getTextStyle(
                    fontFamily, 
                    fontSize: 16, 
                    fontWeight: FontWeight.w500,
                    color: widget.textColor ?? Colors.black,
                  ),
                  decoration: const InputDecoration(
                    hintText: '토글 제목',
                    border: InputBorder.none,
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onChanged: widget.onTitleChanged,
                  onTap: widget.onTap,
                ),
              ),
            ],
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 8.0),
              child: TextField(
                controller: _contentController,
                focusNode: _contentFocusNode,
                style: fontProvider.getTextStyle(
                  fontFamily, 
                  fontSize: 15,
                  color: widget.textColor ?? Colors.black,
                ),
                decoration: const InputDecoration(
                  hintText: '내용 입력...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                onChanged: widget.onContentChanged,
              ),
            ),
        ],
      ),
    );
  }
}
