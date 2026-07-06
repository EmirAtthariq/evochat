import 'package:flutter/material.dart';
import 'package:evochat/widgets/app_bar.dart';

class HelpdeskScreen extends StatelessWidget {
  const HelpdeskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EvoChatAppBar(
        title: 'Helpdesk',
        // showBackButton default true, jadi otomatis muncul tombol back
      ),
      body: const Center(
        child: Text('Isi helpdesk screen di sini'),
      ),
    );
  }
}