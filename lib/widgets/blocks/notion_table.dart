import 'package:flutter/material.dart';

class TableSizeSelectorModal extends StatefulWidget {
  final Function(int rows, int cols) onTableCreated;
  const TableSizeSelectorModal({required this.onTableCreated, super.key});

  @override
  State<TableSizeSelectorModal> createState() => _TableSizeSelectorModalState();
}

class _TableSizeSelectorModalState extends State<TableSizeSelectorModal> {
  int _rows = 3;
  int _cols = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      height: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('표 크기 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          _buildSizeSelector('행 (Rows)', _rows,
              (value) => setState(() => _rows = value)),
          const SizedBox(height: 20),
          _buildSizeSelector('열 (Columns)', _cols,
              (value) => setState(() => _cols = value)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_rows > 0 && _cols > 0) {
                  widget.onTableCreated(_rows, _cols);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('표 생성',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSelector(
      String label, int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: value > 1 ? () => onChanged(value - 1) : null,
            ),
            Container(
              width: 40,
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon:
                  const Icon(Icons.add_circle_outline, color: Colors.green),
              onPressed: value < 10 ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------- NotionTable ----------------

class NotionTable extends StatefulWidget {
  final Map<String, dynamic> data; // rows, cols, cells(Map<String,String>)
  final ValueChanged<Map<String, dynamic>> onChanged;

  const NotionTable({
    required this.data,
    required this.onChanged,
    super.key,
  });

  @override
  State<NotionTable> createState() => _NotionTableState();
}

class _NotionTableState extends State<NotionTable> {
  late int _rows;
  late int _cols;
  late List<List<TextEditingController>> _controllers;

  @override
  void initState() {
    super.initState();
    _rows = (widget.data['rows'] as num?)?.toInt() ?? 3;
    _cols = (widget.data['cols'] as num?)?.toInt() ?? 3;

    final Map<String, dynamic> cellMap =
        (widget.data['cells'] as Map?)?.cast<String, dynamic>() ?? {};
    _initializeControllers(_rows, _cols, cellMap);
  }

  void _initializeControllers(
      int rows, int cols, Map<String, dynamic> cellMap) {
    _controllers = List.generate(
      rows,
      (i) => List.generate(
        cols,
        (j) {
          final key = '${i}_${j}';
          final text = (cellMap[key]?.toString()) ??
              (i == 0 ? 'Header ${j + 1}' : '');
          return TextEditingController(text: text);
        },
      ),
    );
  }

  @override
  void dispose() {
    for (var row in _controllers) {
      for (var c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _notifyParent() {
    final Map<String, String> cells = {};
    for (int i = 0; i < _rows; i++) {
      for (int j = 0; j < _cols; j++) {
        cells['${i}_${j}'] = _controllers[i][j].text;
      }
    }

    widget.onChanged({
      'rows': _rows,
      'cols': _cols,
      'cells': cells, // Map<String,String> (중첩 배열 없음)
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: Colors.black12, width: 1.0),
        children: List.generate(_rows, (i) {
          final isHeader = i == 0;
          return TableRow(
            decoration: BoxDecoration(
              color: isHeader ? const Color(0xFFF0F0F0) : Colors.white,
            ),
            children: List.generate(_cols, (j) {
              return TableCell(
                verticalAlignment: TableCellVerticalAlignment.middle,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 100),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10.0, vertical: 8.0),
                  child: TextField(
                    controller: _controllers[i][j],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isHeader ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: null,
                    onChanged: (_) => _notifyParent(), // 저장
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }
}
