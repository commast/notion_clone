import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';


class BulletedListBlock extends StatefulWidget {
  final String content;
  final String pageId;
  final Function(String) onChanged;
  final Function()? onEnterPressed;
  final Function()? onBackspacePressed;

  const BulletedListBlock({
    super.key,
    required this.content,
    required this.pageId,
    required this.onChanged,
    this.onEnterPressed,
    this.onBackspacePressed,
  });

  @override
  State<BulletedListBlock> createState() => _BulletedListBlockState();
}

class _BulletedListBlockState extends State<BulletedListBlock> {
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
            padding: const EdgeInsets.only(top: 12.0, right: 8.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
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
