import 'package:flutter/material.dart';

class BlocSelectorModal extends StatelessWidget {
  final Function(String) onBlockSelected;
  const BlocSelectorModal({required this.onBlockSelected, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '블록 선택',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _BlockGrid(onBlockSelected: onBlockSelected),
          ),
        ],
      ),
    );
  }
}

class _BlockGrid extends StatelessWidget {
  final Function(String) onBlockSelected;
  const _BlockGrid({required this.onBlockSelected});

  final List<Map<String, dynamic>> _blocks = const [
    {'title': '코드', 'icon': '💻'},
    {'title': '표', 'icon': '📑'},
    {'title': '막대 차트', 'icon': '📊'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('미디어', style: TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.5,
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
            ),
            itemCount: _blocks.length,
            itemBuilder: (context, index) {
              final block = _blocks[index];
              return _BlockItem(
                title: block['title'] as String,
                iconText: block['icon'] as String,
                onTap: () => onBlockSelected(block['title'] as String),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BlockItem extends StatelessWidget {
  final String title;
  final String iconText;
  final VoidCallback onTap;

  const _BlockItem({required this.title, required this.iconText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(iconText, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}