import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class HeadingBlock extends StatelessWidget {
  final int level;
  final String content;
  final String pageId;
  final Function(String) onChanged;

  const HeadingBlock({
    super.key,
    required this.level,
    required this.content,
    required this.pageId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(pageId);

    double fontSize;
    FontWeight fontWeight;

    switch (level) {
      case 1:
        fontSize = 32;
        fontWeight = FontWeight.bold;
        break;
      case 2:
        fontSize = 24;
        fontWeight = FontWeight.bold;
        break;
      case 3:
        fontSize = 20;
        fontWeight = FontWeight.w600;
        break;
      default:
        fontSize = 20;
        fontWeight = FontWeight.w600;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: TextEditingController(text: content)
          ..selection = TextSelection.collapsed(offset: content.length),
        style: fontProvider.getTextStyle(fontFamily, fontSize: fontSize, fontWeight: fontWeight),
        decoration: InputDecoration(
          hintText: '제목 $level',
          border: InputBorder.none,
        ),
        maxLines: null,
        onChanged: onChanged,
      ),
    );
  }
}
