import 'package:flutter/material.dart';

class RecentPageCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const RecentPageCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // ListView에서 간격을 주기 위한 바깥 패딩
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      // 1. Material 위젯 사용
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: onTap,

          child: Container(
            width: 150, // 카드의 고정 너비
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 아이콘
                Icon(icon, size: 24, color: Colors.black54),
                
                const Spacer(),
                
                // 제목
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15, 
                    fontWeight: FontWeight.bold
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 4),
                
                const Text(
                  '마지막 편집: 오늘',
                  style: TextStyle(
                    fontSize: 11, 
                    color: Colors.black45
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}