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
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final  openHistory = extra?['openHistory'] as bool? ?? false;
          final conversationId = extra?['conversationId'] as String?;
          return ChatScreen(
            openHistoryOnStart: openHistory,
            initialConversationId: conversationId,
          );
        }
      ),
      GoRoute(
        path: '/helpdesk',
        builder: (context, state) => const HelpdeskScreen(),
      ),
    ],
  );
}