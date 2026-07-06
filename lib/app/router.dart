import 'package:go_router/go_router.dart';
import 'package:evochat/screens/login_screen.dart';
import 'package:evochat/screens/chat_screen.dart';
import 'package:evochat/screens/helpdesk_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const ChatScreen(),
    ),
    GoRoute(
      path: '/helpdesk',
      builder: (context, state) => const HelpdeskScreen(),
    ),
  ],
);