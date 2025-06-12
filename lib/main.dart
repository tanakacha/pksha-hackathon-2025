import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pksha/notification/models/notification_model.dart';
import 'package:pksha/notification/services/notification_service.dart';
import 'package:pksha/veiw/home/home_screen.dart';
// import 'services/notification_service.dart';
// import 'models/notification_model.dart';

void main() async {
  // Flutter初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();

  // 通知サービスの初期化
  await NotificationService().initialize();

  runApp(
    const ProviderScope(child: HomeScreen()),
  );
}

// バックエンドとの接続
Future<String> fetchWorkoutTime() async {
  final url = Uri.parse('http://localhost:8000/workout-time');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['time'] ?? 'No time available';
    } else {
      throw Exception('Failed to fetch workout time: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Error: $e');
  }
}
