import 'package:flutter/material.dart';
import 'package:evochat/app/router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';


Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await Supabase.initialize(
    url: 'https://grzphmudtrjopckhmqct.supabase.co',
    publishableKey: 'sb_publishable__Aaq0oqkfgltmEPiAKwrow_G0oNI37y',
  );
  final session = Supabase.instance.client.auth.currentSession;
  final initialLocation = session != null ? '/dashboard' : '/login';

  runApp(EvoChatApp(initialLocation: initialLocation));
  FlutterNativeSplash.remove();
}

final supabase = Supabase.instance.client;

class EvoChatApp extends StatelessWidget {
  final String initialLocation;
  const EvoChatApp({super.key, required this.initialLocation});

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
      routerConfig: buildRouter(initialLocation),
    );
  }
}