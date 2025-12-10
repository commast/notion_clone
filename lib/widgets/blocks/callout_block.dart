import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/font_provider.dart';


class CalloutBlock extends StatefulWidget {
  final String content;
  final String pageId;
  final Function(String) onChanged;
  final Color? textColor;
  final VoidCallback? onTap;

  const CalloutBlock({
    super.key,
    required this.content,
    required this.pageId,
    required this.onChanged,
    this.textColor,
    this.onTap,
  });

  @override
  State<CalloutBlock> createState() => _CalloutBlockState();
}

class _CalloutBlockState extends State<CalloutBlock> {
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
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 12.0, top: 2.0),
            child: Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: fontProvider.getTextStyle(
                fontFamily, 
                fontSize: 16,
                color: widget.textColor ?? Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: '콜아웃',
                border: InputBorder.none,
              ),
              maxLines: null,
              onChanged: widget.onChanged,
              onTap: widget.onTap,
            ),
          ),
        ],
      ),
    );
  }
}
