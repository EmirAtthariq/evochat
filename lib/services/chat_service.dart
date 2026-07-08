import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiMessage {
  final String role; // 'user' atau 'assistant'
  final String content;

  ApiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ChatService {
  final String baseUrl;
  ChatService({required this.baseUrl});

  /// Kirim history pesan ke /api/chat dan consume streaming response.
  /// onToken dipanggil tiap potongan teks baru datang.
  /// Return conversationId (baru atau yang sama, buat disimpan di state).
  Future<String> sendMessage({
    required List<ApiMessage> messages,
    String? conversationId,
    required void Function(String token) onFirstToken,
    required void Function(String token) onToken,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async {
    // ambil token dari session Supabase yang lagi aktif
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      onError('Sesi login tidak ditemukan, silakan login ulang.');
      return conversationId ?? '';
    }

    final uri = Uri.parse('$baseUrl/api/chat');
    final request = http.Request('POST', uri);
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${session.accessToken}';
    request.body = jsonEncode({
      'messages': messages.map((m) => m.toJson()).toList(),
      'conversationId': conversationId,
    });

    try {
      final streamedResponse = await http.Client().send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        onError('Server error (${streamedResponse.statusCode}): $body');
        return conversationId ?? '';
      }

      final newConversationId =
          streamedResponse.headers['x-conversation-id'] ?? conversationId ?? '';

      bool isFirst = true;
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        if (chunk.isEmpty) continue;
        if (isFirst) {
          isFirst = false;
          onFirstToken(chunk);
        } else {
          onToken(chunk);
        }
      }

      onDone();
      return newConversationId;
    } catch (e) {
      onError('Gagal konek ke server: $e');
      return conversationId ?? '';
    }
  }
}