import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class TodoListBlock extends StatefulWidget {
  final bool isChecked;
  final String content;
  final String pageId;
  final Function(bool) onCheckedChanged;
  final Function(String) onContentChanged;
  final Function()? onEnterPressed;

  const TodoListBlock({
    super.key,
    required this.isChecked,
    required this.content,
    required this.pageId,
    required this.onCheckedChanged,
    required this.onContentChanged,
    this.onEnterPressed,
  });

  @override
  State<TodoListBlock> createState() => _TodoListBlockState();
}

class _TodoListBlockState extends State<TodoListBlock> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _focusNode = FocusNode();
    
    // 자동 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.content.isEmpty) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(widget.pageId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Checkbox(
              value: widget.isChecked,
              onChanged: (value) {
                widget.onCheckedChanged(value ?? false);
              },
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            child: RawKeyboardListener(
              focusNode: FocusNode(),
              onKey: (RawKeyEvent event) {
                if (event is RawKeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    if (widget.onEnterPressed != null) {
                      widget.onEnterPressed!();
                    }
                  }
                }
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: fontProvider.getTextStyle(fontFamily, fontSize: 16).copyWith(
                  decoration: widget.isChecked ? TextDecoration.lineThrough : null,
                  color: widget.isChecked ? Colors.grey : Colors.black,
                ),
                decoration: const InputDecoration(
                  hintText: '할 일',
                  border: InputBorder.none,
                ),
                maxLines: null,
                onChanged: widget.onContentChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
