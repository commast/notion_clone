import 'package:flutter/material.dart';

class EditableTextBlock extends StatefulWidget {
  final String initialText;
  final bool isTitle;
  final FocusNode? focusNode;
  final Function(String) onChanged; // ★ 데이터 저장을 위한 콜백 추가

  const EditableTextBlock({
    required this.initialText,
    required this.isTitle,
    required this.onChanged, // ★ 필수 인자로 변경
    this.focusNode,
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.isTitle ? 20.0 : 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isTitle)
            Container(width: 20, height: 20, margin: const EdgeInsets.only(top: 10)), 
          
          Expanded(
            child: TextField(
              focusNode: _focusNode,
              controller: _controller,
              // ★ 텍스트가 변경될 때마다 부모(PageScreen)에게 알려줌
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
              style: TextStyle(
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