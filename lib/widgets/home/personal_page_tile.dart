import 'package:flutter/material.dart';
import '../../screens/page_screen.dart';

class PersonalPageTile extends StatelessWidget {
  final String title;
  const PersonalPageTile({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.lock_outline, size: 18),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.more_horiz, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const NotionPageScreen(
              // ★ 이 부분이 수정되었습니다. 고유 ID를 전달합니다.
              pageId: 'personal_page', 
            ),
          ),
        );
      },
    );
  }
}