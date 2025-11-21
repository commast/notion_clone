import 'package:flutter/material.dart';

class NotionBottomBar extends StatelessWidget {
  final VoidCallback? onNewPage;
  final VoidCallback? onSearch;

  const NotionBottomBar({
    super.key,
    this.onNewPage,
    this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50.0 + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12, width: 1.0)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBarItem(Icons.home, '홈', () {}),
            _buildBarItem(Icons.search, '검색', onSearch),
            _buildBarItem(Icons.add_box_outlined, '새 페이지', onNewPage),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
