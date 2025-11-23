import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';


class NumberedListBlock extends StatefulWidget {
  final int number;
  final String content;
  final String pageId;
  final Function(String) onChanged;
  final Function()? onEnterPressed;
  final Function()? onBackspacePressed;

  const NumberedListBlock({
    super.key,
    required this.number,
    required this.content,
    required this.pageId,
    required this.onChanged,
    this.onEnterPressed,
    this.onBackspacePressed,
  });

  @override
  State<NumberedListBlock> createState() => _NumberedListBlockState();
}

class _NumberedListBlockState extends State<NumberedListBlock> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
    _focusNode = FocusNode(
      onKeyEvent: _handleKeyEvent,
    );
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
        if (_controller.text.isEmpty && widget.onBackspacePressed != null) {
          widget.onBackspacePressed!();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
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
            padding: const EdgeInsets.only(top: 4.0, right: 8.0),
            child: SizedBox(
              width: 28,
              child: Text(
                '${widget.number}.',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: fontProvider.getTextStyle(fontFamily, fontSize: 16),
              decoration: const InputDecoration(
                hintText: '목록 항목',
                border: InputBorder.none,
              ),
              maxLines: 1,
              textInputAction: TextInputAction.done,
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
