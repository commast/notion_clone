import 'package:flutter/material.dart';
import '../../data/page_data.dart';

class MovePageDialog extends StatefulWidget {
  final List<PageData> allPages;
  final PageData currentPage;

  const MovePageDialog({
    super.key,
    required this.allPages,
    required this.currentPage,
  });

  @override
  State<MovePageDialog> createState() => _MovePageDialogState();
}

class _MovePageDialogState extends State<MovePageDialog> {
  PageData? _selectedPage;

  List<PageData> get _selectablePages =>
      widget.allPages.where((page) => page.id != widget.currentPage.id).toList();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('페이지 선택'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: _selectablePages.length,
          itemBuilder: (context, index) {
            final page = _selectablePages[index];
            final isSelected = _selectedPage?.id == page.id;

            return ListTile(
              title: Text(page.title),
              selected: isSelected,
              onTap: () => setState(() => _selectedPage = page),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed:
              _selectedPage == null ? null : () => Navigator.pop(context, _selectedPage),
          child: const Text('선택'),
        ),
      ],
    );
  }
}
