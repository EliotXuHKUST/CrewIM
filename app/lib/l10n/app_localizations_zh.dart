// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '知知';

  @override
  String get appSubtitle => 'AI 时代的管理者指挥台';

  @override
  String get goodMorning => '早上好';

  @override
  String get goodAfternoon => '下午好';

  @override
  String get goodEvening => '晚上好';

  @override
  String highlightCount(int count) {
    return '有 $count 件事需要你关注';
  }

  @override
  String get allGood => '一切顺利，没有需要你处理的事';

  @override
  String restSummary(int count) {
    return '其他 $count 件事正常推进中';
  }

  @override
  String todayCompleted(int count) {
    return '今日完成 $count 项';
  }

  @override
  String get viewAll => '查看全部';

  @override
  String get longRunning => '持续运行中';

  @override
  String get inputHint => '说点什么…';

  @override
  String get needsDecision => '需要你拍板';

  @override
  String get failed => '执行失败，需要处理';

  @override
  String get inProgress => '正在进行';

  @override
  String get takingLong => '执行时间较长，可能需要关注';

  @override
  String get paused => '已暂停，等待恢复';

  @override
  String get confirm => '确认';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get resume => '恢复';

  @override
  String get detail => '查看详情';

  @override
  String get delete => '删除';

  @override
  String get save => '保存';

  @override
  String get confirmAll => '全部确认';

  @override
  String get viewConversation => '查看对话';

  @override
  String get addNote => '补充一句…';

  @override
  String get login => '登录';

  @override
  String get signInWithApple => '通过 Apple 登录';

  @override
  String get signInWithGoogle => '通过 Google 登录';

  @override
  String get phoneLogin => '手机号登录';

  @override
  String get emailLogin => '邮箱登录';

  @override
  String get orLoginWith => '或';

  @override
  String get phone => '手机号';

  @override
  String get verificationCode => '验证码';

  @override
  String get getCode => '获取验证码';

  @override
  String countdownSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String get email => '邮箱地址';

  @override
  String get loginAgreement => '登录即表示同意《用户协议》和《隐私政策》';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get termsOfService => '用户协议';

  @override
  String get settings => '设置';

  @override
  String get account => '账号';

  @override
  String get phoneNumber => '手机号';

  @override
  String get logout => '退出登录';

  @override
  String get logoutConfirm => '确定退出当前账号？';

  @override
  String get deleteAccount => '注销账号';

  @override
  String get deleteAccountWarning => '注销后所有数据将被永久删除，包括会话记录、任务历史、绑定账号等。此操作不可撤销。';

  @override
  String get deleteAccountFinal => '真的要永久删除账号和所有数据吗？';

  @override
  String get permanentDelete => '永久删除';

  @override
  String get letMeThink => '我再想想';

  @override
  String get feedback => '意见反馈';

  @override
  String get feedbackHint => '请描述你遇到的问题或建议…';

  @override
  String get feedbackThanks => '感谢你的反馈！';

  @override
  String get submit => '提交';

  @override
  String get version => '版本';

  @override
  String get aiService => 'AI 服务';

  @override
  String get boundAccounts => '已绑定账号';

  @override
  String get noAccounts => '暂未绑定任何账号';

  @override
  String get support => '支持';

  @override
  String get about => '关于';

  @override
  String get onboarding1Title => '说就行';

  @override
  String get onboarding1Subtitle => '语音、文字、图片，想怎么说就怎么说。\n不用选模板，不用填表单。';

  @override
  String get onboarding2Title => 'AI 帮你执行';

  @override
  String get onboarding2Subtitle => '大模型理解你的意图，\nAgent Team 替你动手，你只管拍板。';

  @override
  String get onboarding3Title => '随时看进展';

  @override
  String get onboarding3Subtitle => '待拍板的事置顶提醒，\n执行中的事后台并行，\n结果直接可用。';

  @override
  String get skip => '跳过';

  @override
  String get next => '下一步';

  @override
  String get getStarted => '开始使用';

  @override
  String get understanding => '我理解的是';

  @override
  String get planSteps => '我准备这样做';

  @override
  String get executing => '执行中';

  @override
  String get completed => '已完成';

  @override
  String get taskFailed => '执行失败';

  @override
  String get taskCancelled => '任务已取消';

  @override
  String get confirmed => '已确认';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get continueProcessing => '继续处理';

  @override
  String get toDocument => '转文档';

  @override
  String get setReminder => '设提醒';

  @override
  String get moreInfo => '补充信息';

  @override
  String get search => '搜索';

  @override
  String get allTasks => '全部任务';

  @override
  String get pendingConfirm => '待拍板';

  @override
  String get executingTasks => '执行中';

  @override
  String get completedTasks => '已完成';

  @override
  String get earlierTasks => '更早';

  @override
  String get noTasks => '还没有任务，说一句话开始';

  @override
  String get sendFailed => '指令发送失败';

  @override
  String get uploadFailed => '上传失败';

  @override
  String get networkError => '网络连接失败，请检查网络';

  @override
  String get loginExpired => '登录已过期，请重新登录';

  @override
  String get deleteSession => '删除会话';

  @override
  String get deleteSessionConfirm => '确定删除这个会话？';

  @override
  String get newSession => '新会话';

  @override
  String get scene1Title => '写个方案';

  @override
  String get scene1Desc => '简报、邮件草稿、会议纪要';

  @override
  String get scene2Title => '列个清单';

  @override
  String get scene2Desc => '把事情拆解成行动项';

  @override
  String get scene3Title => '帮我想想';

  @override
  String get scene3Desc => '分析问题、给出建议';

  @override
  String get scene4Title => '发封邮件';

  @override
  String get scene4Desc => '起草并发送邮件';
}
