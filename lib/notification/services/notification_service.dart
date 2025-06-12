import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();

    // iOS 通知設定 - フォアグラウンド表示設定を強化
    final DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          defaultPresentAlert: true,
          defaultPresentBadge: true,
          defaultPresentSound: true,
          defaultPresentBanner: true,
          defaultPresentList: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'plainCategory',
              actions: [DarwinNotificationAction.plain('id', 'タイトル')],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
            DarwinNotificationCategory(
              'alarm',
              actions: [DarwinNotificationAction.plain('stop', '停止')],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
          ],
        );

    final InitializationSettings initSettings = InitializationSettings(
      iOS: iOSSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint('通知がタップされました: ${details.payload}');
      },
    );

    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // 即時通知を送信する簡易メソッド
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? iconName,
  }) async {
    // 最大レベルの割り込み設定でiOS通知を構成
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive, // 時間に敏感な通知として設定
      categoryIdentifier: iconName ?? 'alarm', // アラームまたは指定したアイコン名
      threadIdentifier: 'alarm_notifications', // 通知をグループ化
      attachments: getNotificationAttachment(iconName), // 通知にカスタム画像を添付
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
    );
  }

  // 指定時間に通知を予約
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? iconName,
  }) async {
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: iconName ?? 'alarm', // アラームまたは指定したアイコン名
      threadIdentifier: 'alarm_notifications', // 通知をグループ化
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      iOS: iosDetails,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  // 通知アイコン名に基づいて添付ファイルを取得
  List<DarwinNotificationAttachment>? getNotificationAttachment(String? iconName) {
    // iconNameに基づいて異なる添付ファイルを返す
    // 注意: 実際の画像ファイルはiOSのAssets.xcassetsに追加する必要があります
    try {
      if (iconName == null) return null;
      
      String assetName;
      
      switch (iconName) {
        case 'alarm':
          assetName = 'alarm_icon';
          break;
        case 'task':
          assetName = 'task_icon';
          break;
        case 'meeting':
          assetName = 'meeting_icon';
          break;
        case 'alert':
          assetName = 'alert_icon';
          break;
        case 'test':
          assetName = 'test_icon';
          break;
        default:
          assetName = 'notification_icon';
      }
      
      // iOS用の添付ファイルパス
      // 注意: 実際のパスはプロジェクトによって異なる場合があります
      final String attachmentPath = 'Library/Application Support/NotificationImages/$assetName.png';
      return [
        DarwinNotificationAttachment(
          identifier: 'image',
          url: Uri.file(attachmentPath),
          hideThumbnail: false,
        ),
      ];
    } catch (e) {
      debugPrint('通知添付ファイルエラー: $e');
      return null;
    }
  }
}
