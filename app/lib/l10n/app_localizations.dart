import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'知知'**
  String get appName;

  /// No description provided for @appSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'AI 时代的管理者指挥台'**
  String get appSubtitle;

  /// No description provided for @goodMorning.
  ///
  /// In zh, this message translates to:
  /// **'早上好'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In zh, this message translates to:
  /// **'下午好'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In zh, this message translates to:
  /// **'晚上好'**
  String get goodEvening;

  /// No description provided for @highlightCount.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 件事需要你关注'**
  String highlightCount(int count);

  /// No description provided for @allGood.
  ///
  /// In zh, this message translates to:
  /// **'一切顺利，没有需要你处理的事'**
  String get allGood;

  /// No description provided for @restSummary.
  ///
  /// In zh, this message translates to:
  /// **'其他 {count} 件事正常推进中'**
  String restSummary(int count);

  /// No description provided for @todayCompleted.
  ///
  /// In zh, this message translates to:
  /// **'今日完成 {count} 项'**
  String todayCompleted(int count);

  /// No description provided for @viewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get viewAll;

  /// No description provided for @longRunning.
  ///
  /// In zh, this message translates to:
  /// **'持续运行中'**
  String get longRunning;

  /// No description provided for @inputHint.
  ///
  /// In zh, this message translates to:
  /// **'说点什么…'**
  String get inputHint;

  /// No description provided for @needsDecision.
  ///
  /// In zh, this message translates to:
  /// **'需要你拍板'**
  String get needsDecision;

  /// No description provided for @failed.
  ///
  /// In zh, this message translates to:
  /// **'执行失败，需要处理'**
  String get failed;

  /// No description provided for @inProgress.
  ///
  /// In zh, this message translates to:
  /// **'正在进行'**
  String get inProgress;

  /// No description provided for @takingLong.
  ///
  /// In zh, this message translates to:
  /// **'执行时间较长，可能需要关注'**
  String get takingLong;

  /// No description provided for @paused.
  ///
  /// In zh, this message translates to:
  /// **'已暂停，等待恢复'**
  String get paused;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @resume.
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get resume;

  /// No description provided for @detail.
  ///
  /// In zh, this message translates to:
  /// **'查看详情'**
  String get detail;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @confirmAll.
  ///
  /// In zh, this message translates to:
  /// **'全部确认'**
  String get confirmAll;

  /// No description provided for @viewConversation.
  ///
  /// In zh, this message translates to:
  /// **'查看对话'**
  String get viewConversation;

  /// No description provided for @addNote.
  ///
  /// In zh, this message translates to:
  /// **'补充一句…'**
  String get addNote;

  /// No description provided for @login.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get login;

  /// No description provided for @signInWithApple.
  ///
  /// In zh, this message translates to:
  /// **'通过 Apple 登录'**
  String get signInWithApple;

  /// No description provided for @signInWithGoogle.
  ///
  /// In zh, this message translates to:
  /// **'通过 Google 登录'**
  String get signInWithGoogle;

  /// No description provided for @phoneLogin.
  ///
  /// In zh, this message translates to:
  /// **'手机号登录'**
  String get phoneLogin;

  /// No description provided for @emailLogin.
  ///
  /// In zh, this message translates to:
  /// **'邮箱登录'**
  String get emailLogin;

  /// No description provided for @orLoginWith.
  ///
  /// In zh, this message translates to:
  /// **'或'**
  String get orLoginWith;

  /// No description provided for @phone.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get phone;

  /// No description provided for @verificationCode.
  ///
  /// In zh, this message translates to:
  /// **'验证码'**
  String get verificationCode;

  /// No description provided for @getCode.
  ///
  /// In zh, this message translates to:
  /// **'获取验证码'**
  String get getCode;

  /// No description provided for @countdownSeconds.
  ///
  /// In zh, this message translates to:
  /// **'{seconds}s'**
  String countdownSeconds(int seconds);

  /// No description provided for @email.
  ///
  /// In zh, this message translates to:
  /// **'邮箱地址'**
  String get email;

  /// No description provided for @loginAgreement.
  ///
  /// In zh, this message translates to:
  /// **'登录即表示同意《用户协议》和《隐私政策》'**
  String get loginAgreement;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In zh, this message translates to:
  /// **'用户协议'**
  String get termsOfService;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get account;

  /// No description provided for @phoneNumber.
  ///
  /// In zh, this message translates to:
  /// **'手机号'**
  String get phoneNumber;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get logout;

  /// No description provided for @logoutConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定退出当前账号？'**
  String get logoutConfirm;

  /// No description provided for @deleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'注销账号'**
  String get deleteAccount;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In zh, this message translates to:
  /// **'注销后所有数据将被永久删除，包括会话记录、任务历史、绑定账号等。此操作不可撤销。'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountFinal.
  ///
  /// In zh, this message translates to:
  /// **'真的要永久删除账号和所有数据吗？'**
  String get deleteAccountFinal;

  /// No description provided for @permanentDelete.
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get permanentDelete;

  /// No description provided for @letMeThink.
  ///
  /// In zh, this message translates to:
  /// **'我再想想'**
  String get letMeThink;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'意见反馈'**
  String get feedback;

  /// No description provided for @feedbackHint.
  ///
  /// In zh, this message translates to:
  /// **'请描述你遇到的问题或建议…'**
  String get feedbackHint;

  /// No description provided for @feedbackThanks.
  ///
  /// In zh, this message translates to:
  /// **'感谢你的反馈！'**
  String get feedbackThanks;

  /// No description provided for @submit.
  ///
  /// In zh, this message translates to:
  /// **'提交'**
  String get submit;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @aiService.
  ///
  /// In zh, this message translates to:
  /// **'AI 服务'**
  String get aiService;

  /// No description provided for @boundAccounts.
  ///
  /// In zh, this message translates to:
  /// **'已绑定账号'**
  String get boundAccounts;

  /// No description provided for @noAccounts.
  ///
  /// In zh, this message translates to:
  /// **'暂未绑定任何账号'**
  String get noAccounts;

  /// No description provided for @support.
  ///
  /// In zh, this message translates to:
  /// **'支持'**
  String get support;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @onboarding1Title.
  ///
  /// In zh, this message translates to:
  /// **'说就行'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'语音、文字、图片，想怎么说就怎么说。\n不用选模板，不用填表单。'**
  String get onboarding1Subtitle;

  /// No description provided for @onboarding2Title.
  ///
  /// In zh, this message translates to:
  /// **'AI 帮你执行'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'大模型理解你的意图，\nAgent Team 替你动手，你只管拍板。'**
  String get onboarding2Subtitle;

  /// No description provided for @onboarding3Title.
  ///
  /// In zh, this message translates to:
  /// **'随时看进展'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Subtitle.
  ///
  /// In zh, this message translates to:
  /// **'待拍板的事置顶提醒，\n执行中的事后台并行，\n结果直接可用。'**
  String get onboarding3Subtitle;

  /// No description provided for @skip.
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @getStarted.
  ///
  /// In zh, this message translates to:
  /// **'开始使用'**
  String get getStarted;

  /// No description provided for @understanding.
  ///
  /// In zh, this message translates to:
  /// **'我理解的是'**
  String get understanding;

  /// No description provided for @planSteps.
  ///
  /// In zh, this message translates to:
  /// **'我准备这样做'**
  String get planSteps;

  /// No description provided for @executing.
  ///
  /// In zh, this message translates to:
  /// **'执行中'**
  String get executing;

  /// No description provided for @completed.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completed;

  /// No description provided for @taskFailed.
  ///
  /// In zh, this message translates to:
  /// **'执行失败'**
  String get taskFailed;

  /// No description provided for @taskCancelled.
  ///
  /// In zh, this message translates to:
  /// **'任务已取消'**
  String get taskCancelled;

  /// No description provided for @confirmed.
  ///
  /// In zh, this message translates to:
  /// **'已确认'**
  String get confirmed;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @continueProcessing.
  ///
  /// In zh, this message translates to:
  /// **'继续处理'**
  String get continueProcessing;

  /// No description provided for @toDocument.
  ///
  /// In zh, this message translates to:
  /// **'转文档'**
  String get toDocument;

  /// No description provided for @setReminder.
  ///
  /// In zh, this message translates to:
  /// **'设提醒'**
  String get setReminder;

  /// No description provided for @moreInfo.
  ///
  /// In zh, this message translates to:
  /// **'补充信息'**
  String get moreInfo;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @allTasks.
  ///
  /// In zh, this message translates to:
  /// **'全部任务'**
  String get allTasks;

  /// No description provided for @pendingConfirm.
  ///
  /// In zh, this message translates to:
  /// **'待拍板'**
  String get pendingConfirm;

  /// No description provided for @executingTasks.
  ///
  /// In zh, this message translates to:
  /// **'执行中'**
  String get executingTasks;

  /// No description provided for @completedTasks.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get completedTasks;

  /// No description provided for @earlierTasks.
  ///
  /// In zh, this message translates to:
  /// **'更早'**
  String get earlierTasks;

  /// No description provided for @noTasks.
  ///
  /// In zh, this message translates to:
  /// **'还没有任务，说一句话开始'**
  String get noTasks;

  /// No description provided for @sendFailed.
  ///
  /// In zh, this message translates to:
  /// **'指令发送失败'**
  String get sendFailed;

  /// No description provided for @uploadFailed.
  ///
  /// In zh, this message translates to:
  /// **'上传失败'**
  String get uploadFailed;

  /// No description provided for @networkError.
  ///
  /// In zh, this message translates to:
  /// **'网络连接失败，请检查网络'**
  String get networkError;

  /// No description provided for @loginExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录'**
  String get loginExpired;

  /// No description provided for @deleteSession.
  ///
  /// In zh, this message translates to:
  /// **'删除会话'**
  String get deleteSession;

  /// No description provided for @deleteSessionConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除这个会话？'**
  String get deleteSessionConfirm;

  /// No description provided for @newSession.
  ///
  /// In zh, this message translates to:
  /// **'新会话'**
  String get newSession;

  /// No description provided for @scene1Title.
  ///
  /// In zh, this message translates to:
  /// **'写个方案'**
  String get scene1Title;

  /// No description provided for @scene1Desc.
  ///
  /// In zh, this message translates to:
  /// **'简报、邮件草稿、会议纪要'**
  String get scene1Desc;

  /// No description provided for @scene2Title.
  ///
  /// In zh, this message translates to:
  /// **'列个清单'**
  String get scene2Title;

  /// No description provided for @scene2Desc.
  ///
  /// In zh, this message translates to:
  /// **'把事情拆解成行动项'**
  String get scene2Desc;

  /// No description provided for @scene3Title.
  ///
  /// In zh, this message translates to:
  /// **'帮我想想'**
  String get scene3Title;

  /// No description provided for @scene3Desc.
  ///
  /// In zh, this message translates to:
  /// **'分析问题、给出建议'**
  String get scene3Desc;

  /// No description provided for @scene4Title.
  ///
  /// In zh, this message translates to:
  /// **'发封邮件'**
  String get scene4Title;

  /// No description provided for @scene4Desc.
  ///
  /// In zh, this message translates to:
  /// **'起草并发送邮件'**
  String get scene4Desc;

  /// No description provided for @tryFirstCommand.
  ///
  /// In zh, this message translates to:
  /// **'试试说一句话'**
  String get tryFirstCommand;

  /// No description provided for @tapSceneToStart.
  ///
  /// In zh, this message translates to:
  /// **'或者点击下方场景快速开始'**
  String get tapSceneToStart;

  /// No description provided for @commandSent.
  ///
  /// In zh, this message translates to:
  /// **'指令已发出，AI 正在处理…'**
  String get commandSent;

  /// No description provided for @uploading.
  ///
  /// In zh, this message translates to:
  /// **'上传中…'**
  String get uploading;

  /// No description provided for @taskNotFound.
  ///
  /// In zh, this message translates to:
  /// **'任务未找到'**
  String get taskNotFound;

  /// No description provided for @executionProgress.
  ///
  /// In zh, this message translates to:
  /// **'执行进展'**
  String get executionProgress;

  /// No description provided for @finalResult.
  ///
  /// In zh, this message translates to:
  /// **'最终结果'**
  String get finalResult;

  /// No description provided for @followUpHint.
  ///
  /// In zh, this message translates to:
  /// **'追问或补充…'**
  String get followUpHint;

  /// No description provided for @confirmExecution.
  ///
  /// In zh, this message translates to:
  /// **'确认执行'**
  String get confirmExecution;

  /// No description provided for @conversation.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get conversation;

  /// No description provided for @confirmExecuting.
  ///
  /// In zh, this message translates to:
  /// **'任务已确认，正在执行…'**
  String get confirmExecuting;

  /// No description provided for @cancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get cancelled;

  /// No description provided for @retrying.
  ///
  /// In zh, this message translates to:
  /// **'正在重试…'**
  String get retrying;

  /// No description provided for @retryingUnderstand.
  ///
  /// In zh, this message translates to:
  /// **'重新理解指令中…'**
  String get retryingUnderstand;

  /// No description provided for @followUpFailed.
  ///
  /// In zh, this message translates to:
  /// **'补充发送失败'**
  String get followUpFailed;

  /// No description provided for @confirmFailed.
  ///
  /// In zh, this message translates to:
  /// **'确认失败'**
  String get confirmFailed;

  /// No description provided for @cancelFailed.
  ///
  /// In zh, this message translates to:
  /// **'取消失败'**
  String get cancelFailed;

  /// No description provided for @retryFailed.
  ///
  /// In zh, this message translates to:
  /// **'重试失败'**
  String get retryFailed;

  /// No description provided for @pause.
  ///
  /// In zh, this message translates to:
  /// **'暂停'**
  String get pause;

  /// No description provided for @addAccount.
  ///
  /// In zh, this message translates to:
  /// **'添加账号'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In zh, this message translates to:
  /// **'编辑账号'**
  String get editAccount;

  /// No description provided for @wechatWorkWebhook.
  ///
  /// In zh, this message translates to:
  /// **'企业微信群机器人'**
  String get wechatWorkWebhook;

  /// No description provided for @wechatWorkWebhookHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴群机器人 Webhook URL'**
  String get wechatWorkWebhookHint;

  /// No description provided for @intlPhoneNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'国际号码暂不支持短信验证，请使用邮箱或 Apple 登录'**
  String get intlPhoneNotSupported;

  /// No description provided for @confirmDeleteAccount.
  ///
  /// In zh, this message translates to:
  /// **'确认注销'**
  String get confirmDeleteAccount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
