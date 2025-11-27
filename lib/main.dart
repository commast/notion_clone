import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:async';

import 'screens/home_screen.dart';
import 'screens/email_verification_screen.dart';
import 'utils/theme_provider.dart';
import 'utils/font_provider.dart';
import 'utils/app_theme.dart';
import 'repositories/page_repository.dart';
import 'services/firestore_api_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final apiService = FirestoreApiService();
  final pageRepository = PageRepository(apiService);

  runApp(
    MultiProvider(
      providers: [
        Provider<PageRepository>.value(value: pageRepository),
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
        ChangeNotifierProvider(create: (_) => DeepLinkProvider()),
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
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final deepLinkProvider = Provider.of<DeepLinkProvider>(context, listen: false);

      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          debugPrint('딥링크 수신 (앱 시작): $initialUri');
          _handleDeepLink(initialUri, deepLinkProvider);
        }
      } catch (e) {
        debugPrint('초기 딥링크 처리 실패: $e');
      }

      _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          debugPrint('딥링크 수신 (실행 중/백그라운드): $uri');
          _handleDeepLink(uri, deepLinkProvider);
        }
      }, onError: (err) {
        debugPrint('딥링크 에러: $err');
      });
    });
  }

  void _handleDeepLink(Uri uri, DeepLinkProvider provider) {
    if (uri.scheme == 'notion-clone' && uri.pathSegments.isNotEmpty) {
      if (uri.pathSegments[0] == 'page' && uri.pathSegments.length > 1) {
        final pageId = uri.pathSegments[1];
        debugPrint('페이지 ID 추출: $pageId');
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData) {
            final user = snapshot.data!;
            
            if (!user.emailVerified) {
              return EmailVerificationScreen(
                email: user.email ?? '',
              );
            }
            
            return const NotionHomeScreen();
          }

          return const NotionHomeScreen();
        },
      ),
    );
  }
}

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
