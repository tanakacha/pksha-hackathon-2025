import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pksha/veiw/questionnaire/questionnaire_provider.dart';

class QuestionnaireScreen extends ConsumerWidget {
  const QuestionnaireScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // questionnaireProviderから状態を監視
    final questionnaireState = ref.watch(questionnaireProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('アンケート'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'トレーニングスタイル診断',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'あなたに合ったトレーニング方法を見つけるために、以下の質問に答えてください。',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 質問1
            _buildQuestionCard(
              context,
              'Q1: 褒められるとやる気が出ますか？',
              questionnaireState.answer1,
              (value) =>
                  ref.read(questionnaireProvider.notifier).updateAnswer1(value),
            ),

            const SizedBox(height: 12),

            // 質問2
            _buildQuestionCard(
              context,
              'Q2: キツめに言われた方が燃えますか？',
              questionnaireState.answer2,
              (value) =>
                  ref.read(questionnaireProvider.notifier).updateAnswer2(value),
            ),

            const SizedBox(height: 12),

            // 質問3
            _buildQuestionCard(
              context,
              'Q3: 理屈で納得できないと動けませんか？',
              questionnaireState.answer3,
              (value) =>
                  ref.read(questionnaireProvider.notifier).updateAnswer3(value),
            ),

            const Spacer(),

            // 送信ボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    questionnaireState.isAllAnswered
                        ? () => _submitAnswers(context, questionnaireState)
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('回答を送信', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 質問カードのウィジェットを構築
  Widget _buildQuestionCard(
    BuildContext context,
    String question,
    bool? answer,
    Function(bool) onChanged,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // はいボタン
                Expanded(
                  child: _buildAnswerButton(
                    context,
                    'はい',
                    answer == true,
                    () => onChanged(true),
                  ),
                ),
                const SizedBox(width: 16),
                // いいえボタン
                Expanded(
                  child: _buildAnswerButton(
                    context,
                    'いいえ',
                    answer == false,
                    () => onChanged(false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 回答ボタンのウィジェットを構築
  Widget _buildAnswerButton(
    BuildContext context,
    String label,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        side: BorderSide(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  // 回答を送信
  void _submitAnswers(BuildContext context, QuestionnaireState state) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('診断結果'),
            content: Text('あなたに合ったトレーニングスタイルは「${state.resultType}」です！'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ダイアログを閉じる
                  Navigator.of(context).pop(); // 前の画面に戻る
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
