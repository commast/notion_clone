import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// 블록 삭제 기믹
class BlockActionWrapper extends StatelessWidget {
  final Widget child;           // 감쌀 블록 위젯
  final VoidCallback onDuplicate; // 복제 버튼 눌렀을 때 실행할 함수
  final VoidCallback onDelete;    // 삭제 버튼 눌렀을 때 실행할 함수

  const BlockActionWrapper({
    super.key,
    required this.child,
    required this.onDuplicate,
    required this.onDelete,
  });

  // 하단 메뉴 띄우기
  void _showBlockOptionModal(BuildContext context) {
    // 햅틱 진동 (UX 향상)
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              // 핸들 바
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              
              // 1. 복제
              ListTile(
                leading: const Icon(Icons.content_copy, color: Colors.black87),
                title: const Text('복제', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context); // 메뉴 닫기
                  onDuplicate(); // 메인에서 넘겨준 복제 함수 실행
                },
              ),
              
              const Divider(thickness: 1, height: 1),

              // 2. 삭제
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('삭제', style: TextStyle(color: Colors.red, fontSize: 16)),
                onTap: () {
                  Navigator.pop(context); // 메뉴 닫기
                  onDelete(); // 메인에서 넘겨준 삭제 함수 실행
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        // 키보드 내리기
        FocusScope.of(context).unfocus();
        _showBlockOptionModal(context);
      },
      behavior: HitTestBehavior.translucent, // 빈 공간 터치도 인식
      child: child,
    );
  }
}