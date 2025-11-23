import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';

class CalloutBlock extends StatelessWidget {
  final String content;
  final String pageId;
  final Function(String) onChanged;

  const CalloutBlock({
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
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: content)
                ..selection = TextSelection.collapsed(offset: content.length),
              style: fontProvider.getTextStyle(fontFamily, fontSize: 15),
              decoration: const InputDecoration(
                hintText: '콜아웃 내용',
                border: InputBorder.none,
              ),
              maxLines: null,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
