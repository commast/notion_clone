import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class EditableTextBlock extends StatefulWidget {
  final String initialText;
  final bool isTitle;
  final FocusNode? focusNode;
  final Function(String) onChanged;
  final String? pageId;
  final Color? textColor;
  final VoidCallback? onTap;

  const EditableTextBlock({
    required this.initialText,
    required this.isTitle,
    required this.onChanged,
    this.focusNode,
    this.pageId,
    this.textColor,
    this.onTap,
    super.key,
  });

  @override
  State<EditableTextBlock> createState() => _EditableTextBlockState();
}

class _EditableTextBlockState extends State<EditableTextBlock> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = widget.pageId != null 
        ? fontProvider.getFontFamily(widget.pageId!) 
        : FontFamily.basic;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.isTitle ? 20.0 : 8.0),
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        keyboardType: TextInputType.multiline,
        maxLines: null,
        style: fontProvider.getTextStyle(
          fontFamily,
          fontSize: widget.isTitle ? 32 : 18,
          fontWeight: widget.isTitle ? FontWeight.bold : FontWeight.normal,
          color: widget.textColor ?? Colors.black,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: widget.isTitle ? '제목 없음' : '입력하세요',
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: widget.isTitle ? 32 : 18,
          ),
        ),
      ),
    );
  }
}
