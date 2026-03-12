// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ZhiZhi';

  @override
  String get appSubtitle => 'AI Copilot for Managers';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String highlightCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items need your attention',
      one: '1 item needs your attention',
    );
    return '$_temp0';
  }

  @override
  String get allGood => 'All clear, nothing needs your attention';

  @override
  String restSummary(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other items progressing normally',
      one: '1 other item progressing normally',
    );
    return '$_temp0';
  }

  @override
  String todayCompleted(int count) {
    return '$count completed today';
  }

  @override
  String get viewAll => 'View all';

  @override
  String get longRunning => 'Running continuously';

  @override
  String get inputHint => 'Say something…';

  @override
  String get needsDecision => 'Needs your decision';

  @override
  String get failed => 'Failed, needs attention';

  @override
  String get inProgress => 'In progress';

  @override
  String get takingLong => 'Taking longer than expected';

  @override
  String get paused => 'Paused, waiting to resume';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get resume => 'Resume';

  @override
  String get detail => 'Details';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get confirmAll => 'Confirm all';

  @override
  String get viewConversation => 'View conversation';

  @override
  String get addNote => 'Add a note…';

  @override
  String get login => 'Sign in';

  @override
  String get signInWithApple => 'Sign in with Apple';

  @override
  String get signInWithGoogle => 'Sign in with Google';

  @override
  String get phoneLogin => 'Phone number';

  @override
  String get emailLogin => 'Email';

  @override
  String get orLoginWith => 'or';

  @override
  String get phone => 'Phone number';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get getCode => 'Get code';

  @override
  String countdownSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get email => 'Email address';

  @override
  String get loginAgreement =>
      'By signing in, you agree to our Terms of Service and Privacy Policy';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get termsOfService => 'Terms of Service';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get phoneNumber => 'Phone';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirm => 'Are you sure you want to sign out?';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountWarning =>
      'All data will be permanently deleted, including conversations, task history, and linked accounts. This action cannot be undone.';

  @override
  String get deleteAccountFinal =>
      'Are you sure you want to permanently delete your account and all data?';

  @override
  String get permanentDelete => 'Delete permanently';

  @override
  String get letMeThink => 'Let me think';

  @override
  String get feedback => 'Feedback';

  @override
  String get feedbackHint => 'Describe your issue or suggestion…';

  @override
  String get feedbackThanks => 'Thank you for your feedback!';

  @override
  String get submit => 'Submit';

  @override
  String get version => 'Version';

  @override
  String get aiService => 'AI Service';

  @override
  String get boundAccounts => 'Linked accounts';

  @override
  String get noAccounts => 'No accounts linked';

  @override
  String get support => 'Support';

  @override
  String get about => 'About';

  @override
  String get onboarding1Title => 'Just say it';

  @override
  String get onboarding1Subtitle =>
      'Voice, text, or photos — communicate naturally.\nNo templates, no forms.';

  @override
  String get onboarding2Title => 'AI executes for you';

  @override
  String get onboarding2Subtitle =>
      'The AI understands your intent.\nAgent Team handles the work.\nYou just make decisions.';

  @override
  String get onboarding3Title => 'Track progress anytime';

  @override
  String get onboarding3Subtitle =>
      'Pending decisions pinned on top.\nTasks running in parallel.\nResults ready to use.';

  @override
  String get skip => 'Skip';

  @override
  String get next => 'Next';

  @override
  String get getStarted => 'Get started';

  @override
  String get understanding => 'I understand this as';

  @override
  String get planSteps => 'Here\'s my plan';

  @override
  String get executing => 'Executing';

  @override
  String get completed => 'Completed';

  @override
  String get taskFailed => 'Execution failed';

  @override
  String get taskCancelled => 'Task cancelled';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get continueProcessing => 'Continue';

  @override
  String get toDocument => 'To doc';

  @override
  String get setReminder => 'Remind me';

  @override
  String get moreInfo => 'More info';

  @override
  String get search => 'Search';

  @override
  String get allTasks => 'All tasks';

  @override
  String get pendingConfirm => 'Pending';

  @override
  String get executingTasks => 'In progress';

  @override
  String get completedTasks => 'Completed';

  @override
  String get earlierTasks => 'Earlier';

  @override
  String get noTasks => 'No tasks yet. Say something to start.';

  @override
  String get sendFailed => 'Failed to send command';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get networkError => 'Network error, please check your connection';

  @override
  String get loginExpired => 'Session expired, please sign in again';

  @override
  String get deleteSession => 'Delete conversation';

  @override
  String get deleteSessionConfirm => 'Delete this conversation?';

  @override
  String get newSession => 'New conversation';

  @override
  String get scene1Title => 'Write a plan';

  @override
  String get scene1Desc => 'Reports, email drafts, meeting notes';

  @override
  String get scene2Title => 'Make a list';

  @override
  String get scene2Desc => 'Break things into action items';

  @override
  String get scene3Title => 'Help me think';

  @override
  String get scene3Desc => 'Analyze problems, give suggestions';

  @override
  String get scene4Title => 'Send an email';

  @override
  String get scene4Desc => 'Draft and send emails';

  @override
  String get tryFirstCommand => 'Try saying something';

  @override
  String get tapSceneToStart => 'Or tap a scenario below to get started';

  @override
  String get commandSent => 'Command sent, AI is processing…';

  @override
  String get uploading => 'Uploading…';

  @override
  String get taskNotFound => 'Task not found';

  @override
  String get executionProgress => 'Execution progress';

  @override
  String get finalResult => 'Result';

  @override
  String get followUpHint => 'Follow up…';

  @override
  String get confirmExecution => 'Confirm';

  @override
  String get conversation => 'Conversation';

  @override
  String get confirmExecuting => 'Confirmed, executing…';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get retrying => 'Retrying…';

  @override
  String get retryingUnderstand => 'Re-analyzing…';

  @override
  String get followUpFailed => 'Follow-up failed';

  @override
  String get confirmFailed => 'Confirm failed';

  @override
  String get cancelFailed => 'Cancel failed';

  @override
  String get retryFailed => 'Retry failed';

  @override
  String get pause => 'Pause';

  @override
  String get addAccount => 'Add account';

  @override
  String get editAccount => 'Edit account';

  @override
  String get wechatWorkWebhook => 'WeChat Work Bot';

  @override
  String get wechatWorkWebhookHint => 'Paste group bot Webhook URL';

  @override
  String get intlPhoneNotSupported =>
      'International numbers not supported for SMS. Please use email or Apple Sign-In.';

  @override
  String get confirmDeleteAccount => 'Confirm deletion';
}
