import 'package:flutter/material.dart';
import 'package:pksha/notification/models/notification_model.dart';
import 'package:pksha/notification/services/notification_service.dart';
import 'package:pksha/veiw/questionnaire/questionnaire_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
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
      title: '腕立て',
      message: '腕立て10回の時間です',
      scheduledTime: DateTime.now().add(const Duration(minutes: 10)),
      iconName: 'muscle',
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
      iconName: 'meeting',
    ),
    NotificationModel(
      id: 4,
      title: 'アラート',
      message: '緊急アラートです',
      scheduledTime: DateTime.now().add(const Duration(hours: 3)),
      iconName: 'alert',
    ),
    NotificationModel(
      id: 5,
      title: 'アラーム',
      message: '設定したアラームの時間です',
      scheduledTime: DateTime.now().add(const Duration(minutes: 30)),
      iconName: 'alarm',
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
      iconName: 'muscle',
    );

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テスト通知を送信しました')));
  }

  // アイコン名から適切なIconDataを取得
  IconData _getIconData(String? iconName) {
    switch (iconName) {
      case 'muscle':
        return Icons.fitness_center;
      case 'alarm':
        return Icons.alarm;
      case 'meeting':
        return Icons.people;
      case 'task':
        return Icons.assignment;
      case 'alert':
        return Icons.warning;
      case 'test':
        return Icons.notifications_active;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知サンプル'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // リストビューをExpandedでラップして高さ制約を与える
          Expanded(
            child: ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return ListTile(
                  title: Text(notification.title),
                  subtitle: Text(notification.message),
                  trailing: Text(
                    '${notification.scheduledTime.hour}:${notification.scheduledTime.minute.toString().padLeft(2, '0')}',
                  ),
                  leading: Icon(_getIconData(notification.iconName)),
                );
              },
            ),
          ),

          // 画面遷移ボタンを追加
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                // 新しい画面に遷移
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const QuestionnaireScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50), // 横幅いっぱい、高さ50
              ),
              child: const Text('アンケートに進む'),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendTestNotification,
        tooltip: 'テスト通知',
        child: const Icon(Icons.notifications_active),
      ),
    );
  }
}

// 遷移先の画面を定義
class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('次の画面'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('新しい画面です', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // 前の画面に戻る
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
