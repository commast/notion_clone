import 'package:flutter/material.dart';

class NotionChart extends StatefulWidget {
  final List<Map<String, dynamic>> initialData;
  final ValueChanged<List<Map<String, dynamic>>>? onChanged;

  const NotionChart({super.key, this.initialData = const [], this.onChanged});

  @override
  State<NotionChart> createState() => _NotionChartState();
}

class _NotionChartState extends State<NotionChart> {
  late List<Map<String, dynamic>> _data;

  bool _isEditingTitle = false;
  late TextEditingController _titleController;

  /// ✅ 차트 제목: 데이터에 chartTitle 이 있으면 그걸 쓰고, 없으면 기본 제목
  String get _chartTitle {
    if (_data.isNotEmpty &&
        _data[0]['chartTitle'] is String &&
        (_data[0]['chartTitle'] as String).isNotEmpty) {
      return _data[0]['chartTitle'] as String;
    }
    return '분기별 성과 (막대 차트)';
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialData.isNotEmpty) {
      
      _data = widget.initialData.map((e) {
        final map = Map<String, dynamic>.from(e);
        
        
        if (map['color'] is int) {
          map['color'] = Color(map['color']);
        }
        return map;
      }).toList();
    } else {
      // 기본 데이터
      _data = [
        {
          'label': '1분기',
          'value': 80.0,
          'color': const Color(0xFF676EFF),
          'chartTitle': '분기별 성과 (막대 차트)',
        },
        {
          'label': '2분기',
          'value': 60.0,
          'color': const Color(0xFFF06543),
          'chartTitle': '분기별 성과 (막대 차트)',
        },
        {
          'label': '3분기',
          'value': 95.0,
          'color': const Color(0xFF43A047),
          'chartTitle': '분기별 성과 (막대 차트)',
        },
        {
          'label': '4분기',
          'value': 40.0,
          'color': const Color(0xFFFFCC00),
          'chartTitle': '분기별 성과 (막대 차트)',
        },
      ];
    }
    
    
    _titleController = TextEditingController(text: _chartTitle);
  }

  void _updateChartData(List<Map<String, dynamic>> newData) {
    setState(() {
      _data = newData;
    });

    if (widget.onChanged != null) {
      // Color -> int 직렬화 + chartTitle 도 함께 저장
      final serialized = newData
          .map(
            (item) => {
              'label': item['label'],
              'value': item['value'],
              'color': (item['color'] as Color).value,
              if (item['chartTitle'] != null) 'chartTitle': item['chartTitle'],
            },
          )
          .toList();

      widget.onChanged!(serialized);
    }
  }

  void _finishTitleEdit() {
    final newTitle = _titleController.text.trim();

    setState(() {
      _isEditingTitle = false;
    });

    if (newTitle.isEmpty) return;

    // 모든 데이터 아이템에 chartTitle 반영
    final updated = _data.map<Map<String, dynamic>>((item) {
      final copy = Map<String, dynamic>.from(item);
      copy['chartTitle'] = newTitle;
      return copy;
    }).toList();

    _updateChartData(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_data.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16.0),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black12, width: 1.0),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          children: [
            const Text(
              '차트 데이터 없음',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => ChartEditModal(
                    initialData: _data,
                    onDataUpdated: _updateChartData,
                  ),
                );
              },
              child: const Text('데이터 추가', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    }

    final double dataMaxValue = _data
        .map((e) => e['value'] as double)
        .reduce((a, b) => a > b ? a : b);
    final double chartMaxValue = (dataMaxValue > 100) ? dataMaxValue : 100.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12, width: 1.0),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ 제목 클릭 → 그 자리에서 TextField 로 편집
