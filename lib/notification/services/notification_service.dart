import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

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
              'muscle',
              actions: [DarwinNotificationAction.plain('done', '完了')],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
            DarwinNotificationCategory(
              'task',
              actions: [
                DarwinNotificationAction.plain('complete', '完了'),
                DarwinNotificationAction.plain('postpone', '延期'),
              ],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
            DarwinNotificationCategory(
              'meeting',
              actions: [
                DarwinNotificationAction.plain('attend', '参加'),
                DarwinNotificationAction.plain('decline', '辞退'),
              ],
              options: <DarwinNotificationCategoryOption>{
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
            DarwinNotificationCategory(
              'alert',
              actions: [DarwinNotificationAction.plain('acknowledge', '確認')],
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
    // アイコンの添付ファイルを取得
    final attachments = await _getNotificationAttachments(iconName);

    // 最大レベルの割り込み設定でiOS通知を構成
    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive, // 時間に敏感な通知として設定
      categoryIdentifier: iconName ?? 'muscle', // アラームまたは指定したアイコン名
      threadIdentifier: 'alarm_notifications', // 通知をグループ化
      attachments: attachments,
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
    // アイコンの添付ファイルを取得
    final attachments = await _getNotificationAttachments(iconName);

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      sound: 'default',
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: iconName ?? 'muscle', // muscleアイコンをデフォルトにする
      threadIdentifier: 'alarm_notifications', // 通知をグループ化
      attachments: attachments,
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

  // 通知アイコンの添付ファイルを生成するメソッド
  Future<List<DarwinNotificationAttachment>?> _getNotificationAttachments(
    String? iconName,
  ) async {
    try {
      // すべての通知でmuscleアイコンを使用（または指定されたアイコンを使用）
      final String iconPath = 'assets/icons/${iconName ?? 'muscle'}.png';

      // アセットからファイルを読み込む
      final ByteData byteData = await rootBundle.load(iconPath);
      final Uint8List imageBytes = byteData.buffer.asUint8List();

      // 一時ファイルに保存
      final String tempPath =
          '${Directory.systemTemp.path}/${iconName ?? 'muscle'}.png';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageBytes);

      // 添付ファイルを生成
      final attachment = DarwinNotificationAttachment(
        tempPath,
        identifier: 'notification_icon',
      );

      return [attachment];
    } catch (e) {
      debugPrint('通知アイコンの設定中にエラーが発生しました: $e');
      return null;
    }
  }
}
