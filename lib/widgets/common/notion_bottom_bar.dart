import 'package:flutter/material.dart';

class NotionBottomBar extends StatelessWidget {
  final VoidCallback? onNewPage;

  const NotionBottomBar({super.key, this.onNewPage});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 홈 버튼 -----------------------------------------
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 26),
            onPressed: () {
              // 만약 다른 페이지에 있다면 홈으로 이동 가능
              Navigator.popUntil(context, (route) => route.isFirst);
            },
          ),

          // 검색 버튼 ---------------------------------------
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            onPressed: () {
              // 검색 화면 만들면 여기에 연결
              debugPrint("검색 버튼 눌림");
            },
          ),

          // 새 페이지 버튼 ----------------------------------
          IconButton(
            icon: const Icon(Icons.mode_edit_outline, size: 26),
            onPressed: onNewPage, // 외부에서 callback 연결
          ),
        ],
      ),
    );
  }
}
