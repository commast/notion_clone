import 'package:flutter/material.dart';

class DividerBlock extends StatelessWidget {
  const DividerBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Divider(thickness: 1, color: Colors.black26),
    );
  }
}
