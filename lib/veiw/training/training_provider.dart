import 'package:flutter_riverpod/flutter_riverpod.dart';

// トレーニング項目のモデルクラス
class TrainingItem {
  final int id;
  final String title;
  final String description;
  final String icon;
  final bool isCompleted;

  TrainingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.isCompleted = false,
  });

  // 新しい状態でコピーを生成するメソッド
  TrainingItem copyWith({
    int? id,
    String? title,
    String? description,
    String? icon,
    bool? isCompleted,
  }) {
    return TrainingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

// トレーニングリストの状態クラス
class TrainingListState {
  final List<TrainingItem> items;
  final double completionRate; // 完了率（0.0〜1.0）

  TrainingListState({required this.items, this.completionRate = 0.0});

  // 新しい状態でコピーを生成するメソッド
  TrainingListState copyWith({
    List<TrainingItem>? items,
    double? completionRate,
  }) {
    return TrainingListState(
      items: items ?? this.items,
      completionRate: completionRate ?? this.completionRate,
    );
  }

  // 完了率を計算するメソッド
  double calculateCompletionRate() {
    if (items.isEmpty) return 0.0;
    int completedCount = items.where((item) => item.isCompleted).length;
    return completedCount / items.length;
  }
}

// トレーニングリスト状態管理用のノティファイア
class TrainingListNotifier extends StateNotifier<TrainingListState> {
  TrainingListNotifier()
    : super(
        TrainingListState(
          items: [
            // サンプルのトレーニング項目を初期状態としてセット
            TrainingItem(
              id: 1,
              title: '腹筋',
              description: '10回×3セット',
              icon: 'muscle',
            ),
            TrainingItem(
              id: 2,
              title: '腕立て伏せ',
              description: '5回×3セット',
              icon: 'muscle',
            ),
            TrainingItem(
              id: 3,
              title: 'スクワット',
              description: '15回×3セット',
              icon: 'training',
            ),
            TrainingItem(
              id: 4,
              title: 'ランニング',
              description: '20分間',
              icon: 'training',
            ),
            TrainingItem(
              id: 5,
              title: 'ストレッチ',
              description: '全身5分間',
              icon: 'training',
            ),
          ],
          completionRate: 0.0,
        ),
      );

  // トレーニング項目の完了状態を切り替える
  void toggleComplete(int id) {
    state = state.copyWith(
      items:
          state.items.map((item) {
            if (item.id == id) {
              return item.copyWith(isCompleted: !item.isCompleted);
            }
            return item;
          }).toList(),
    );

    // 完了率を更新
    updateCompletionRate();
  }

  // すべてのトレーニングをリセット
  void resetAllItems() {
    state = state.copyWith(
      items:
          state.items.map((item) => item.copyWith(isCompleted: false)).toList(),
      completionRate: 0.0,
    );
  }

  // 完了率を計算して更新
  void updateCompletionRate() {
    double newRate = state.calculateCompletionRate();
    state = state.copyWith(completionRate: newRate);
  }
}

// トレーニングリスト状態のプロバイダー
final trainingListProvider =
    StateNotifierProvider<TrainingListNotifier, TrainingListState>((ref) {
      return TrainingListNotifier();
    });
