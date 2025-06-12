import 'package:flutter_riverpod/flutter_riverpod.dart';

// アンケート回答の状態を管理するクラス
class QuestionnaireState {
  final bool? answer1; // Q1: 褒められるとやる気が出る
  final bool? answer2; // Q2: キツめに言われた方が燃える
  final bool? answer3; // Q3: 理屈で納得できないと動けない

  QuestionnaireState({this.answer1, this.answer2, this.answer3});

  // 新しい状態を生成するコピーメソッド
  QuestionnaireState copyWith({bool? answer1, bool? answer2, bool? answer3}) {
    return QuestionnaireState(
      answer1: answer1 ?? this.answer1,
      answer2: answer2 ?? this.answer2,
      answer3: answer3 ?? this.answer3,
    );
  }

  // すべての質問に回答したかチェック
  bool get isAllAnswered =>
      answer1 != null && answer2 != null && answer3 != null;

  // 回答結果からタイプを判定
  String get resultType {
    if (answer1 == true && answer2 == false) {
      return 'ポジティブ応援型';
    } else if (answer1 == false && answer2 == true) {
      return 'ハードプッシュ型';
    } else if (answer3 == true) {
      return '理論重視型';
    } else {
      return 'バランス型';
    }
  }
}

// アンケート状態を管理するノティファイアプロバイダー
class QuestionnaireNotifier extends StateNotifier<QuestionnaireState> {
  QuestionnaireNotifier() : super(QuestionnaireState());

  // 質問1の回答を更新
  void updateAnswer1(bool value) {
    state = state.copyWith(answer1: value);
  }

  // 質問2の回答を更新
  void updateAnswer2(bool value) {
    state = state.copyWith(answer2: value);
  }

  // 質問3の回答を更新
  void updateAnswer3(bool value) {
    state = state.copyWith(answer3: value);
  }

  // 状態をリセット
  void reset() {
    state = QuestionnaireState();
  }
}

// アンケート状態のプロバイダー
final questionnaireProvider =
    StateNotifierProvider<QuestionnaireNotifier, QuestionnaireState>((ref) {
      return QuestionnaireNotifier();
    });
