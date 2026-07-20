import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evochat/widgets/app_bar.dart';
import 'package:evochat/services/profile_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _profileService = ProfileService(baseUrl: 'http://192.168.56.1:3000');
  String? _nama;
  String _email = '';
  String? _domisili; 
  bool _profileLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _email = Supabase.instance.client.auth.currentUser?.email ?? 'Pengguna';
    _loadProfile();
  }

  Future<void> _loadProfile({int attempt = 1}) async {
    try {
      final profile = await _profileService.fetchUserProfile();
      if (!mounted) return;
      setState(() {
        _nama = profile.nama;
        _email = profile.email;
        _domisili = profile.domisili;
        _profileLoadFailed = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('Gagal memuat profil (percobaan $attempt): $e');

      if (attempt < 2) {
        // retry otomatis sekali setelah jeda singkat
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        return _loadProfile(attempt: attempt + 1);
      }

      if (!mounted) return;
      setState(() => _profileLoadFailed = true);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EvoChatAppBar(title: 'EvoChat'),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  _nama ?? 'Pengguna',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                accountEmail: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_email),
                    if (_domisili != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _domisili!,
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ],
                      )
                    ]
                  ]
                ) ,
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    (_nama ?? _email).isNotEmpty
                        ? (_nama ?? _email)[0].toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
              const Spacer(),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang,',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _nama ?? _email,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (_nama != null) ...[
                const SizedBox(height: 2),
                Text(
                  _email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
              if (_profileLoadFailed) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    setState(() => _profileLoadFailed = false);
                    _loadProfile();
                  },
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 4),
                      Text(
                        'Gagal memuat nama · Coba lagi',
                        style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),

              _DashboardMenuCard(
                icon: Icons.chat_bubble_outline,
                title: 'Chat',
                subtitle: 'Butuh bantuan? Tanyakan saja ke asisten AI kami',
                onTap: () => context.push('/chat'),
              ),
              const SizedBox(height: 16),
              _DashboardMenuCard(
                icon: Icons.support_agent,
                title: 'Helpdesk',
                subtitle: 'Butuh bantuan lebih lanjut? Hubungi tim kami',
                onTap: () => context.push('/helpdesk'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}