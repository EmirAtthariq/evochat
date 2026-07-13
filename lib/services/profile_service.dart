import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String email;
  final String? nama;
  final String? domisili;

  UserProfile({
    required this.email,
    required this.nama,
    required this.domisili,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'],
      nama: json['nama'],
      domisili: json['domisili'],
    );
  }
}

class ProfileService {
  final String baseUrl;
  ProfileService({required this.baseUrl});

  Future<UserProfile> fetchUserProfile() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw Exception('Sesi login tidak ditemukan, silakan login ulang.');
    }

    final res = await http.get(
      Uri.parse('$baseUrl/api/profile'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    );

    if (res.statusCode != 200) {
      throw Exception('Gagal memuat profil pengguna');
    }

    final data = jsonDecode(res.body);
    return UserProfile.fromJson(data);
  }
}