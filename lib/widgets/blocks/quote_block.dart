import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';


class QuoteBlock extends StatefulWidget {
  final String content;
  final String pageId;
  final Function(String) onChanged;
  final Color? textColor;
  final VoidCallback? onTap;

  const QuoteBlock({
    super.key,
    required this.content,
    required this.pageId,
    required this.onChanged,
    this.textColor,
    this.onTap,
  });

  @override
  State<QuoteBlock> createState() => _QuoteBlockState();
}

class _QuoteBlockState extends State<QuoteBlock> {
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

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(widget.pageId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 8.0),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey, width: 4)),
      ),
      child: TextField(
        controller: _controller,
        style: fontProvider.getTextStyle(
          fontFamily, 
          fontSize: 16,
          color: widget.textColor ?? Colors.grey.shade700,
        ).copyWith(
          fontStyle: FontStyle.italic,
        ),
        decoration: const InputDecoration(
          hintText: '인용문',
          border: InputBorder.none,
        ),
        maxLines: null,
        onChanged: widget.onChanged,
        onTap: widget.onTap,
      ),
    );
  }
}
