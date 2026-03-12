// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => '知知';

  @override
  String get appSubtitle => 'AI時代のマネージャー司令台';

  @override
  String get goodMorning => 'おはようございます';

  @override
  String get goodAfternoon => 'こんにちは';

  @override
  String get goodEvening => 'こんばんは';

  @override
  String highlightCount(int count) {
    return '$count件の確認事項があります';
  }

  @override
  String get allGood => 'すべて順調です。対応が必要なものはありません';

  @override
  String restSummary(int count) {
    return '他$count件は正常に進行中';
  }

  @override
  String todayCompleted(int count) {
    return '本日$count件完了';
  }

  @override
  String get viewAll => 'すべて表示';

  @override
  String get longRunning => '継続実行中';

  @override
  String get inputHint => '何かお伝えください…';

  @override
  String get needsDecision => '判断が必要です';

  @override
  String get failed => '実行失敗、対応が必要です';

  @override
  String get inProgress => '進行中';

  @override
  String get takingLong => '予想より時間がかかっています';

  @override
  String get paused => '一時停止中';

  @override
  String get confirm => '確認';

  @override
  String get cancel => 'キャンセル';

  @override
  String get retry => '再試行';

  @override
  String get resume => '再開';

  @override
  String get detail => '詳細';

  @override
  String get delete => '削除';

  @override
  String get save => '保存';

  @override
  String get confirmAll => 'すべて確認';

  @override
  String get viewConversation => '会話を見る';

  @override
  String get addNote => '補足を追加…';

  @override
  String get login => 'ログイン';

  @override
  String get signInWithApple => 'Appleでサインイン';

  @override
  String get signInWithGoogle => 'Googleでサインイン';

  @override
  String get phoneLogin => '電話番号';

  @override
  String get emailLogin => 'メール';

  @override
  String get orLoginWith => 'または';

  @override
  String get phone => '電話番号';

  @override
  String get verificationCode => '認証コード';

  @override
  String get getCode => 'コードを取得';

  @override
  String countdownSeconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get email => 'メールアドレス';

  @override
  String get loginAgreement => 'ログインすると利用規約とプライバシーポリシーに同意したことになります';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get termsOfService => '利用規約';

  @override
  String get settings => '設定';

  @override
  String get account => 'アカウント';

  @override
  String get phoneNumber => '電話番号';

  @override
  String get logout => 'ログアウト';

  @override
  String get logoutConfirm => 'ログアウトしますか？';

  @override
  String get deleteAccount => 'アカウント削除';

  @override
  String get deleteAccountWarning => 'すべてのデータが完全に削除されます。この操作は取り消せません。';

  @override
  String get deleteAccountFinal => '本当にアカウントとすべてのデータを削除しますか？';

  @override
  String get permanentDelete => '完全に削除';

  @override
  String get letMeThink => 'もう少し考えます';

  @override
  String get feedback => 'フィードバック';

  @override
  String get feedbackHint => '問題やご提案をお聞かせください…';

  @override
  String get feedbackThanks => 'フィードバックありがとうございます！';

  @override
  String get submit => '送信';

  @override
  String get version => 'バージョン';

  @override
  String get aiService => 'AIサービス';

  @override
  String get boundAccounts => '連携済みアカウント';

  @override
  String get noAccounts => 'アカウント連携なし';

  @override
  String get support => 'サポート';

  @override
  String get about => 'について';

  @override
  String get onboarding1Title => '話すだけ';

  @override
  String get onboarding1Subtitle => '音声、テキスト、写真、自然にコミュニケーション。\nテンプレートもフォームも不要。';

  @override
  String get onboarding2Title => 'AIが実行';

  @override
  String get onboarding2Subtitle => 'AIがあなたの意図を理解し、\nAgent Teamが実行。\nあなたは判断だけ。';

  @override
  String get onboarding3Title => 'いつでも進捗確認';

  @override
  String get onboarding3Subtitle => '判断待ちの案件はトップに表示。\nタスクは並行して進行。\n結果はすぐ使える。';

  @override
  String get skip => 'スキップ';

  @override
  String get next => '次へ';

  @override
  String get getStarted => '始める';

  @override
  String get understanding => '私の理解';

  @override
  String get planSteps => '実行計画';

  @override
  String get executing => '実行中';

  @override
  String get completed => '完了';

  @override
  String get taskFailed => '実行失敗';

  @override
  String get taskCancelled => 'キャンセル済み';

  @override
  String get confirmed => '確認済み';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'コピーしました';

  @override
  String get continueProcessing => '続行';

  @override
  String get toDocument => '文書化';

  @override
  String get setReminder => 'リマインダー';

  @override
  String get moreInfo => '補足情報';

  @override
  String get search => '検索';

  @override
  String get allTasks => 'すべてのタスク';

  @override
  String get pendingConfirm => '判断待ち';

  @override
  String get executingTasks => '進行中';

  @override
  String get completedTasks => '完了';

  @override
  String get earlierTasks => '以前';

  @override
  String get noTasks => 'タスクはまだありません。何かお伝えください。';

  @override
  String get sendFailed => '送信に失敗しました';

  @override
  String get uploadFailed => 'アップロードに失敗しました';

  @override
  String get networkError => 'ネットワークエラー、接続を確認してください';

  @override
  String get loginExpired => 'セッションが切れました。再度ログインしてください';

  @override
  String get deleteSession => '会話を削除';

  @override
  String get deleteSessionConfirm => 'この会話を削除しますか？';

  @override
  String get newSession => '新しい会話';

  @override
  String get scene1Title => '企画書を書く';

  @override
  String get scene1Desc => 'レポート、メール下書き、議事録';

  @override
  String get scene2Title => 'リストを作る';

  @override
  String get scene2Desc => 'タスクをアクション項目に分解';

  @override
  String get scene3Title => '一緒に考える';

  @override
  String get scene3Desc => '問題を分析、提案を出す';

  @override
  String get scene4Title => 'メールを送る';

  @override
  String get scene4Desc => 'メールの作成と送信';

  @override
  String get tryFirstCommand => '何か言ってみてください';

  @override
  String get tapSceneToStart => 'または下のシナリオをタップ';

  @override
  String get commandSent => '指示を送信しました。AIが処理中…';

  @override
  String get uploading => 'アップロード中…';

  @override
  String get taskNotFound => 'タスクが見つかりません';

  @override
  String get executionProgress => '実行状況';

  @override
  String get finalResult => '結果';

  @override
  String get followUpHint => 'フォローアップ…';

  @override
  String get confirmExecution => '実行を確認';

  @override
  String get conversation => '会話';

  @override
  String get confirmExecuting => '確認済み、実行中…';

  @override
  String get cancelled => 'キャンセル済み';

  @override
  String get retrying => '再試行中…';

  @override
  String get retryingUnderstand => '再分析中…';

  @override
  String get followUpFailed => 'フォローアップ送信失敗';

  @override
  String get confirmFailed => '確認に失敗';

  @override
  String get cancelFailed => 'キャンセルに失敗';

  @override
  String get retryFailed => '再試行に失敗';

  @override
  String get pause => '一時停止';

  @override
  String get addAccount => 'アカウント追加';

  @override
  String get editAccount => 'アカウント編集';

  @override
  String get wechatWorkWebhook => '企業微信ボット';

  @override
  String get wechatWorkWebhookHint => 'グループボットWebhook URLを貼り付け';

  @override
  String get intlPhoneNotSupported => '国際番号はSMS非対応です。メールまたはAppleサインインをご利用ください。';

  @override
  String get confirmDeleteAccount => '削除を確認';
}
