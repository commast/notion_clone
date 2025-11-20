import 'package:flutter/material.dart';
import '../../screens/page_screen.dart';

class PersonalPageTile extends StatelessWidget {
  final String title;
  final VoidCallback? onMorePressed;
  final VoidCallback? onTap;

  const PersonalPageTile({
    super.key,
    required this.title,
    this.onMorePressed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.description_outlined, size: 18),
      title: Text(title, style: const TextStyle(fontSize: 14)),

      // 🔥 onTap은 단 하나만!
      onTap: onTap,

      trailing: IconButton(
        icon: const Icon(Icons.more_horiz, size: 18),
        onPressed: onMorePressed,
      ),
    );
  }
}
