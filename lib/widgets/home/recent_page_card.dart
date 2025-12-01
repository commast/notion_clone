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
      // 1. Material 위젯 사용: 배경색과 둥근 모서리, 클릭 효과를 담당
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.hardEdge, // 물결 효과가 둥근 모서리를 넘지 않게 자름
        child: InkWell(
          onTap: onTap, // 2. 클릭 이벤트 연결
          // 3. 내부 컨테이너 (여기서는 크기와 내부 패딩만 담당)
          child: Container(
            width: 150, // 카드의 고정 너비
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 아이콘
                Icon(icon, size: 24, color: Colors.black54),
                
                const Spacer(), // 남은 공간을 차지하여 텍스트를 아래로 밈
                
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
                
                // 부가 설명 (선택 사항)
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