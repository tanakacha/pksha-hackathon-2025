// 通知のモデルクラス
class NotificationModel {
  final int id;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final String? iconName;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.scheduledTime,
    this.iconName,
  });
}
