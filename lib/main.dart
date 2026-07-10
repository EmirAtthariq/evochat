import 'package:flutter/material.dart';
import 'package:evochat/app/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://grzphmudtrjopckhmqct.supabase.co',
    publishableKey: 'sb_publishable__Aaq0oqkfgltmEPiAKwrow_G0oNI37y',
  );
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
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w600,
          ),
        ),
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F7),
      ),
      routerConfig: router,
    );
  }
}