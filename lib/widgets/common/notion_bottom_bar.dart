import 'package:flutter/material.dart';

class NotionBottomBar extends StatelessWidget {
  const NotionBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12, width: 1.0)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.search, color: Colors.black54),
          Icon(Icons.notifications_none, color: Colors.black54),
          Icon(Icons.add_circle_outline, color: Colors.black),
          Icon(Icons.timer_outlined, color: Colors.black54),
          Icon(Icons.account_circle_outlined, color: Colors.black54),
        ],
      ),
    );
  }
}