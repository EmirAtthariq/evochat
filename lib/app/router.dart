import 'package:go_router/go_router.dart';
import 'package:evochat/screens/login_screen.dart';
import 'package:evochat/screens/dashboard_screen.dart';
import 'package:evochat/screens/chat_screen.dart';
import 'package:evochat/screens/helpdesk_screen.dart';

GoRouter buildRouter(String initialLocation){
  return GoRouter(
    initialLocation: initialLocation,
  routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: '/helpdesk',
        builder: (context, state) => const HelpdeskScreen(),
      ),
    ],
  );
}