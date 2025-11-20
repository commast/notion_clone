import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const NotionCloneApp());
}

class NotionCloneApp extends StatelessWidget {
  const NotionCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notion Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
        useMaterial3: true,
      ),
      home: const NotionHomeScreen(),
    );
  }
}