_isEditingTitle
    ? TextField(
        controller: _titleController,
        autofocus: true,
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
        ),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        // ✅ 타이핑할 때마다 _data + onChanged 갱신
        onChanged: (val) {
          final newTitle = val.trim();
          if (newTitle.isEmpty) return;

          final updated = _data.map<Map<String, dynamic>>((item) {
            final copy = Map<String, dynamic>.from(item);
            copy['chartTitle'] = newTitle;
            return copy;
          }).toList();

          _updateChartData(updated); // 여기서 widget.onChanged 호출됨
        },
        onSubmitted: (_) => _finishTitleEdit(),
        onEditingComplete: _finishTitleEdit,
      )
    : GestureDetector(
        onTap: () {
          setState(() {
            _isEditingTitle = true;
            _titleController.text = _chartTitle;
          });
        },
        child: Text(
          _chartTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

          const SizedBox(height: 15),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _YAxisLabels(chartMaxValue: chartMaxValue),
                const SizedBox(width: 8),
                Expanded(
                  child: _GraphArea(data: _data, chartMaxValue: chartMaxValue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(color: Colors.black12, height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '데이터 소스: Notion Table',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              TextButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ChartEditModal(
                      initialData: _data,
                      onDataUpdated: _updateChartData,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 20),
                ),
                child: const Text(
                  '편집',
                  style: TextStyle(color: Colors.blue, fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────── Y 축 레이블 ─────────────────

class _YAxisLabels extends StatelessWidget {
  final double chartMaxValue;
  const _YAxisLabels({required this.chartMaxValue});
  @override
  Widget build(BuildContext context) {
    final List<double> values = [
      chartMaxValue,
      chartMaxValue * 0.75,
      chartMaxValue * 0.5,
      chartMaxValue * 0.25,
      0,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: values
          .map(
            (value) => Container(
              alignment: Alignment.centerRight,
              height: 40.0,
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ───────────────── 그래프 영역 ─────────────────

class _GraphArea extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final double chartMaxValue;
  final double chartHeight = 160.0;
  final double xAxisLabelHeight = 20.0;
  const _GraphArea({required this.data, required this.chartMaxValue});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: chartHeight,
          child: Stack(
            children: [
              ...List.generate(4, (index) {
                final double position = index * (chartHeight / 4);
                return Positioned(
                  top: position,
                  left: 0,
                  right: 0,
                  child: Container(height: 1.0, color: Colors.black12),
                );
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.map((item) {
                    return _BarItem(
                      label: item['label'] as String,
                      value: item['value'] as double,
                      color: item['color'] as Color,
                      chartMaxValue: chartMaxValue,
                      chartHeight: chartHeight,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: xAxisLabelHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: data
                .map(
                  (item) => Text(
                    item['label'] as String,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ───────────────── 막대 아이템 ─────────────────

class _BarItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final double chartMaxValue;
  final double chartHeight;
  const _BarItem({
    required this.label,
    required this.value,
    required this.color,
    required this.chartMaxValue,
    required this.chartHeight,
  });
  @override
  Widget build(BuildContext context) {
    const double valueTextHeight = 16.0;
    final double maxBarHeight = chartHeight - valueTextHeight;
    final double relativeHeight = (value / chartMaxValue) * maxBarHeight;
    final double barHeight = relativeHeight.clamp(0.0, maxBarHeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: valueTextHeight,
          child: Text(
            value.toStringAsFixed(value < 1 ? 2 : 0),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          height: barHeight,
          width: 30,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
      ],
    );
  }
}

// ───────────────── 편집 모달 ─────────────────

class ChartEditModal extends StatefulWidget {
  final List<Map<String, dynamic>> initialData;
  final Function(List<Map<String, dynamic>>) onDataUpdated;
  const ChartEditModal({
    required this.initialData,
    required this.onDataUpdated,
    super.key,
  });
  @override
  State<ChartEditModal> createState() => _ChartEditModalState();
}

class _ChartEditModalState extends State<ChartEditModal> {
  late List<Map<String, dynamic>> _editingData;
  final List<TextEditingController> _labelControllers = [];
  final List<TextEditingController> _valueControllers = [];
  final List<Color> notionColors = const [
    Color(0xFF676EFF),
    Color(0xFFF06543),
    Color(0xFF43A047),
    Color(0xFFFFCC00),
    Color(0xFF6C6C6C),
  ];

  @override
  void initState() {
    super.initState();
    _editingData = widget.initialData
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    _initializeControllers();
  }

  void _initializeControllers() {
    _labelControllers.clear();
    _valueControllers.clear();
    for (var item in _editingData) {
      _labelControllers.add(
        TextEditingController(text: item['label'] as String),
      );
      _valueControllers.add(
        TextEditingController(text: item['value'].toString()),
      );
    }
  }

  void _saveData() {
    for (int i = 0; i < _editingData.length; i++) {
      _editingData[i]['label'] = _labelControllers[i].text;
      _editingData[i]['value'] =
          double.tryParse(_valueControllers[i].text) ?? 0.0;
    }
    _editingData.removeWhere((item) => (item['label'] as String).isEmpty);
    widget.onDataUpdated(_editingData);
    Navigator.pop(context);
  }

  void _addItem() {
    setState(() {
      final newColorIndex = _editingData.length % notionColors.length;
      _editingData.add({
        'label': 'New Item',
        'value': 50.0,
        'color': notionColors[newColorIndex],
      });
      _initializeControllers();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _editingData.removeAt(index);
      _initializeControllers();
    });
  }

  void _changeColor(int index, Color color) {
    setState(() {
      _editingData[index]['color'] = color;
    });
  }

  @override
  void dispose() {
    for (var c in _labelControllers) c.dispose();
    for (var c in _valueControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      height: screenHeight * 0.9,
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '막대 차트 데이터 편집',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: ListView.builder(
              itemCount: _editingData.length,
              itemBuilder: (context, index) {
                return _ChartDataItemRow(
                  index: index,
                  data: _editingData[index],
                  labelController: _labelControllers[index],
                  valueController: _valueControllers[index],
                  onRemove: () => _removeItem(index),
                  onColorChange: (color) => _changeColor(index, color),
                  notionColors: notionColors,
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, color: Colors.blue),
            label: const Text(
              '항목 추가',
              style: TextStyle(color: Colors.blue, fontSize: 16),
            ),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '저장',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartDataItemRow extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;
  final TextEditingController labelController;
  final TextEditingController valueController;
  final VoidCallback onRemove;
  final Function(Color) onColorChange;
  final List<Color> notionColors;

  const _ChartDataItemRow({
    required this.index,
    required this.data,
    required this.labelController,
    required this.valueController,
    required this.onRemove,
    required this.onColorChange,
    required this.notionColors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  0,
                  MediaQuery.of(context).size.height * 0.5,
                  MediaQuery.of(context).size.width,
                  0,
                ),
                items: notionColors.map((color) {
                  return PopupMenuItem<Color>(
                    value: color,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          color.value == (data['color'] as Color).value
                              ? '선택됨'
                              : '선택',
                          style: TextStyle(
                            color: color.value == (data['color'] as Color).value
                                ? Colors.blue
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ).then((Color? selectedColor) {
                if (selectedColor != null) {
                  onColorChange(selectedColor);
                }
              });
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: data['color'] as Color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: labelController,
              decoration: const InputDecoration(
                hintText: '레이블',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: TextField(
              controller: valueController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '값',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.black54),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
