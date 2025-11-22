import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum FontFamily {
  basic,   // 산세리프체 (Roboto)
  serif,   // 세리프체 (Noto Serif)
  mono,    // 모노스페이스 (Roboto Mono)
}

class FontProvider with ChangeNotifier {
  // 페이지별 글꼴을 저장하는 Map
  final Map<String, FontFamily> _pageFonts = {};
  
  FontFamily getFontFamily(String pageId) {
    return _pageFonts[pageId] ?? FontFamily.basic;
  }
  
  void setFontFamily(String pageId, FontFamily font) {
    _pageFonts[pageId] = font;
    notifyListeners();
  }
  
  String getFontFamilyName(FontFamily font) {
    switch (font) {
      case FontFamily.basic:
        return 'Basic';
      case FontFamily.serif:
        return 'Serif';
      case FontFamily.mono:
        return 'Monospace';
    }
  }
  
  // 실제 글꼴 스타일을 반환 - Google Fonts 사용
  TextStyle getTextStyle(FontFamily font, {double? fontSize, FontWeight? fontWeight, Color? color}) {
    switch (font) {
      case FontFamily.basic:
        // 산세리프 - Roboto (깔끔한 현대적 느낌)
        return GoogleFonts.roboto(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: -0.3,
        );
      case FontFamily.serif:
        // 세리프체 - Noto Serif (전통적인 명조체 느낌)
        return GoogleFonts.notoSerif(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: 0.2,
        );
      case FontFamily.mono:
        // 모노스페이스 - Roboto Mono (코딩용 고정폭)
        return GoogleFonts.robotoMono(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: 0.0,
        );
    }
  }
}
