import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiMessage {
  final String role; // 'user' atau 'assistant'
  final String content;

  ApiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class ConversationSummary {
  final String id;
  final String title;
  final DateTime createdAt;

  ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'],
      title: json['title'] ?? 'Percakapan',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ChatService {
  final String baseUrl;
  ChatService({required this.baseUrl});
  //Delete conversation by ID
  Future<void> deleteConversation(String conversationId) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Sesi login tidak ditemukan, silakan login ulang.');
    }

    final res = await http.delete(
      Uri.parse('$baseUrl/api/conversations/$conversationId'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (res.statusCode != 200) {
      throw Exception('Gagal menghapus percakapan');
    }
  }
  Future<List<ConversationSummary>> fetchConversations() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Sesi login tidak ditemukan, silakan login ulang.');
    }

    final res = await http.get(
      Uri.parse('$baseUrl/api/conversations'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat riwayat percakapan');
    }

    final data = jsonDecode(res.body) as List;
    return data.map((c) => ConversationSummary.fromJson(c)).toList();
  }

  Future<List<ApiMessage>> fetchConversationMessages(String conversationId) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Sesi login tidak ditemukan, silakan login ulang.');
    }

    final res = await http.get(
      Uri.parse('$baseUrl/api/conversations/$conversationId/messages'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat isi percakapan');
    }

    final data = jsonDecode(res.body);
    final messagesJson = data['messages'] as List;
    return messagesJson
        .map((m) => ApiMessage(role: m['role'], content: m['content']))
        .toList();
  }

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