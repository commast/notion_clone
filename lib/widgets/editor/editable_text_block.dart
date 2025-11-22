import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class EditableTextBlock extends StatefulWidget {
  final String initialText;
  final bool isTitle;
  final FocusNode? focusNode;
  final Function(String) onChanged;
  final String? pageId;

  const EditableTextBlock({
    required this.initialText,
    required this.isTitle,
    required this.onChanged,
    this.focusNode,
    this.pageId,
    super.key,
  });

  @override
  State<EditableTextBlock> createState() => _EditableTextBlockState();
}

class _EditableTextBlockState extends State<EditableTextBlock> {
  late FocusNode _focusNode;
  late TextEditingController _controller;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() {
        _hasFocus = _focusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 글꼴 Provider 가져오기
    final fontProvider = Provider.of<FontProvider>(context);
    final currentFont = widget.pageId != null 
        ? fontProvider.getFontFamily(widget.pageId!)
        : FontFamily.basic;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.isTitle ? 20.0 : 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isTitle)
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 10),
            ),
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: _controller,
              onChanged: widget.onChanged,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: _hasFocus
                    ? ''
                    : (widget.isTitle ? '제목을 입력하세요' : '/ 를 입력하여 블록을 추가하세요'),
                hintStyle: TextStyle(
                  color: Colors.grey.withOpacity(0.6),
                  fontWeight: FontWeight.normal,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              // 글꼴 적용
              style: fontProvider.getTextStyle(
                currentFont,
                fontSize: widget.isTitle ? 32 : 18,
                fontWeight: widget.isTitle ? FontWeight.bold : FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
