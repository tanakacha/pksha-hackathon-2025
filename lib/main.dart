import 'package:flutter/material.dart';
import 'package:pksha/notification/notification.dart';
// import 'services/notification_service.dart';
// import 'models/notification_model.dart';

void main() async {
  // Flutter初期化を確実に行う
  WidgetsFlutterBinding.ensureInitialized();

  // 通知サービスの初期化
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通知アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const NotificationScreen(),
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();

  // モックデータ（ハードコーディング）
  final List<NotificationModel> _notifications = [
    NotificationModel(
      id: 1,
      title: '会議のお知らせ',
      message: '10分後に会議が始まります',
      scheduledTime: DateTime.now().add(const Duration(minutes: 10)),
      iconName: 'meeting',
    ),
    NotificationModel(
      id: 2,
      title: 'タスク期限',
      message: 'プロジェクト提出期限です',
      scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      iconName: 'task',
    ),
    NotificationModel(
      id: 3,
      title: 'ミーティング',
      message: 'チームミーティングの時間です',
      scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      iconName: 'alert',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // アプリ起動時にモックデータの通知をスケジュール
    _scheduleNotifications();
  }

  // 通知をスケジュール
  void _scheduleNotifications() async {
    for (var notification in _notifications) {
      if (notification.scheduledTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotification(
          id: notification.id,
          title: notification.title,
          body: notification.message,
          scheduledTime: notification.scheduledTime,
          iconName: notification.iconName,
        );
      }
    }
  }

  // テスト用の即時通知
  void _sendTestNotification() async {
    print("テスト通知を送信します...");

    // 現在時刻の10秒後に通知をスケジュール
    final now = DateTime.now().add(const Duration(seconds: 10));

    // まずは即時通知を試す
    await _notificationService.showNotification(
      id: 0,
      title: 'テスト即時通知',
      body: '即時通知のテストです',
      iconName: 'test',
    );

    // 10秒後の通知もスケジュール
    await _notificationService.scheduleNotification(
      id: 999,
      title: '予約通知テスト',
      body: '10秒後に予約した通知です',
      scheduledTime: now,
      iconName: 'test',
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テスト通知を送信しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知サンプル'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return ListTile(
            title: Text(notification.title),
            subtitle: Text(notification.message),
            trailing: Text(
              '${notification.scheduledTime.hour}:${notification.scheduledTime.minute.toString().padLeft(2, '0')}',
            ),
            leading: const Icon(Icons.notifications),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendTestNotification,
        tooltip: 'テスト通知',
        child: const Icon(Icons.notifications_active),
      ),
    );
  }
}
