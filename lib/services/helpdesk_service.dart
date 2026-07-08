import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class HelpdeskContact {
  final String id;
  final String label;
  final String whatsappNumber;

  HelpdeskContact({
    required this.id,
    required this.label,
    required this.whatsappNumber,
  });

  factory HelpdeskContact.fromJson(Map<String, dynamic> json) {
    return HelpdeskContact(
      id: json['id'],
      label: json['label'],
      whatsappNumber: json['whatsapp_number'],
    );
  }
}

// wrapper baru buat nampung domisili + list contacts sekaligus
class HelpdeskData {
  final String domisili;
  final List<HelpdeskContact> contacts;

  HelpdeskData({required this.domisili, required this.contacts});
}

class HelpdeskService {
  final String baseUrl;
  HelpdeskService({required this.baseUrl});

  Future<HelpdeskData> fetchContacts() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      throw Exception('Sesi login tidak ditemukan, silakan login ulang.');
    }

    final res = await http.get(
      Uri.parse('$baseUrl/api/helpdesk'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
      },
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Gagal memuat data helpdesk');
    }

    final data = jsonDecode(res.body);
    final contactsJson = data['contacts'] as List;

    return HelpdeskData(
      domisili: data['domisili'] ?? '',
      contacts: contactsJson.map((c) => HelpdeskContact.fromJson(c)).toList(),
    );
  }
}