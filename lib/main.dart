import 'package:flutter/material.dart';
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

  runApp(const HomeScreen());
}
