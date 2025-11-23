import 'package:flutter/material.dart';


class KeyboardAccessoryBar extends StatelessWidget {
  final VoidCallback onPlusPressed;
  final VoidCallback onImagePressed;
  final VoidCallback onUndoPressed;         // 추가
  final VoidCallback onDeletePressed;       // 추가
  final VoidCallback onColorPressed;        // 추가
  final bool canUndo;                       // 추가

  const KeyboardAccessoryBar({
    required this.onPlusPressed,
    required this.onImagePressed,
    required this.onUndoPressed,
    required this.onDeletePressed,
    required this.onColorPressed,
    this.canUndo = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: Colors.black12, width: 1.0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            onPressed: onPlusPressed,
          ),
          
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.black54),
            onPressed: onImagePressed,
          ),

          IconButton(
            icon: Icon(
              Icons.undo,
              color: canUndo ? Colors.black54 : Colors.grey.shade300,
            ),
            onPressed: canUndo ? onUndoPressed : null,
          ),

          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: onDeletePressed,
          ),

          IconButton(
            icon: const Icon(Icons.palette_outlined, color: Colors.black54),
            onPressed: onColorPressed,
          ),

          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '메모를 입력하세요',
                isDense: true,
                contentPadding: EdgeInsets.only(left: 10.0, top: 12.0),
              ),
            ),
          ),
          
          IconButton(
            icon: const Icon(Icons.keyboard_hide, color: Colors.black54),
            onPressed: () {
              FocusScope.of(context).unfocus();
            },
          ),
        ],
      ),
    );
  }
}
