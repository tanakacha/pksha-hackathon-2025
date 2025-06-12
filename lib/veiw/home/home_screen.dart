import 'package:flutter/material.dart';
import 'package:pksha/notification/models/notification_model.dart';
import 'package:pksha/notification/services/notification_service.dart';
import 'package:pksha/veiw/questionnaire/questionnaire_screen.dart';
import 'package:pksha/veiw/training/training_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '通知一覧',
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
      title: 'ランニング',
      message: 'ランニング30分の時間です',
      scheduledTime: DateTime.now().add(const Duration(hours: 1)),
      iconName: 'training',
    ),
  ];

  String workoutTime = "Press the button to get workout time";

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
      title: '腕立てふせ！',
      body: 'まずは1回やってみよう！',
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
      case 'training':
        return Icons.run_circle;
      default:
        return Icons.notifications;
    }
  }

  Future<void> getWorkoutTime() async {
    try {
      // localhostをエミュレーター用のIPアドレスに変更
      final url = Uri.parse('http://10.0.2.2:8000/workout-time');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          workoutTime = data['time'] ?? 'No time available';
        });
      } else {
        setState(() {
          workoutTime = 'Failed to fetch workout time: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        workoutTime = "Error: $error";
      });
    }
  }

  Future<void> getWorkoutTimeAndUpdateNotification() async {
    try {
      // FastAPIから筋トレ時間を取得
      final url = Uri.parse('http://localhost:8000/workout-time');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final workoutTimeString = data['time'];

        if (workoutTimeString != null) {
          try {
            // 現在の日付と取得した時刻を組み合わせてDateTime型を生成
            final now = DateTime.now();
            final workoutTimeParts = workoutTimeString.split(':');
            final workoutDateTime = DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(workoutTimeParts[0]),
              int.parse(workoutTimeParts[1]),
            );

            setState(() {
              // 「腕立て」の通知時刻を更新
              _notifications[0] = NotificationModel(
                id: _notifications[0].id,
                title: _notifications[0].title,
                message: _notifications[0].message,
                scheduledTime: workoutDateTime,
                iconName: _notifications[0].iconName,
              );
            });

            // 通知を再スケジュール
            await _notificationService.scheduleNotification(
              id: _notifications[0].id,
              title: _notifications[0].title,
              body: _notifications[0].message,
              scheduledTime: workoutDateTime,
              iconName: _notifications[0].iconName,
            );

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('腕立ての通知時刻を更新しました')));
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('時刻の変換に失敗しました')));
          }
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('筋トレ時間が取得できませんでした')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to fetch workout time: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知一覧'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // トレーニングボタン
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'トレーニング',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TrainingScreen()),
              );
            },
          ),
          // アンケートボタン
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.question_answer),
              tooltip: 'アンケート',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const QuestionnaireScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // リストビューを高さ制約付きでラップしてスクロール可能にする
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: ListView.builder(
                key: ValueKey(_notifications), // 再描画を強制するためのキー
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
            // 筋トレ時間を表示
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                workoutTime,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // 筋トレ時間を取得ボタン
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: getWorkoutTimeAndUpdateNotification,
                child: const Text('筋トレ時間を取得'),
              ),
            ),
          ],
        ),
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
