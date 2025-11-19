import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 클립보드용
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart'; // 테마
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/cpp.dart';
// 필요한 언어를 여기서 추가 import 하세요.

class CodeBlock extends StatefulWidget {
  const CodeBlock({super.key});

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  late CodeController _codeController;
  String _selectedLanguage = 'Dart';

  // 지원할 언어 목록 매핑
  final Map<String, dynamic> _languageMap = {
    'Dart': dart,
    'Python': python,
    'JavaScript': javascript,
    'Java': java,
    'C++': cpp,
  };

  @override
  void initState() {
    super.initState();
    // 초기 코드와 언어 설정
    _codeController = CodeController(
      text: "void main() {\n  print('Hello Notion!');\n}",
      language: dart,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // 언어 변경 시 호출
  void _changeLanguage(String? langKey) {
    if (langKey == null) return;
    setState(() {
      _selectedLanguage = langKey;
      _codeController.language = _languageMap[langKey];
    });
  }

  // 클립보드 복사
  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _codeController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('코드가 복사되었습니다!'), duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF23241f), // Monokai 배경색과 맞춤
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // 1. 상단 헤더 (언어 선택 및 복사 버튼)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: const BoxDecoration(
              color: Colors.white10, // 헤더는 살짝 밝게
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 언어 선택 드롭다운
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF2e2e2e),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                    items: _languageMap.keys.map((String key) {
                      return DropdownMenuItem<String>(
                        value: key,
                        child: Text(key),
                      );
                    }).toList(),
                    onChanged: _changeLanguage,
                  ),
                ),
                // 복사 버튼
                InkWell(
                  onTap: _copyToClipboard,
                  child: const Row(
                    children: [
                      Icon(Icons.copy, color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text("복사", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. 코드 에디터 영역
          CodeTheme(
            data: CodeThemeData(styles: monokaiSublimeTheme),
            child: CodeField(
              controller: _codeController,
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.5,
              ),
              gutterStyle: const GutterStyle(
                textStyle: TextStyle(color: Colors.white30, fontSize: 12),
                showLineNumbers: true,
                margin: 5,
              ),
              background: const Color(0xFF23241f), // 배경색 명시
            ),
          ),
        ],
      ),
    );
  }
}