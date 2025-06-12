import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pksha/veiw/training/training_provider.dart';

class TrainingScreen extends ConsumerWidget {
  const TrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // トレーニングリストの状態を監視
    final trainingState = ref.watch(trainingListProvider);
    final items = trainingState.items;
    final completionRate = trainingState.completionRate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('トレーニングリスト'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // リセットボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'リセット',
            onPressed: () {
              ref.read(trainingListProvider.notifier).resetAllItems();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('すべてのトレーニングをリセットしました')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 進捗バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '進捗状況: ${(completionRate * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${items.where((item) => item.isCompleted).length}/${items.length}完了',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionRate,
                  backgroundColor: Colors.grey[300],
                  color: Theme.of(context).colorScheme.primary,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
          ),

          // トレーニングリスト
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildTrainingItem(context, ref, item);
              },
            ),
          ),
        ],
      ),
    );
  }

  // トレーニング項目のカードウィジェット
  Widget _buildTrainingItem(
    BuildContext context,
    WidgetRef ref,
    TrainingItem item,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          // タップで完了状態を切り替え
          ref.read(trainingListProvider.notifier).toggleComplete(item.id);
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // アイコン
              Icon(
                _getIconData(item.icon),
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 16),
              // トレーニング情報
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration:
                            item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                        color: item.isCompleted ? Colors.grey : Colors.black,
                      ),
                    ),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 14,
                        color:
                            item.isCompleted ? Colors.grey : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              // チェックボックス
              Checkbox(
                value: item.isCompleted,
                activeColor: Theme.of(context).colorScheme.primary,
                onChanged: (bool? value) {
                  ref
                      .read(trainingListProvider.notifier)
                      .toggleComplete(item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // アイコン名からIconDataを取得
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'muscle':
        return Icons.fitness_center;
      case 'training':
        return Icons.directions_run;
      default:
        return Icons.sports;
    }
  }
}
