import 'dart:io';
import 'package:flutter/material.dart';

class ImageBlock extends StatelessWidget {
  final File imageFile;

  const ImageBlock({required this.imageFile, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      width: double.infinity,
      // 이미지가 너무 크면 적당히 제한하거나 비율 유지
      constraints: const BoxConstraints(maxHeight: 300), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        // 이미지 외곽선 (선택 사항)
        border: Border.all(color: Colors.black12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.file(
          imageFile,
          fit: BoxFit.cover, // 영역에 꽉 차게
        ),
      ),
    );
  }
}