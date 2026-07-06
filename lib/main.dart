import 'package:flutter/material.dart';
import 'package:evochat/app/router.dart';

void main() {
  runApp(const EvoChatApp());
}

class EvoChatApp extends StatelessWidget {
  const EvoChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'EvoChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        appBarTheme: AppBarTheme(
        ),
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      ),
      routerConfig: router,
    );
  }
}