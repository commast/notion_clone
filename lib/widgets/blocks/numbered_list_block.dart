import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class NumberedListBlock extends StatelessWidget {
  final int number;
  final String content;
  final String pageId;
  final Function(String) onChanged;
  final Function()? onEnterPressed;

  const NumberedListBlock({
    super.key,
    required this.number,
    required this.content,
    required this.pageId,
    required this.onChanged,
    this.onEnterPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fontProvider = Provider.of<FontProvider>(context);
    final fontFamily = fontProvider.getFontFamily(pageId);

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
                '$number.',
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: content)
                ..selection = TextSelection.collapsed(offset: content.length),
              style: fontProvider.getTextStyle(fontFamily, fontSize: 16),
              decoration: const InputDecoration(
                hintText: '목록 항목',
                border: InputBorder.none,
              ),
              maxLines: null,
              textInputAction: TextInputAction.newline,
              onChanged: onChanged,
              onSubmitted: (_) {
                if (onEnterPressed != null) {
                  onEnterPressed!();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
