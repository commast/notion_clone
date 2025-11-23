import 'package:flutter/material.dart';


class ColorPickerModal extends StatelessWidget {
  final Function(Color?, Color?) onColorSelected;

  const ColorPickerModal({
    required this.onColorSelected,
    super.key,
  });

  static const Map<String, Color> textColors = {
    '기본': Colors.black,
    '회색': Colors.grey,
    '갈색': Color(0xFF8B4513),
    '주황색': Colors.orange,
    '노란색': Color(0xFFFFD700),
    '초록색': Colors.green,
    '파란색': Colors.blue,
    '보라색': Colors.purple,
    '분홍색': Colors.pink,
    '빨간색': Colors.red,
  };

  static const Map<String, Color> backgroundColors = {
    '기본': Colors.transparent,
    '회색': Color(0xFFEEEEEE),
    '갈색': Color(0xFFEDDCCC),
    '주황색': Color(0xFFFFE5CC),
    '노란색': Color(0xFFFFF9CC),
    '초록색': Color(0xFFE0F7E0),
    '파란색': Color(0xFFE0F0FF),
    '보라색': Color(0xFFF0E0FF),
    '분홍색': Color(0xFFFFE0F0),
    '빨간색': Color(0xFFFFE0E0),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Text(
              '색상 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                const Text(
                  '텍스트 색상',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: textColors.entries.map((entry) {
                    return _ColorButton(
                      label: entry.key,
                      color: entry.value,
                      isBackground: false,
                      onTap: () {
                        onColorSelected(entry.value, null);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 24),
                
                const Text(
                  '배경 색상',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: backgroundColors.entries.map((entry) {
                    return _ColorButton(
                      label: entry.key,
                      color: entry.value,
                      isBackground: true,
                      onTap: () {
                        onColorSelected(null, entry.value);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _ColorButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isBackground;
  final VoidCallback onTap;

  const _ColorButton({
    required this.label,
    required this.color,
    required this.isBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isBackground ? color : Colors.white,
          border: Border.all(
            color: isBackground ? Colors.grey.shade300 : color,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isBackground 
                ? (color == Colors.transparent ? Colors.black87 : Colors.black87) 
                : color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
