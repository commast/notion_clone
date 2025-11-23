import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class QuoteBlock extends StatelessWidget {
  final String content;
  final String pageId;
  final Function(String) onChanged;

  const QuoteBlock({
    super.key,
    required this.content,
    required this.pageId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(pageId);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0, right: 8.0),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey, width: 4)),
      ),
      child: TextField(
        controller: TextEditingController(text: content)
          ..selection = TextSelection.collapsed(offset: content.length),
        style: fontProvider.getTextStyle(fontFamily, fontSize: 16).copyWith(
          fontStyle: FontStyle.italic,
          color: Colors.grey.shade700,
        ),
        decoration: const InputDecoration(
          hintText: '인용문',
          border: InputBorder.none,
        ),
        maxLines: null,
        onChanged: onChanged,
      ),
    );
  }
}
