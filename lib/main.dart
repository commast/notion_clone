import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'utils/theme_provider.dart';
import 'utils/font_provider.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => DeepLinkProvider()), // ✅ 딥링크 Provider 추가
      ],
      child: const NotionCloneApp(),
    ),
  );
}

class NotionCloneApp extends StatefulWidget {
  const NotionCloneApp({super.key});

  @override
  State<NotionCloneApp> createState() => _NotionCloneAppState();
}

class _NotionCloneAppState extends State<NotionCloneApp> {
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final deepLinkProvider = Provider.of<DeepLinkProvider>(context, listen: false);

    // ✅ 앱이 실행 중일 때 딥링크 처리
    _linkSubscription = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        debugPrint('🔗 딥링크 수신 (실행 중): $uri');
        _handleDeepLink(uri, deepLinkProvider);
      }
    }, onError: (err) {
      debugPrint('❌ 딥링크 에러: $err');
    });

    // ✅ 앱이 종료된 상태에서 딥링크로 실행될 때
    try {
      final initialUri = await getInitialUri();
      if (initialUri != null) {
        debugPrint('🔗 딥링크 수신 (앱 시작): $initialUri');
        _handleDeepLink(initialUri, deepLinkProvider);
      }
    } catch (e) {
      debugPrint('❌ 초기 딥링크 처리 실패: $e');
    }
  }

  void _handleDeepLink(Uri uri, DeepLinkProvider provider) {
    // notion-clone://page/1763807132566 형식 처리
    if (uri.scheme == 'notion-clone' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments[0] == 'page' && uri.pathSegments.length > 1) {
        final pageId = uri.pathSegments[1];
        debugPrint('✅ 페이지 ID 추출: $pageId');
        
        // Provider에 페이지 ID 저장
        provider.setPageIdToOpen(pageId);
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Notion Clone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const NotionHomeScreen(),
    );
  }
}

// ✅ 딥링크 상태 관리를 위한 Provider
class DeepLinkProvider with ChangeNotifier {
  String? _pageIdToOpen;

  String? get pageIdToOpen => _pageIdToOpen;

  void setPageIdToOpen(String? pageId) {
    _pageIdToOpen = pageId;
    notifyListeners();
  }

  void clearPageIdToOpen() {
    _pageIdToOpen = null;
    notifyListeners();
  }
}
