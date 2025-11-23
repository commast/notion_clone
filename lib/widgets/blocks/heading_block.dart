import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class HeadingBlock extends StatefulWidget {
  final int level;
  final String content;
  final String pageId;
  final Function(String) onChanged;
  final Color? textColor;
  final VoidCallback? onTap;

  const HeadingBlock({
    required this.level,
    required this.content,
    required this.pageId,
    required this.onChanged,
    this.textColor,
    this.onTap,
    super.key,
  });

  @override
  State<HeadingBlock> createState() => _HeadingBlockState();
}

class _HeadingBlockState extends State<HeadingBlock> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _fontSize {
    switch (widget.level) {
      case 1:
        return 28;
      case 2:
        return 24;
      case 3:
        return 20;
      default:
        return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(widget.pageId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
        style: fontProvider.getTextStyle(
          fontFamily,
          fontSize: _fontSize,
          fontWeight: FontWeight.bold,
          color: widget.textColor ?? Colors.black,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '제목 ${widget.level}',
        ),
        maxLines: null,
      ),
    );
  }
}
