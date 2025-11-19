import 'package:flutter/material.dart';

class KeyboardAccessoryBar extends StatelessWidget {
  final VoidCallback onPlusPressed;
  final VoidCallback onImagePressed; // ★ 추가됨

  const KeyboardAccessoryBar({
    required this.onPlusPressed,
    required this.onImagePressed, // ★ 추가됨
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
          // 1. 기존 + 버튼
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: Colors.black),
            onPressed: onPlusPressed,
          ),
          
          // 2. ★ 추가된 이미지 버튼 ★
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Colors.black54),
            onPressed: onImagePressed,
          ),

          // 3. 텍스트 필드 (기존 코드)
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
          
          // 4. 키보드 내리기 버튼 (기존 코드)
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