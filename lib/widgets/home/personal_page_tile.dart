import 'package:flutter/material.dart';

class PersonalPageTile extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final VoidCallback? onAddSubPage;
  final VoidCallback? onToggleExpand;
  final VoidCallback? onMove; // 추가
  final bool isFavorite;
  final bool isExpanded;
  final bool hasSubPages;
  final int level;

  const PersonalPageTile({
    super.key,
    required this.title,
    this.onTap,
    this.onFavorite,
    this.onDuplicate,
    this.onDelete,
    this.onAddSubPage,
    this.onToggleExpand,
    this.onMove, // 추가
    this.isFavorite = false,
    this.isExpanded = false,
    this.hasSubPages = false,
    this.level = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 16.0 + (level * 20.0),
        right: 16.0,
        top: 4.0,
        bottom: 4.0,
      ),
      leading: hasSubPages
          ? IconButton(
              icon: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_right,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onToggleExpand,
            )
          : Icon(
              isFavorite ? Icons.star : Icons.description_outlined,
              size: 18,
              color: isFavorite ? Colors.amber : null,
            ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      
      onTap: onTap,
      
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onAddSubPage,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, size: 18),
            offset: const Offset(0, 40),
            padding: EdgeInsets.zero,
            onSelected: (value) {
              switch (value) {
                case 'favorite':
                  onFavorite?.call();
                  break;
                case 'move': // 추가
                  onMove?.call();
                  break;
                case 'duplicate':
                  onDuplicate?.call();
                  break;
                case 'delete':
                  onDelete?.call();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'favorite',
                child: Row(
                  children: [
                    Icon(
                      isFavorite ? Icons.star_border : Icons.star,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 12),
                    Text(isFavorite ? '즐겨찾기 해제' : '즐겨찾기 추가'),
                  ],
                ),
              ),
              // 옮기기 메뉴 추가
              const PopupMenuItem(
                value: 'move',
                child: Row(
                  children: [
                    Icon(Icons.drive_file_move_outline, size: 18),
                    SizedBox(width: 12),
                    Text('옮기기'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, size: 18),
                    SizedBox(width: 12),
                    Text('복제'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    SizedBox(width: 12),
                    Text('삭제', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
