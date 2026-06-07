// THIS IS A GENERATED FILE, DO NOT EDIT.
// ALL YOUR CHANGES WILL BE DISCARDED.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<Locale> supportedLocales = <Locale>[Locale('zh'), Locale('en')];

  /// No description provided for @hello.
  ///
  /// In zh, this message translates to:
  /// **'你好'**
  String get hello;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'好的'**
  String get ok;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @appTitle.
  ///
  /// In zh, this message translates to:
  /// **'EVE Fit Assistant'**
  String get appTitle;

  /// No description provided for @edit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @showInfo.
  ///
  /// In zh, this message translates to:
  /// **'显示详情'**
  String get showInfo;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @share.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// No description provided for @dynamicConvert.
  ///
  /// In zh, this message translates to:
  /// **'深渊'**
  String get dynamicConvert;

  /// No description provided for @dynamicRevert.
  ///
  /// In zh, this message translates to:
  /// **'还原'**
  String get dynamicRevert;

  /// No description provided for @dynamicSelectTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择深渊物质'**
  String get dynamicSelectTitle;

  /// No description provided for @enable.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In zh, this message translates to:
  /// **'禁用'**
  String get disable;

  /// No description provided for @loading.
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// No description provided for @applyAfterRestart.
  ///
  /// In zh, this message translates to:
  /// **'重启应用程序后生效'**
  String get applyAfterRestart;

  /// No description provided for @useCategorySelectList.
  ///
  /// In zh, this message translates to:
  /// **'组别分类'**
  String get useCategorySelectList;

  /// No description provided for @useMarketGroupSelectList.
  ///
  /// In zh, this message translates to:
  /// **'市场组别分类'**
  String get useMarketGroupSelectList;

  /// No description provided for @typeListReturnBehaviorPreviousPage.
  ///
  /// In zh, this message translates to:
  /// **'返回上一级'**
  String get typeListReturnBehaviorPreviousPage;

  /// No description provided for @typeListReturnBehaviorExit.
  ///
  /// In zh, this message translates to:
  /// **'退出列表'**
  String get typeListReturnBehaviorExit;

  /// No description provided for @highSlot.
  ///
  /// In zh, this message translates to:
  /// **'高能量槽'**
  String get highSlot;

  /// No description provided for @midSlot.
  ///
  /// In zh, this message translates to:
  /// **'中能量槽'**
  String get midSlot;

  /// No description provided for @lowSlot.
  ///
  /// In zh, this message translates to:
  /// **'低能量槽'**
  String get lowSlot;

  /// No description provided for @rigSlot.
  ///
  /// In zh, this message translates to:
  /// **'改装件槽'**
  String get rigSlot;

  /// No description provided for @subsystemSlot.
  ///
  /// In zh, this message translates to:
  /// **'子系统'**
  String get subsystemSlot;

  /// No description provided for @implantSlot.
  ///
  /// In zh, this message translates to:
  /// **'植入体槽'**
  String get implantSlot;

  /// No description provided for @boosterSlot.
  ///
  /// In zh, this message translates to:
  /// **'增效剂槽'**
  String get boosterSlot;

  /// No description provided for @serviceSlot.
  ///
  /// In zh, this message translates to:
  /// **'服务设施槽'**
  String get serviceSlot;

  /// No description provided for @tacticalMode.
  ///
  /// In zh, this message translates to:
  /// **'战术模式'**
  String get tacticalMode;

  /// No description provided for @drone.
  ///
  /// In zh, this message translates to:
  /// **'无人机'**
  String get drone;

  /// No description provided for @fighter.
  ///
  /// In zh, this message translates to:
  /// **'铁骑舰载机'**
  String get fighter;

  /// No description provided for @charge.
  ///
  /// In zh, this message translates to:
  /// **'弹药'**
  String get charge;

  /// No description provided for @frontPageTitleWorkspace.
  ///
  /// In zh, this message translates to:
  /// **'工作台'**
  String get frontPageTitleWorkspace;

  /// No description provided for @frontPageTitleFitList.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get frontPageTitleFitList;

  /// No description provided for @frontPageTitleCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get frontPageTitleCharacter;

  /// No description provided for @frontPageTitleSetting.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get frontPageTitleSetting;

  /// No description provided for @characterBuiltInProfiles.
  ///
  /// In zh, this message translates to:
  /// **'内置档案'**
  String get characterBuiltInProfiles;

  /// No description provided for @characterCustomProfiles.
  ///
  /// In zh, this message translates to:
  /// **'自定义档案'**
  String get characterCustomProfiles;

  /// No description provided for @characterCreateProfile.
  ///
  /// In zh, this message translates to:
  /// **'创建档案'**
  String get characterCreateProfile;

  /// No description provided for @characterCreateProfileError.
  ///
  /// In zh, this message translates to:
  /// **'无法创建档案：{message}'**
  String characterCreateProfileError({required String message});

  /// No description provided for @characterNewProfileName.
  ///
  /// In zh, this message translates to:
  /// **'新角色'**
  String get characterNewProfileName;

  /// No description provided for @characterClonedProfileName.
  ///
  /// In zh, this message translates to:
  /// **'{name} 副本'**
  String characterClonedProfileName({required String name});

  /// No description provided for @characterCloneProfileError.
  ///
  /// In zh, this message translates to:
  /// **'无法复制 {name}：{message}'**
  String characterCloneProfileError({required String name, required String message});

  /// No description provided for @characterNoCustomProfiles.
  ///
  /// In zh, this message translates to:
  /// **'还没有自定义档案。可以先从全 5 创建一个本地技能档案。'**
  String get characterNoCustomProfiles;

  /// No description provided for @characterLastModified.
  ///
  /// In zh, this message translates to:
  /// **'修改于 {time}'**
  String characterLastModified({required String time});

  /// No description provided for @characterDeleteProfileTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除档案'**
  String get characterDeleteProfileTitle;

  /// No description provided for @characterDeleteProfileContent.
  ///
  /// In zh, this message translates to:
  /// **'删除 {name}？使用该档案的配置会保留档案 ID，直到你选择其他档案。'**
  String characterDeleteProfileContent({required String name});

  /// No description provided for @characterDeleteProfileError.
  ///
  /// In zh, this message translates to:
  /// **'无法删除 {name}：{message}'**
  String characterDeleteProfileError({required String name, required String message});

  /// No description provided for @characterProfileInfoTab.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get characterProfileInfoTab;

  /// No description provided for @characterProfileNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'角色名称'**
  String get characterProfileNameLabel;

  /// No description provided for @characterProfileDescriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get characterProfileDescriptionLabel;

  /// No description provided for @characterProfileNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入角色名称。'**
  String get characterProfileNameRequired;

  /// No description provided for @characterSkillAllGroups.
  ///
  /// In zh, this message translates to:
  /// **'全部技能组'**
  String get characterSkillAllGroups;

  /// No description provided for @workspaceTabActionCreateFitName.
  ///
  /// In zh, this message translates to:
  /// **'创建新配置'**
  String get workspaceTabActionCreateFitName;

  /// No description provided for @bundleAccessRequiredTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要数据包'**
  String get bundleAccessRequiredTitle;

  /// No description provided for @bundleAccessNotSelectedDescription.
  ///
  /// In zh, this message translates to:
  /// **'在选择活动数据包之前，无法创建或导入配置。'**
  String get bundleAccessNotSelectedDescription;

  /// No description provided for @bundleAccessLoadingDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前数据包仍在加载中。请等待加载完成后再试。'**
  String get bundleAccessLoadingDescription;

  /// No description provided for @bundleAccessInvalidDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前数据包不完整或无效。请先导入有效归档文件，或切换到其他数据包。'**
  String get bundleAccessInvalidDescription;

  /// No description provided for @bundleAccessReadyDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前活动数据包已就绪。'**
  String get bundleAccessReadyDescription;

  /// No description provided for @bundleAccessManageAction.
  ///
  /// In zh, this message translates to:
  /// **'打开数据包管理'**
  String get bundleAccessManageAction;

  /// No description provided for @startupPersistenceRepairSummary.
  ///
  /// In zh, this message translates to:
  /// **'已恢复本地存储：{details}。'**
  String startupPersistenceRepairSummary({required String details});

  /// No description provided for @startupPersistenceRepairSummaryWithWarnings.
  ///
  /// In zh, this message translates to:
  /// **'已恢复本地存储：{details}。仍有 {unreadableCount} 个配置文件需要手动清理。'**
  String startupPersistenceRepairSummaryWithWarnings({
    required String details,
    required int unreadableCount,
  });

  /// No description provided for @startupPersistenceRepairFoundUnreadableFits.
  ///
  /// In zh, this message translates to:
  /// **'发现了无法读取的配置文件'**
  String get startupPersistenceRepairFoundUnreadableFits;

  /// No description provided for @startupPersistenceRepairRebuiltMetadata.
  ///
  /// In zh, this message translates to:
  /// **'已重写本地元数据'**
  String get startupPersistenceRepairRebuiltMetadata;

  /// No description provided for @startupPersistenceRepairRemovedMissingFits.
  ///
  /// In zh, this message translates to:
  /// **'移除了 {count} 条缺失配置的记录'**
  String startupPersistenceRepairRemovedMissingFits({required int count});

  /// No description provided for @startupPersistenceRepairRestoredFits.
  ///
  /// In zh, this message translates to:
  /// **'恢复了 {count} 条已保存配置的记录'**
  String startupPersistenceRepairRestoredFits({required int count});

  /// No description provided for @startupPersistenceRepairRemovedMissingBundles.
  ///
  /// In zh, this message translates to:
  /// **'移除了 {count} 条缺失数据包的记录'**
  String startupPersistenceRepairRemovedMissingBundles({required int count});

  /// No description provided for @startupPersistenceRepairRestoredBundles.
  ///
  /// In zh, this message translates to:
  /// **'恢复了 {count} 个已安装数据包'**
  String startupPersistenceRepairRestoredBundles({required int count});

  /// No description provided for @startupPersistenceRepairUpdatedSelectedBundle.
  ///
  /// In zh, this message translates to:
  /// **'已更新当前选中的数据包'**
  String get startupPersistenceRepairUpdatedSelectedBundle;

  /// No description provided for @settingTileAppSettingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingTileAppSettingsTitle;

  /// No description provided for @settingTileRemoteContentTitle.
  ///
  /// In zh, this message translates to:
  /// **'远程内容'**
  String get settingTileRemoteContentTitle;

  /// No description provided for @settingTileBundleManagerTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包'**
  String get settingTileBundleManagerTitle;

  /// No description provided for @settingTileVersionTitle.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get settingTileVersionTitle;

  /// No description provided for @settingTileVersionSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'发布说明与更新日志'**
  String get settingTileVersionSubtitle;

  /// No description provided for @appSettingsPageSectionBundle.
  ///
  /// In zh, this message translates to:
  /// **'数据包'**
  String get appSettingsPageSectionBundle;

  /// No description provided for @appSettingsPageBundleImpactWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包影响警告'**
  String get appSettingsPageBundleImpactWarningTitle;

  /// No description provided for @appSettingsPageBundleImpactWarningDescription.
  ///
  /// In zh, this message translates to:
  /// **'当切换数据包或导入增量包可能影响已保存的配置或角色时显示警告。'**
  String get appSettingsPageBundleImpactWarningDescription;

  /// No description provided for @bundleImpactDisableConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭数据包影响警告？'**
  String get bundleImpactDisableConfirmTitle;

  /// No description provided for @bundleImpactDisableConfirmDescription.
  ///
  /// In zh, this message translates to:
  /// **'在重新启用此设置之前，数据包切换和增量包导入将不再显示影响警告。'**
  String get bundleImpactDisableConfirmDescription;

  /// No description provided for @bundleImpactWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'潜在数据包影响'**
  String get bundleImpactWarningTitle;

  /// No description provided for @bundleImpactSwitchWarningDescription.
  ///
  /// In zh, this message translates to:
  /// **'切换到数据包 {bundleId} 可能影响已保存的本地数据。'**
  String bundleImpactSwitchWarningDescription({required Object bundleId});

  /// No description provided for @bundleImpactIncrementalWarningDescription.
  ///
  /// In zh, this message translates to:
  /// **'导入数据包 {bundleId} 的增量补丁可能影响已保存的本地数据。'**
  String bundleImpactIncrementalWarningDescription({required Object bundleId});

  /// No description provided for @bundleImpactContinueAction.
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get bundleImpactContinueAction;

  /// No description provided for @bundleImpactFitsSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个配置会受到影响'**
  String bundleImpactFitsSummary({required Object count});

  /// No description provided for @bundleImpactCharactersSummary.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个角色会受到影响'**
  String bundleImpactCharactersSummary({required Object count});

  /// No description provided for @bundleImpactBundleDataSummary.
  ///
  /// In zh, this message translates to:
  /// **'数据包内容将被更新'**
  String get bundleImpactBundleDataSummary;

  /// No description provided for @bundleImpactDetailPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包影响'**
  String get bundleImpactDetailPageTitle;

  /// No description provided for @bundleImpactDetailDescription.
  ///
  /// In zh, this message translates to:
  /// **'使用数据包 {bundleId} 时的潜在影响。'**
  String bundleImpactDetailDescription({required Object bundleId});

  /// No description provided for @bundleImpactNoImpacts.
  ///
  /// In zh, this message translates to:
  /// **'未发现本地影响。'**
  String get bundleImpactNoImpacts;

  /// No description provided for @bundleImpactFitsSection.
  ///
  /// In zh, this message translates to:
  /// **'配置'**
  String get bundleImpactFitsSection;

  /// No description provided for @bundleImpactCharactersSection.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get bundleImpactCharactersSection;

  /// No description provided for @bundleImpactBundleDataSection.
  ///
  /// In zh, this message translates to:
  /// **'数据包内容'**
  String get bundleImpactBundleDataSection;

  /// No description provided for @bundleImpactSavedBundleLabel.
  ///
  /// In zh, this message translates to:
  /// **'保存时数据包：'**
  String get bundleImpactSavedBundleLabel;

  /// No description provided for @bundleImpactTargetBundleLabel.
  ///
  /// In zh, this message translates to:
  /// **'目标数据包：'**
  String get bundleImpactTargetBundleLabel;

  /// No description provided for @bundleImpactReasonLabel.
  ///
  /// In zh, this message translates to:
  /// **'原因：'**
  String get bundleImpactReasonLabel;

  /// No description provided for @bundleImpactReasonBundleMismatch.
  ///
  /// In zh, this message translates to:
  /// **'数据包 ID 不同'**
  String get bundleImpactReasonBundleMismatch;

  /// No description provided for @bundleImpactReasonMissingRevision.
  ///
  /// In zh, this message translates to:
  /// **'缺少可比较的版本元数据'**
  String get bundleImpactReasonMissingRevision;

  /// No description provided for @bundleImpactReasonManifestMismatch.
  ///
  /// In zh, this message translates to:
  /// **'Manifest 哈希不同'**
  String get bundleImpactReasonManifestMismatch;

  /// No description provided for @bundleImpactReasonGenerationMismatch.
  ///
  /// In zh, this message translates to:
  /// **'生成时间戳不同'**
  String get bundleImpactReasonGenerationMismatch;

  /// No description provided for @bundleImpactReasonBuildMismatch.
  ///
  /// In zh, this message translates to:
  /// **'游戏构建版本不同'**
  String get bundleImpactReasonBuildMismatch;

  /// No description provided for @bundleImpactReasonAppVersionMismatch.
  ///
  /// In zh, this message translates to:
  /// **'应用版本不同'**
  String get bundleImpactReasonAppVersionMismatch;

  /// No description provided for @bundleImpactReasonIncrementalPatch.
  ///
  /// In zh, this message translates to:
  /// **'增量补丁包含变更'**
  String get bundleImpactReasonIncrementalPatch;

  /// No description provided for @bundleImpactReasonFullReplacement.
  ///
  /// In zh, this message translates to:
  /// **'完整替换包包含变更'**
  String get bundleImpactReasonFullReplacement;

  /// No description provided for @workspaceTabAnnouncementTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新动态'**
  String get workspaceTabAnnouncementTitle;

  /// No description provided for @documentAnnouncementPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'更新动态'**
  String get documentAnnouncementPageTitle;

  /// No description provided for @documentVersionPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get documentVersionPageTitle;

  /// No description provided for @documentAnnouncementEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有更新内容'**
  String get documentAnnouncementEmptyTitle;

  /// No description provided for @documentVersionEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前没有版本说明'**
  String get documentVersionEmptyTitle;

  /// No description provided for @documentEmptyDescription.
  ///
  /// In zh, this message translates to:
  /// **'内置公告、信息说明和版本更新会显示在这里，后续在线更新仍可按来源单独区分。'**
  String get documentEmptyDescription;

  /// No description provided for @documentLoadErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'无法加载文档'**
  String get documentLoadErrorTitle;

  /// No description provided for @documentLoadErrorDescription.
  ///
  /// In zh, this message translates to:
  /// **'请稍后重试，或重新启动应用。'**
  String get documentLoadErrorDescription;

  /// No description provided for @documentSelectPrompt.
  ///
  /// In zh, this message translates to:
  /// **'请选择一条内容以查看详情。'**
  String get documentSelectPrompt;

  /// No description provided for @documentKindAnnouncement.
  ///
  /// In zh, this message translates to:
  /// **'公告'**
  String get documentKindAnnouncement;

  /// No description provided for @documentKindInformation.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get documentKindInformation;

  /// No description provided for @documentKindVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get documentKindVersion;

  /// No description provided for @documentOpenHint.
  ///
  /// In zh, this message translates to:
  /// **'点击查看'**
  String get documentOpenHint;

  /// No description provided for @documentVersionBadge.
  ///
  /// In zh, this message translates to:
  /// **'应用 {version}'**
  String documentVersionBadge({required String version});

  /// No description provided for @documentMarkAllRead.
  ///
  /// In zh, this message translates to:
  /// **'全部标为已读'**
  String get documentMarkAllRead;

  /// No description provided for @documentMarkAllUnread.
  ///
  /// In zh, this message translates to:
  /// **'全部标为未读'**
  String get documentMarkAllUnread;

  /// No description provided for @documentMinAppVerWarning.
  ///
  /// In zh, this message translates to:
  /// **'需要应用版本 {version} 或更高'**
  String documentMinAppVerWarning({required String version});

  /// No description provided for @versionBumpCardTitle.
  ///
  /// In zh, this message translates to:
  /// **'v{version} 更新内容'**
  String versionBumpCardTitle({required String version});

  /// No description provided for @versionBumpCardSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条新内容'**
  String versionBumpCardSubtitle({required int count});

  /// No description provided for @versionBumpCardCloseTooltip.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get versionBumpCardCloseTooltip;

  /// No description provided for @versionBumpCardSubtitleFallback.
  ///
  /// In zh, this message translates to:
  /// **'查看版本说明'**
  String get versionBumpCardSubtitleFallback;

  /// No description provided for @fitCreationPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建新配置'**
  String get fitCreationPageTitle;

  /// No description provided for @fitCreationPageDialogHint.
  ///
  /// In zh, this message translates to:
  /// **'新配置 {count}'**
  String fitCreationPageDialogHint({required int count});

  /// No description provided for @fitCreationPageDialogErrorText.
  ///
  /// In zh, this message translates to:
  /// **'请输入配置名。'**
  String get fitCreationPageDialogErrorText;

  /// No description provided for @fitCreationPageDialogDeleteFitTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除配置'**
  String get fitCreationPageDialogDeleteFitTitle;

  /// No description provided for @fitCreationPageDialogDeleteFitContent.
  ///
  /// In zh, this message translates to:
  /// **'您确定要删除配置 {fitName} 吗？'**
  String fitCreationPageDialogDeleteFitContent({required String fitName});

  /// No description provided for @fitPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'{fitName} - {shipName}'**
  String fitPageTitle({required String fitName, required String shipName});

  /// No description provided for @fitPageUnavailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置不可用'**
  String get fitPageUnavailableTitle;

  /// No description provided for @fitPageMissingMessage.
  ///
  /// In zh, this message translates to:
  /// **'找不到该配置。'**
  String get fitPageMissingMessage;

  /// No description provided for @fitPageBrokenMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法加载该配置。'**
  String get fitPageBrokenMessage;

  /// No description provided for @fitPageShipUnavailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'该配置引用了当前数据包中不可用的舰船数据。'**
  String get fitPageShipUnavailableMessage;

  /// No description provided for @fitBundleChangedTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包已变更'**
  String get fitBundleChangedTitle;

  /// No description provided for @fitBundleChangedDescription.
  ///
  /// In zh, this message translates to:
  /// **'该配置保存于当前活动数据包的旧版本。您仍可查看和导出该配置，但在重新导入兼容的数据包版本，或基于当前数据重新创建配置前，将保持只读。'**
  String get fitBundleChangedDescription;

  /// No description provided for @fitBundleLegacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要重新确认数据包'**
  String get fitBundleLegacyTitle;

  /// No description provided for @fitBundleLegacyDescription.
  ///
  /// In zh, this message translates to:
  /// **'该配置保存时尚未记录数据包版本信息。您仍可查看和导出该配置，但在使用兼容数据包重新打开，或基于当前数据包重新创建配置前，将保持只读。'**
  String get fitBundleLegacyDescription;

  /// No description provided for @fitBundleMismatchTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包不匹配'**
  String get fitBundleMismatchTitle;

  /// No description provided for @fitBundleMismatchDescription.
  ///
  /// In zh, this message translates to:
  /// **'该配置保存于数据包 {savedBundleId}，而当前活动数据包为 {activeBundleId}。您仍可查看和导出该配置，但编辑将保持禁用。'**
  String fitBundleMismatchDescription({
    required String savedBundleId,
    required String activeBundleId,
  });

  /// No description provided for @fitBundleMismatchSwitchDescription.
  ///
  /// In zh, this message translates to:
  /// **'该配置保存于数据包 {savedBundleId}，而当前活动数据包为 {activeBundleId}。如需直接编辑该配置，请切回 {savedBundleId}；如果您想在当前数据包下保留一个新的可编辑副本，请先确认当前数据差异，再导出并重新导入该配置。'**
  String fitBundleMismatchSwitchDescription({
    required String savedBundleId,
    required String activeBundleId,
  });

  /// No description provided for @fitBundleMismatchImportDescription.
  ///
  /// In zh, this message translates to:
  /// **'该配置保存于数据包 {savedBundleId}，而当前活动数据包为 {activeBundleId}。如需直接编辑该配置，请先重新导入数据包 {savedBundleId}；如果您想迁移到当前数据包，请导出后在当前数据包下重新导入。'**
  String fitBundleMismatchImportDescription({
    required String savedBundleId,
    required String activeBundleId,
  });

  /// No description provided for @fitBundleSwitchLabel.
  ///
  /// In zh, this message translates to:
  /// **'切换数据包后编辑'**
  String get fitBundleSwitchLabel;

  /// No description provided for @fitBundleImportLabel.
  ///
  /// In zh, this message translates to:
  /// **'重新导入数据包数据'**
  String get fitBundleImportLabel;

  /// No description provided for @fitBundleSwitchAction.
  ///
  /// In zh, this message translates to:
  /// **'切换数据包'**
  String get fitBundleSwitchAction;

  /// No description provided for @fitBundleSwitchErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'无法切换数据包。将保留当前数据包。'**
  String get fitBundleSwitchErrorMessage;

  /// No description provided for @fitBundleOpenManagerAction.
  ///
  /// In zh, this message translates to:
  /// **'打开数据包管理'**
  String get fitBundleOpenManagerAction;

  /// No description provided for @fitBundleUnavailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包不可用'**
  String get fitBundleUnavailableTitle;

  /// No description provided for @fitBundleUnavailableDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前没有活动数据包，无法确认兼容性。在数据包可用前，该配置将保持只读。'**
  String get fitBundleUnavailableDescription;

  /// No description provided for @fitBundleUnavailableSwitchDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前没有活动数据包。请选择 {savedBundleId} 后再编辑该配置；如果您暂时不想切换应用的数据上下文，也可以继续只读查看。'**
  String fitBundleUnavailableSwitchDescription({required String savedBundleId});

  /// No description provided for @fitBundleUnavailableImportDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前没有活动数据包，且该配置对应的已保存数据包尚未安装。请先在数据包管理中导入所需数据，再进行编辑；或者基于当前可用数据包重新创建配置。'**
  String get fitBundleUnavailableImportDescription;

  /// No description provided for @fitPageStatsUnavailableTitle.
  ///
  /// In zh, this message translates to:
  /// **'属性不可用'**
  String get fitPageStatsUnavailableTitle;

  /// No description provided for @fitPageStatsUnavailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'在计算恢复期间，您仍然可以查看和编辑该配置。'**
  String get fitPageStatsUnavailableMessage;

  /// No description provided for @fitPageSaveErrorTitle.
  ///
  /// In zh, this message translates to:
  /// **'更改未保存'**
  String get fitPageSaveErrorTitle;

  /// No description provided for @fitPageSaveErrorMessage.
  ///
  /// In zh, this message translates to:
  /// **'最新的配置更改无法保存。'**
  String get fitPageSaveErrorMessage;

  /// No description provided for @fitPageReadOnlyMessage.
  ///
  /// In zh, this message translates to:
  /// **'在启用兼容的数据包之前，该配置将保持只读。'**
  String get fitPageReadOnlyMessage;

  /// No description provided for @fitPageRetryAction.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get fitPageRetryAction;

  /// No description provided for @fitPageBackAction.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get fitPageBackAction;

  /// No description provided for @fitIssueDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置问题'**
  String get fitIssueDialogTitle;

  /// No description provided for @fitIssueMissingDynamic.
  ///
  /// In zh, this message translates to:
  /// **'{slotName} #{index} 引用了缺失的动态物品数据。'**
  String fitIssueMissingDynamic({required String slotName, required int index});

  /// No description provided for @fitIssueMissingItemType.
  ///
  /// In zh, this message translates to:
  /// **'{slotName} #{index} 引用了当前不可用的物品数据。'**
  String fitIssueMissingItemType({required String slotName, required int index});

  /// No description provided for @fitIssueMissingChargeType.
  ///
  /// In zh, this message translates to:
  /// **'{slotName} #{index} 引用了当前不可用的弹药数据。'**
  String fitIssueMissingChargeType({required String slotName, required int index});

  /// No description provided for @fitIssueIncompatibleChargeSize.
  ///
  /// In zh, this message translates to:
  /// **'弹药尺寸不匹配。'**
  String get fitIssueIncompatibleChargeSize;

  /// No description provided for @fitIssueIncompatibleChargeSizeDetails.
  ///
  /// In zh, this message translates to:
  /// **'期望尺寸：{expected}；实际尺寸：{actual}。'**
  String fitIssueIncompatibleChargeSizeDetails({required String expected, required String actual});

  /// No description provided for @fitIssueIncompatibleChargeCapacity.
  ///
  /// In zh, this message translates to:
  /// **'弹药体积超过装备容量。'**
  String get fitIssueIncompatibleChargeCapacity;

  /// No description provided for @fitIssueIncompatibleChargeCapacityDetails.
  ///
  /// In zh, this message translates to:
  /// **'最大容量：{max} m³；实际体积：{actual} m³。'**
  String fitIssueIncompatibleChargeCapacityDetails({required String max, required String actual});

  /// No description provided for @fitIssueIncompatibleChargeGroup.
  ///
  /// In zh, this message translates to:
  /// **'该装备不接受此弹药类型。'**
  String get fitIssueIncompatibleChargeGroup;

  /// No description provided for @fitIssueIncompatibleChargeGroupDetails.
  ///
  /// In zh, this message translates to:
  /// **'期望弹药分组：{expected}；实际分组：{actual}。'**
  String fitIssueIncompatibleChargeGroupDetails({required String expected, required String actual});

  /// No description provided for @fitIssueTooMuchTurret.
  ///
  /// In zh, this message translates to:
  /// **'炮台数量过多。'**
  String get fitIssueTooMuchTurret;

  /// No description provided for @fitIssueTooMuchTurretDetails.
  ///
  /// In zh, this message translates to:
  /// **'最大数量：{expected}；实际数量：{actual}。'**
  String fitIssueTooMuchTurretDetails({required int expected, required int actual});

  /// No description provided for @fitIssueTooMuchLauncher.
  ///
  /// In zh, this message translates to:
  /// **'发射器数量过多。'**
  String get fitIssueTooMuchLauncher;

  /// No description provided for @fitIssueTooMuchLauncherDetails.
  ///
  /// In zh, this message translates to:
  /// **'最大数量：{expected}；实际数量：{actual}。'**
  String fitIssueTooMuchLauncherDetails({required int expected, required int actual});

  /// No description provided for @fitIssueConflictItem.
  ///
  /// In zh, this message translates to:
  /// **'主动装备冲突。'**
  String get fitIssueConflictItem;

  /// No description provided for @fitIssueConflictItemDetails.
  ///
  /// In zh, this message translates to:
  /// **'物品组 {groupName} 中启用了多个受限制装备。'**
  String fitIssueConflictItemDetails({required String groupName});

  /// No description provided for @fitIssueDuplicateBooster.
  ///
  /// In zh, this message translates to:
  /// **'增效剂槽位重复。'**
  String get fitIssueDuplicateBooster;

  /// No description provided for @fitIssueDuplicateBoosterDetails.
  ///
  /// In zh, this message translates to:
  /// **'增效剂槽位 {slot} 已被占用。'**
  String fitIssueDuplicateBoosterDetails({required int slot});

  /// No description provided for @fitIssueIncompatibleShipGroup.
  ///
  /// In zh, this message translates to:
  /// **'物品无法安装到该舰船分组。'**
  String get fitIssueIncompatibleShipGroup;

  /// No description provided for @fitIssueIncompatibleShipGroupDetails.
  ///
  /// In zh, this message translates to:
  /// **'期望舰船分组：{expected}。'**
  String fitIssueIncompatibleShipGroupDetails({required String expected});

  /// No description provided for @fitIssueIncompatibleShipType.
  ///
  /// In zh, this message translates to:
  /// **'物品无法安装到该舰船类型。'**
  String get fitIssueIncompatibleShipType;

  /// No description provided for @fitIssueIncompatibleShipTypeDetails.
  ///
  /// In zh, this message translates to:
  /// **'期望舰船类型：{expected}。'**
  String fitIssueIncompatibleShipTypeDetails({required String expected});

  /// No description provided for @fitIssueIncompatibleRigSize.
  ///
  /// In zh, this message translates to:
  /// **'改装件尺寸不匹配。'**
  String get fitIssueIncompatibleRigSize;

  /// No description provided for @fitIssueIncompatibleRigSizeDetails.
  ///
  /// In zh, this message translates to:
  /// **'期望尺寸：{expected}；实际尺寸：{actual}。'**
  String fitIssueIncompatibleRigSizeDetails({required String expected, required String actual});

  /// No description provided for @fitIssueMissingCharge.
  ///
  /// In zh, this message translates to:
  /// **'缺少弹药。'**
  String get fitIssueMissingCharge;

  /// No description provided for @fitIssueUnknownValidationIssue.
  ///
  /// In zh, this message translates to:
  /// **'未知配置校验问题。'**
  String get fitIssueUnknownValidationIssue;

  /// No description provided for @fitTabsCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get fitTabsCharacter;

  /// No description provided for @fitTabsEquipment.
  ///
  /// In zh, this message translates to:
  /// **'装备'**
  String get fitTabsEquipment;

  /// No description provided for @fitTabsAttributes.
  ///
  /// In zh, this message translates to:
  /// **'属性'**
  String get fitTabsAttributes;

  /// No description provided for @fitTabsDrone.
  ///
  /// In zh, this message translates to:
  /// **'无人机'**
  String get fitTabsDrone;

  /// No description provided for @fitTabsFighter.
  ///
  /// In zh, this message translates to:
  /// **'舰载机'**
  String get fitTabsFighter;

  /// No description provided for @fitTabsUtils.
  ///
  /// In zh, this message translates to:
  /// **'杂项'**
  String get fitTabsUtils;

  /// No description provided for @fitSkillPolicyPresetTitle.
  ///
  /// In zh, this message translates to:
  /// **'技能档案：{profileName}'**
  String fitSkillPolicyPresetTitle({required String profileName});

  /// No description provided for @fitSkillPolicyPresetDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前构建使用预设技能档案，而不是真实角色数据。'**
  String get fitSkillPolicyPresetDescription;

  /// No description provided for @fitSkillProfileAll5.
  ///
  /// In zh, this message translates to:
  /// **'全 5'**
  String get fitSkillProfileAll5;

  /// No description provided for @fitSkillProfileAlphaMax.
  ///
  /// In zh, this message translates to:
  /// **'Alpha 最高'**
  String get fitSkillProfileAlphaMax;

  /// No description provided for @fitSkillProfileAll0.
  ///
  /// In zh, this message translates to:
  /// **'全 0'**
  String get fitSkillProfileAll0;

  /// No description provided for @fitSkillPolicyUnsupportedTitle.
  ///
  /// In zh, this message translates to:
  /// **'当前构建暂不支持技能感知模拟。'**
  String get fitSkillPolicyUnsupportedTitle;

  /// No description provided for @fitSkillPolicyUnsupportedDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前配置模拟不会应用角色技能修正。植入体和增效剂仍然生效。'**
  String get fitSkillPolicyUnsupportedDescription;

  /// No description provided for @fitAddItemDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加物品：{slotName}'**
  String fitAddItemDialogTitle({required String slotName});

  /// No description provided for @fitAddItemDialogTitleWithIndex.
  ///
  /// In zh, this message translates to:
  /// **'添加物品：{slotName} #{index}'**
  String fitAddItemDialogTitleWithIndex({required String slotName, required int index});

  /// No description provided for @fitSlotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'{slotName}（空）'**
  String fitSlotEmpty({required String slotName});

  /// No description provided for @fitActionFill.
  ///
  /// In zh, this message translates to:
  /// **'补满'**
  String get fitActionFill;

  /// No description provided for @fitActionSet.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get fitActionSet;

  /// No description provided for @fitUnknownImplantAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的植入体不可用'**
  String fitUnknownImplantAtSlot({required int slot});

  /// No description provided for @fitUnknownImplant.
  ///
  /// In zh, this message translates to:
  /// **'植入体不可用（{typeId}）'**
  String fitUnknownImplant({required int typeId});

  /// No description provided for @fitUnknownBoosterAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的增效剂不可用'**
  String fitUnknownBoosterAtSlot({required int slot});

  /// No description provided for @fitUnknownBooster.
  ///
  /// In zh, this message translates to:
  /// **'增效剂不可用（{typeId}）'**
  String fitUnknownBooster({required int typeId});

  /// No description provided for @fitUnknownItemAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的物品数据不可用'**
  String fitUnknownItemAtSlot({required int slot});

  /// No description provided for @fitUnknownItemWithIdAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的物品数据不可用（{itemId}）'**
  String fitUnknownItemWithIdAtSlot({required int itemId, required int slot});

  /// No description provided for @fitUnknownFighterAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的舰载机数据不可用'**
  String fitUnknownFighterAtSlot({required int slot});

  /// No description provided for @fitUnknownFighterWithIdAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的舰载机数据不可用（{itemId}）'**
  String fitUnknownFighterWithIdAtSlot({required int itemId, required int slot});

  /// No description provided for @fitUnknownShip.
  ///
  /// In zh, this message translates to:
  /// **'舰船数据不可用（{typeId}）'**
  String fitUnknownShip({required int typeId});

  /// No description provided for @fitUnknownSubsystemAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的子系统数据不可用'**
  String fitUnknownSubsystemAtSlot({required int slot});

  /// No description provided for @fitUnknownSubsystemWithIdAtSlot.
  ///
  /// In zh, this message translates to:
  /// **'槽位 {slot} 的子系统数据不可用（{itemId}）'**
  String fitUnknownSubsystemWithIdAtSlot({required int itemId, required int slot});

  /// No description provided for @fitUnknownTacticalMode.
  ///
  /// In zh, this message translates to:
  /// **'战术模式数据不可用（{typeId}）'**
  String fitUnknownTacticalMode({required int typeId});

  /// No description provided for @fitUtilsNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入配置名。'**
  String get fitUtilsNameRequired;

  /// No description provided for @fitUtilsExportButton.
  ///
  /// In zh, this message translates to:
  /// **'导出配置'**
  String get fitUtilsExportButton;

  /// No description provided for @fitUtilsExportImageButton.
  ///
  /// In zh, this message translates to:
  /// **'导出图片'**
  String get fitUtilsExportImageButton;

  /// No description provided for @fitUtilsNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置名称'**
  String get fitUtilsNameLabel;

  /// No description provided for @fitUtilsDescriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置备注'**
  String get fitUtilsDescriptionLabel;

  /// No description provided for @fitExportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'导出配置'**
  String get fitExportDialogTitle;

  /// No description provided for @fitExportLoadError.
  ///
  /// In zh, this message translates to:
  /// **'无法加载该配置用于导出。'**
  String get fitExportLoadError;

  /// No description provided for @fitExportFormatNative.
  ///
  /// In zh, this message translates to:
  /// **'EFA 原生编码'**
  String get fitExportFormatNative;

  /// No description provided for @fitExportFormatNativeDescription.
  ///
  /// In zh, this message translates to:
  /// **'完整保留配置细节的导出格式，适合在另一台 EVE Fit Assistant 设备上导入。'**
  String get fitExportFormatNativeDescription;

  /// No description provided for @fitExportFormatFittingLink.
  ///
  /// In zh, this message translates to:
  /// **'游戏内装配链接'**
  String get fitExportFormatFittingLink;

  /// No description provided for @fitExportFormatFittingLinkDescription.
  ///
  /// In zh, this message translates to:
  /// **'复制可粘贴到 EVE 的装配链接。游戏支持的模块、弹药、无人机和舰载机信息会被保留。'**
  String get fitExportFormatFittingLinkDescription;

  /// No description provided for @fitExportFormatEft.
  ///
  /// In zh, this message translates to:
  /// **'EFT 文本'**
  String get fitExportFormatEft;

  /// No description provided for @fitExportFormatEftDescription.
  ///
  /// In zh, this message translates to:
  /// **'复制可用于 pyfa 等第三方工具的 EFT 文本格式。'**
  String get fitExportFormatEftDescription;

  /// No description provided for @fitExportLossyWarning.
  ///
  /// In zh, this message translates to:
  /// **'该导出格式会丢失部分配置细节。'**
  String get fitExportLossyWarning;

  /// No description provided for @fitExportCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制配置导出内容。'**
  String get fitExportCopied;

  /// No description provided for @fitExportClipboardError.
  ///
  /// In zh, this message translates to:
  /// **'当前无法复制该配置导出内容。'**
  String get fitExportClipboardError;

  /// No description provided for @fitExportShareError.
  ///
  /// In zh, this message translates to:
  /// **'当前无法分享该配置导出内容。'**
  String get fitExportShareError;

  /// No description provided for @fitListActionExport.
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get fitListActionExport;

  /// No description provided for @fitListActionImport.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get fitListActionImport;

  /// No description provided for @fitImportDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入配置'**
  String get fitImportDialogTitle;

  /// No description provided for @fitImportDialogDescription.
  ///
  /// In zh, this message translates to:
  /// **'请在下方粘贴配置文本。当前导入流程支持 EFA 原生编码和 EFT 文本。'**
  String get fitImportDialogDescription;

  /// No description provided for @fitImportInputLabel.
  ///
  /// In zh, this message translates to:
  /// **'配置文本'**
  String get fitImportInputLabel;

  /// No description provided for @fitImportPasteButton.
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get fitImportPasteButton;

  /// No description provided for @fitImportConfirmButton.
  ///
  /// In zh, this message translates to:
  /// **'导入'**
  String get fitImportConfirmButton;

  /// No description provided for @fitImportErrorEmpty.
  ///
  /// In zh, this message translates to:
  /// **'请先粘贴配置文本再导入。'**
  String get fitImportErrorEmpty;

  /// No description provided for @fitImportErrorUnsupportedFormat.
  ///
  /// In zh, this message translates to:
  /// **'该文本不是当前支持的配置导入格式。'**
  String get fitImportErrorUnsupportedFormat;

  /// No description provided for @fitImportErrorUnsupportedFittingLink.
  ///
  /// In zh, this message translates to:
  /// **'当前测试版本暂不支持导入游戏内装配链接。'**
  String get fitImportErrorUnsupportedFittingLink;

  /// No description provided for @fitImportErrorUnsupportedNativeVersion.
  ///
  /// In zh, this message translates to:
  /// **'该 EFA 导出内容来自较新的应用版本，当前版本暂时无法导入。'**
  String get fitImportErrorUnsupportedNativeVersion;

  /// No description provided for @fitImportErrorInvalidNativePayload.
  ///
  /// In zh, this message translates to:
  /// **'该 EFA 导出内容已损坏或不完整。'**
  String get fitImportErrorInvalidNativePayload;

  /// No description provided for @fitImportErrorInvalidEft.
  ///
  /// In zh, this message translates to:
  /// **'该 EFT 文本无效，或包含当前测试版本暂不支持的段落。'**
  String get fitImportErrorInvalidEft;

  /// No description provided for @fitImportErrorUnknownType.
  ///
  /// In zh, this message translates to:
  /// **'当前数据包无法识别“{typeName}”。'**
  String fitImportErrorUnknownType({required String typeName});

  /// No description provided for @fitImportErrorUnavailableShip.
  ///
  /// In zh, this message translates to:
  /// **'当前数据包中没有舰船“{shipName}”。'**
  String fitImportErrorUnavailableShip({required String shipName});

  /// No description provided for @fitImportErrorUnavailableData.
  ///
  /// In zh, this message translates to:
  /// **'导入所需的数据暂未就绪。请等待应用完成数据包加载后再试。'**
  String get fitImportErrorUnavailableData;

  /// No description provided for @fitImportSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已导入 {fitName}'**
  String fitImportSuccess({required String fitName});

  /// No description provided for @fitImportUnknownError.
  ///
  /// In zh, this message translates to:
  /// **'无法导入该配置。'**
  String get fitImportUnknownError;

  /// No description provided for @fitScreenshotPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'配置图片导出'**
  String get fitScreenshotPageTitle;

  /// No description provided for @fitScreenshotSave.
  ///
  /// In zh, this message translates to:
  /// **'保存图片'**
  String get fitScreenshotSave;

  /// No description provided for @fitScreenshotShare.
  ///
  /// In zh, this message translates to:
  /// **'分享图片'**
  String get fitScreenshotShare;

  /// No description provided for @fitScreenshotSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存截图到 {path}'**
  String fitScreenshotSaved({required String path});

  /// No description provided for @fitScreenshotDamageProfile.
  ///
  /// In zh, this message translates to:
  /// **'伤害分布'**
  String get fitScreenshotDamageProfile;

  /// No description provided for @fitScreenshotEquipment.
  ///
  /// In zh, this message translates to:
  /// **'装备'**
  String get fitScreenshotEquipment;

  /// No description provided for @fitScreenshotSupport.
  ///
  /// In zh, this message translates to:
  /// **'植入体与增效剂'**
  String get fitScreenshotSupport;

  /// No description provided for @fitScreenshotMinions.
  ///
  /// In zh, this message translates to:
  /// **'无人机与舰载机'**
  String get fitScreenshotMinions;

  /// No description provided for @fitScreenshotStats.
  ///
  /// In zh, this message translates to:
  /// **'快速属性'**
  String get fitScreenshotStats;

  /// No description provided for @fitScreenshotEmpty.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get fitScreenshotEmpty;

  /// No description provided for @fitScreenshotStatsUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'属性不可用'**
  String get fitScreenshotStatsUnavailable;

  /// No description provided for @fitScreenshotFighterCapacity.
  ///
  /// In zh, this message translates to:
  /// **'舰载机容量'**
  String get fitScreenshotFighterCapacity;

  /// No description provided for @fitScreenshotShieldHp.
  ///
  /// In zh, this message translates to:
  /// **'护盾 HP'**
  String get fitScreenshotShieldHp;

  /// No description provided for @fitScreenshotArmorHp.
  ///
  /// In zh, this message translates to:
  /// **'装甲 HP'**
  String get fitScreenshotArmorHp;

  /// No description provided for @fitScreenshotHullHp.
  ///
  /// In zh, this message translates to:
  /// **'结构 HP'**
  String get fitScreenshotHullHp;

  /// No description provided for @fitScreenshotCapacitor.
  ///
  /// In zh, this message translates to:
  /// **'电容'**
  String get fitScreenshotCapacitor;

  /// No description provided for @fitScreenshotDroneBandwidth.
  ///
  /// In zh, this message translates to:
  /// **'无人机带宽'**
  String get fitScreenshotDroneBandwidth;

  /// No description provided for @fitAttributeTabCapacitorStable.
  ///
  /// In zh, this message translates to:
  /// **'{percent}% 稳定'**
  String fitAttributeTabCapacitorStable({required String percent});

  /// No description provided for @fitFighterAbilityTurret.
  ///
  /// In zh, this message translates to:
  /// **'炮塔'**
  String get fitFighterAbilityTurret;

  /// No description provided for @fitFighterAbilityMissiles.
  ///
  /// In zh, this message translates to:
  /// **'导弹'**
  String get fitFighterAbilityMissiles;

  /// No description provided for @fitFighterAbilityVolley.
  ///
  /// In zh, this message translates to:
  /// **'齐射'**
  String get fitFighterAbilityVolley;

  /// No description provided for @fitFighterAbilityBomb.
  ///
  /// In zh, this message translates to:
  /// **'炸弹'**
  String get fitFighterAbilityBomb;

  /// No description provided for @fitDroneTabAddDroneTitle.
  ///
  /// In zh, this message translates to:
  /// **'添加无人机'**
  String get fitDroneTabAddDroneTitle;

  /// No description provided for @appSettingsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'应用设置'**
  String get appSettingsPageTitle;

  /// No description provided for @appSettingsPageSectionGeneral.
  ///
  /// In zh, this message translates to:
  /// **'常规'**
  String get appSettingsPageSectionGeneral;

  /// No description provided for @appSettingsPageLocaleTitle.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get appSettingsPageLocaleTitle;

  /// No description provided for @appSettingsPageLocaleSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'选择应用语言'**
  String get appSettingsPageLocaleSubtitle;

  /// No description provided for @appSettingsPageFontScaleTitle.
  ///
  /// In zh, this message translates to:
  /// **'字体缩放'**
  String get appSettingsPageFontScaleTitle;

  /// No description provided for @appSettingsPageFontScaleDescription.
  ///
  /// In zh, this message translates to:
  /// **'调整应用文字缩放比例，更改立即生效。'**
  String get appSettingsPageFontScaleDescription;

  /// No description provided for @appSettingsPageFontScaleXS.
  ///
  /// In zh, this message translates to:
  /// **'特小'**
  String get appSettingsPageFontScaleXS;

  /// No description provided for @appSettingsPageFontScaleS.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get appSettingsPageFontScaleS;

  /// No description provided for @appSettingsPageFontScaleM.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get appSettingsPageFontScaleM;

  /// No description provided for @appSettingsPageFontScaleL.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get appSettingsPageFontScaleL;

  /// No description provided for @appSettingsPageFontScaleXL.
  ///
  /// In zh, this message translates to:
  /// **'特大'**
  String get appSettingsPageFontScaleXL;

  /// No description provided for @appSettingsPageSectionSelectList.
  ///
  /// In zh, this message translates to:
  /// **'展示列表格式'**
  String get appSettingsPageSectionSelectList;

  /// No description provided for @appSettingsPageShipSelectTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'舰船选择列表格式'**
  String get appSettingsPageShipSelectTypeTitle;

  /// No description provided for @appSettingsPageShipSelectTypeDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择舰船时使用的列表格式。\n按组别分类会按照游戏中的物品组进行分类。\n按市场组别分类会按照市场中的分组进行分类。'**
  String get appSettingsPageShipSelectTypeDescription;

  /// No description provided for @appSettingsPageListReturnBehaviorTitle.
  ///
  /// In zh, this message translates to:
  /// **'列表返回行为'**
  String get appSettingsPageListReturnBehaviorTitle;

  /// No description provided for @appSettingsPageListReturnBehaviorDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择在嵌套选择列表中触发系统返回时的行为。返回上一级会先回到上一个列表层级，然后再关闭列表；退出列表会直接关闭选择器。'**
  String get appSettingsPageListReturnBehaviorDescription;

  /// No description provided for @appSettingsPageSectionRemoteContent.
  ///
  /// In zh, this message translates to:
  /// **'远程内容'**
  String get appSettingsPageSectionRemoteContent;

  /// No description provided for @appSettingsPageRemoteContentPanelVisibleTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示远程内容设置'**
  String get appSettingsPageRemoteContentPanelVisibleTitle;

  /// No description provided for @appSettingsPageRemoteContentVisibleTitle.
  ///
  /// In zh, this message translates to:
  /// **'显示远程内容入口'**
  String get appSettingsPageRemoteContentVisibleTitle;

  /// No description provided for @appSettingsPageRemoteContentVisibleDescription.
  ///
  /// In zh, this message translates to:
  /// **'在设置页显示或隐藏远程内容入口。'**
  String get appSettingsPageRemoteContentVisibleDescription;

  /// No description provided for @appSettingsPageRemoteContentOpenTitle.
  ///
  /// In zh, this message translates to:
  /// **'打开远程内容设置'**
  String get appSettingsPageRemoteContentOpenTitle;

  /// No description provided for @appSettingsPageRemoteContentOpenDescription.
  ///
  /// In zh, this message translates to:
  /// **'配置远程内容运行时参数。'**
  String get appSettingsPageRemoteContentOpenDescription;

  /// No description provided for @appSettingsPageRemoteContentWarningTitle.
  ///
  /// In zh, this message translates to:
  /// **'要打开远程内容设置吗？'**
  String get appSettingsPageRemoteContentWarningTitle;

  /// No description provided for @appSettingsPageRemoteContentWarningDescription.
  ///
  /// In zh, this message translates to:
  /// **'远程内容设置仍处于实验阶段，可能影响后续文档、版本和数据包元数据发现。仅在确认要使用的端点时继续。'**
  String get appSettingsPageRemoteContentWarningDescription;

  /// No description provided for @appSettingsPageRemoteContentEnabledTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用远程内容'**
  String get appSettingsPageRemoteContentEnabledTitle;

  /// No description provided for @appSettingsPageRemoteContentEnabledDescription.
  ///
  /// In zh, this message translates to:
  /// **'当运行时同步可用时，允许应用从配置的远程源发现文档、版本和数据包元数据。'**
  String get appSettingsPageRemoteContentEnabledDescription;

  /// No description provided for @appSettingsPageRemoteContentEndpointTitle.
  ///
  /// In zh, this message translates to:
  /// **'远程内容端点'**
  String get appSettingsPageRemoteContentEndpointTitle;

  /// No description provided for @appSettingsPageRemoteContentEndpointDescription.
  ///
  /// In zh, this message translates to:
  /// **'源：{origin}\n根路径：{resourceRoot}\n频道：{channel}'**
  String appSettingsPageRemoteContentEndpointDescription({
    required String origin,
    required String resourceRoot,
    required String channel,
  });

  /// No description provided for @appSettingsPageRemoteContentNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get appSettingsPageRemoteContentNotSet;

  /// No description provided for @appSettingsPageRemoteContentOriginUrlLabel.
  ///
  /// In zh, this message translates to:
  /// **'源 URL'**
  String get appSettingsPageRemoteContentOriginUrlLabel;

  /// No description provided for @appSettingsPageRemoteContentResourceRootLabel.
  ///
  /// In zh, this message translates to:
  /// **'资源根路径'**
  String get appSettingsPageRemoteContentResourceRootLabel;

  /// No description provided for @appSettingsPageRemoteContentChannelLabel.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get appSettingsPageRemoteContentChannelLabel;

  /// No description provided for @appSettingsPageRemoteContentChannelTesting.
  ///
  /// In zh, this message translates to:
  /// **'测试版'**
  String get appSettingsPageRemoteContentChannelTesting;

  /// No description provided for @appSettingsPageRemoteContentChannelStable.
  ///
  /// In zh, this message translates to:
  /// **'稳定版'**
  String get appSettingsPageRemoteContentChannelStable;

  /// No description provided for @appSettingsPageCollectLogsEntryTitle.
  ///
  /// In zh, this message translates to:
  /// **'收集日志'**
  String get appSettingsPageCollectLogsEntryTitle;

  /// No description provided for @appSettingsPageCollectLogsEntryDescription.
  ///
  /// In zh, this message translates to:
  /// **'选择和分享应用日志以进行调试和问题报告'**
  String get appSettingsPageCollectLogsEntryDescription;

  /// No description provided for @collectLogsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'收集日志'**
  String get collectLogsPageTitle;

  /// No description provided for @collectLogsQuickFilter.
  ///
  /// In zh, this message translates to:
  /// **'快速筛选'**
  String get collectLogsQuickFilter;

  /// No description provided for @collectLogsFilterAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get collectLogsFilterAll;

  /// No description provided for @collectLogsFilter1Hour.
  ///
  /// In zh, this message translates to:
  /// **'1小时'**
  String get collectLogsFilter1Hour;

  /// No description provided for @collectLogsFilter24Hours.
  ///
  /// In zh, this message translates to:
  /// **'24小时'**
  String get collectLogsFilter24Hours;

  /// No description provided for @collectLogsFilter7Days.
  ///
  /// In zh, this message translates to:
  /// **'7天'**
  String get collectLogsFilter7Days;

  /// No description provided for @collectLogsFilter30Days.
  ///
  /// In zh, this message translates to:
  /// **'30天'**
  String get collectLogsFilter30Days;

  /// No description provided for @collectLogsFileActive.
  ///
  /// In zh, this message translates to:
  /// **'(当前)'**
  String get collectLogsFileActive;

  /// No description provided for @collectLogsNoLogFiles.
  ///
  /// In zh, this message translates to:
  /// **'未找到日志文件'**
  String get collectLogsNoLogFiles;

  /// No description provided for @collectLogsShareButton.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get collectLogsShareButton;

  /// No description provided for @collectLogsTotalSize.
  ///
  /// In zh, this message translates to:
  /// **'{size}，共 {count} 个文件'**
  String collectLogsTotalSize({required String size, required int count});

  /// No description provided for @collectLogsLoadError.
  ///
  /// In zh, this message translates to:
  /// **'加载日志文件失败'**
  String get collectLogsLoadError;

  /// No description provided for @appSettingsPageSectionDeveloper.
  ///
  /// In zh, this message translates to:
  /// **'开发者选项'**
  String get appSettingsPageSectionDeveloper;

  /// No description provided for @appSettingsPageDebugLogTitle.
  ///
  /// In zh, this message translates to:
  /// **'启用调试日志'**
  String get appSettingsPageDebugLogTitle;

  /// No description provided for @appSettingsPageDebugLogDescription.
  ///
  /// In zh, this message translates to:
  /// **'启用调试日志后，应用将会输出所有日志到日志目录中。\n建议仅当开发者要求开启此功能时才开启。'**
  String get appSettingsPageDebugLogDescription;

  /// No description provided for @bundleManagerPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包管理'**
  String get bundleManagerPageTitle;

  /// No description provided for @bundleImportOverwriteTitle.
  ///
  /// In zh, this message translates to:
  /// **'要替换现有数据包吗？'**
  String get bundleImportOverwriteTitle;

  /// No description provided for @bundleManagerBundleAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'打包应用版本：'**
  String get bundleManagerBundleAppVersion;

  /// No description provided for @bundleManagerBundleBuild.
  ///
  /// In zh, this message translates to:
  /// **'构建版本：'**
  String get bundleManagerBundleBuild;

  /// No description provided for @bundleManagerBundleGameVersion.
  ///
  /// In zh, this message translates to:
  /// **'游戏版本：'**
  String get bundleManagerBundleGameVersion;

  /// No description provided for @bundleManagerBundleServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器：'**
  String get bundleManagerBundleServer;

  /// No description provided for @bundleManagerBundleRegion.
  ///
  /// In zh, this message translates to:
  /// **'服务地区：'**
  String get bundleManagerBundleRegion;

  /// No description provided for @bundleManagerBundleBranch.
  ///
  /// In zh, this message translates to:
  /// **'游戏分支：'**
  String get bundleManagerBundleBranch;

  /// No description provided for @bundleManagerBundleSchemaVersion.
  ///
  /// In zh, this message translates to:
  /// **'架构 v{num}'**
  String bundleManagerBundleSchemaVersion({required int num});

  /// No description provided for @bundleManagerDeleteBundleConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除数据包'**
  String get bundleManagerDeleteBundleConfirmTitle;

  /// No description provided for @bundleManagerDeleteBundleConfirmContent.
  ///
  /// In zh, this message translates to:
  /// **'您确定要删除数据包 {bundleId} 吗？'**
  String bundleManagerDeleteBundleConfirmContent({required String bundleId});

  /// No description provided for @bundleManagerDeleteBundleInUseWarning.
  ///
  /// In zh, this message translates to:
  /// **'该数据包正在被使用，删除后可能导致某些功能无法正常工作。'**
  String get bundleManagerDeleteBundleInUseWarning;

  /// No description provided for @bundleManagerDetailPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包详情'**
  String get bundleManagerDetailPageTitle;

  /// No description provided for @bundleManagerDetailSectionTitleLatestPatch.
  ///
  /// In zh, this message translates to:
  /// **'最新补丁'**
  String get bundleManagerDetailSectionTitleLatestPatch;

  /// No description provided for @bundleManagerDetailSectionTitleHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史版本'**
  String get bundleManagerDetailSectionTitleHistory;

  /// No description provided for @bundleManagerDetailVariantFull.
  ///
  /// In zh, this message translates to:
  /// **'完整'**
  String get bundleManagerDetailVariantFull;

  /// No description provided for @bundleManagerDetailVariantIncremental.
  ///
  /// In zh, this message translates to:
  /// **'增量'**
  String get bundleManagerDetailVariantIncremental;

  /// No description provided for @bundleManagerDetailGeneratedAt.
  ///
  /// In zh, this message translates to:
  /// **'生成时间：'**
  String get bundleManagerDetailGeneratedAt;

  /// No description provided for @bundleManagerDetailLoadedAt.
  ///
  /// In zh, this message translates to:
  /// **'加载时间：'**
  String get bundleManagerDetailLoadedAt;

  /// No description provided for @bundleVerificationTitle.
  ///
  /// In zh, this message translates to:
  /// **'完整性校验'**
  String get bundleVerificationTitle;

  /// No description provided for @bundleVerificationAction.
  ///
  /// In zh, this message translates to:
  /// **'校验已安装文件'**
  String get bundleVerificationAction;

  /// No description provided for @bundleVerificationConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'要校验已安装的数据包文件吗？'**
  String get bundleVerificationConfirmTitle;

  /// No description provided for @bundleVerificationConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'此操作会读取已安装的数据包文件，并根据本地清单比较文件大小和 SHA-256 哈希。大型数据包可能需要一些时间。不会修改任何文件。'**
  String get bundleVerificationConfirmMessage;

  /// No description provided for @bundleVerificationValid.
  ///
  /// In zh, this message translates to:
  /// **'已安装文件与本地清单一致。'**
  String get bundleVerificationValid;

  /// No description provided for @bundleVerificationWarning.
  ///
  /// In zh, this message translates to:
  /// **'校验完成，但存在警告。'**
  String get bundleVerificationWarning;

  /// No description provided for @bundleVerificationInvalid.
  ///
  /// In zh, this message translates to:
  /// **'校验发现数据包完整性问题。'**
  String get bundleVerificationInvalid;

  /// No description provided for @bundleVerificationNeverRun.
  ///
  /// In zh, this message translates to:
  /// **'尚未执行校验。'**
  String get bundleVerificationNeverRun;

  /// No description provided for @bundleVerificationCheckedAt.
  ///
  /// In zh, this message translates to:
  /// **'校验时间：{time}'**
  String bundleVerificationCheckedAt({required String time});

  /// No description provided for @bundleVerificationMissingFiles.
  ///
  /// In zh, this message translates to:
  /// **'缺失：{count}'**
  String bundleVerificationMissingFiles({required int count});

  /// No description provided for @bundleVerificationHashMismatches.
  ///
  /// In zh, this message translates to:
  /// **'哈希不匹配：{count}'**
  String bundleVerificationHashMismatches({required int count});

  /// No description provided for @bundleVerificationSizeMismatches.
  ///
  /// In zh, this message translates to:
  /// **'大小不匹配：{count}'**
  String bundleVerificationSizeMismatches({required int count});

  /// No description provided for @bundleVerificationExtraFiles.
  ///
  /// In zh, this message translates to:
  /// **'额外文件：{count}'**
  String bundleVerificationExtraFiles({required int count});

  /// No description provided for @bundleVerificationMoreIssues.
  ///
  /// In zh, this message translates to:
  /// **'另有 {count} 个问题'**
  String bundleVerificationMoreIssues({required int count});

  /// No description provided for @bundleVerificationRemoteRepairUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'在可用的远程数据包元数据实现前，暂不支持远程修复。'**
  String get bundleVerificationRemoteRepairUnavailable;

  /// No description provided for @bundleVerificationIssueMissingManifest.
  ///
  /// In zh, this message translates to:
  /// **'缺少清单：{path}'**
  String bundleVerificationIssueMissingManifest({required String path});

  /// No description provided for @bundleVerificationIssueInvalidManifest.
  ///
  /// In zh, this message translates to:
  /// **'清单无效 {path}：{error}'**
  String bundleVerificationIssueInvalidManifest({required String path, required String error});

  /// No description provided for @bundleVerificationIssueManifestHashMissing.
  ///
  /// In zh, this message translates to:
  /// **'安装记录中没有最新清单哈希。'**
  String get bundleVerificationIssueManifestHashMissing;

  /// No description provided for @bundleVerificationIssueManifestHashMismatch.
  ///
  /// In zh, this message translates to:
  /// **'清单哈希不匹配：应为 {expected}，实际为 {actual}'**
  String bundleVerificationIssueManifestHashMismatch({
    required String expected,
    required String actual,
  });

  /// No description provided for @bundleVerificationIssueUnsafeManifestPath.
  ///
  /// In zh, this message translates to:
  /// **'清单路径不安全：{path}'**
  String bundleVerificationIssueUnsafeManifestPath({required String path});

  /// No description provided for @bundleVerificationIssueMissingFile.
  ///
  /// In zh, this message translates to:
  /// **'缺少文件：{path}'**
  String bundleVerificationIssueMissingFile({required String path});

  /// No description provided for @bundleVerificationIssueSizeMismatch.
  ///
  /// In zh, this message translates to:
  /// **'文件大小不匹配 {path}：应为 {expected}，实际为 {actual}'**
  String bundleVerificationIssueSizeMismatch({
    required String path,
    required int expected,
    required int actual,
  });

  /// No description provided for @bundleVerificationIssueHashMismatch.
  ///
  /// In zh, this message translates to:
  /// **'文件哈希不匹配 {path}：应为 {expected}，实际为 {actual}'**
  String bundleVerificationIssueHashMismatch({
    required String path,
    required String expected,
    required String actual,
  });

  /// No description provided for @bundleVerificationIssueExtraFile.
  ///
  /// In zh, this message translates to:
  /// **'额外文件：{path}'**
  String bundleVerificationIssueExtraFile({required String path});

  /// No description provided for @bundleVerificationIssueReadError.
  ///
  /// In zh, this message translates to:
  /// **'读取失败 {path}：{error}'**
  String bundleVerificationIssueReadError({required String path, required String error});

  /// No description provided for @bundleVerificationIssueUnsupportedSchemaVersion.
  ///
  /// In zh, this message translates to:
  /// **'数据包架构 v{version} 不受支持（支持版本: v{min}–v{max})。'**
  String bundleVerificationIssueUnsupportedSchemaVersion({
    required int version,
    required int min,
    required int max,
  });

  /// No description provided for @bundleVerificationIssueSchemaVersionMismatch.
  ///
  /// In zh, this message translates to:
  /// **'数据包架构 v{version} 与当前应用架构 v{current} 不同。'**
  String bundleVerificationIssueSchemaVersionMismatch({required int version, required int current});

  /// No description provided for @bundleManagerSetupTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入第一个数据包'**
  String get bundleManagerSetupTitle;

  /// No description provided for @bundleManagerSetupDescription.
  ///
  /// In zh, this message translates to:
  /// **'装配和相关功能需要先加载一个有效的数据包。请先导入数据包归档文件。'**
  String get bundleManagerSetupDescription;

  /// No description provided for @bundleManagerAlphaScope.
  ///
  /// In zh, this message translates to:
  /// **'Alpha 范围：应用可以安装多个数据包，但全局同一时间只会启用一个活动数据包。'**
  String get bundleManagerAlphaScope;

  /// No description provided for @bundleManagerImportSelectionBehavior.
  ///
  /// In zh, this message translates to:
  /// **'导入数据包时会保留当前活动数据包。只有在您确实想切换应用数据上下文时，才需要在下方选择其他已安装数据包。'**
  String get bundleManagerImportSelectionBehavior;

  /// No description provided for @bundleManagerSelectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择活动数据包'**
  String get bundleManagerSelectionTitle;

  /// No description provided for @bundleManagerSelectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'请从下方已安装的数据包中选择一个，或重新导入新的归档文件来恢复数据。'**
  String get bundleManagerSelectionDescription;

  /// No description provided for @bundleManagerLoadingTitle.
  ///
  /// In zh, this message translates to:
  /// **'正在加载数据包'**
  String get bundleManagerLoadingTitle;

  /// No description provided for @bundleManagerLoadingDescription.
  ///
  /// In zh, this message translates to:
  /// **'正在准备数据包 {bundleId}。'**
  String bundleManagerLoadingDescription({required String bundleId});

  /// No description provided for @bundleManagerInvalidTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包需要处理'**
  String get bundleManagerInvalidTitle;

  /// No description provided for @bundleManagerInvalidDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前选中的数据包缺少必要文件或元数据。请导入有效归档，或切换到其他已安装的数据包。'**
  String get bundleManagerInvalidDescription;

  /// No description provided for @bundleManagerReadyTitle.
  ///
  /// In zh, this message translates to:
  /// **'数据包可用'**
  String get bundleManagerReadyTitle;

  /// No description provided for @bundleManagerReadyDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前活动数据包：{bundleId}'**
  String bundleManagerReadyDescription({required String bundleId});

  /// No description provided for @bundleManagerImportAction.
  ///
  /// In zh, this message translates to:
  /// **'导入数据包'**
  String get bundleManagerImportAction;

  /// No description provided for @bundleRemoteSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'远程数据包'**
  String get bundleRemoteSectionTitle;

  /// No description provided for @bundleRemoteSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'从已配置的远程内容端点发现兼容的数据包归档。只有在您选择后才会开始下载。'**
  String get bundleRemoteSectionDescription;

  /// No description provided for @bundleRemoteRefreshAction.
  ///
  /// In zh, this message translates to:
  /// **'刷新远程数据包'**
  String get bundleRemoteRefreshAction;

  /// No description provided for @bundleRemoteEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的兼容远程数据包。'**
  String get bundleRemoteEmpty;

  /// No description provided for @bundleRemoteChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查远程数据包目录……'**
  String get bundleRemoteChecking;

  /// No description provided for @bundleRemoteCatalogMissing.
  ///
  /// In zh, this message translates to:
  /// **'远程索引未在此频道提供数据包目录。'**
  String get bundleRemoteCatalogMissing;

  /// No description provided for @bundleRemoteCatalogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'远程数据包目录为空。'**
  String get bundleRemoteCatalogEmpty;

  /// No description provided for @bundleRemoteAlternativesOnly.
  ///
  /// In zh, this message translates to:
  /// **'存在可用的远程数据包，但当前安装状态下没有首选项。请先检查备选项再下载。'**
  String get bundleRemoteAlternativesOnly;

  /// No description provided for @bundleRemoteCurrent.
  ///
  /// In zh, this message translates to:
  /// **'已安装的数据包已经匹配最新兼容的远程产物。'**
  String get bundleRemoteCurrent;

  /// No description provided for @bundleRemoteNoImportable.
  ///
  /// In zh, this message translates to:
  /// **'已找到远程数据包元数据，但当前设备暂时没有可导入的产物。'**
  String get bundleRemoteNoImportable;

  /// No description provided for @bundleRemoteReviewAction.
  ///
  /// In zh, this message translates to:
  /// **'检查数据包'**
  String get bundleRemoteReviewAction;

  /// No description provided for @bundleRemoteDownloadRecommendedAction.
  ///
  /// In zh, this message translates to:
  /// **'下载推荐项'**
  String get bundleRemoteDownloadRecommendedAction;

  /// No description provided for @bundleRemoteSelectionPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'远程数据包'**
  String get bundleRemoteSelectionPageTitle;

  /// No description provided for @bundleRemoteDisabled.
  ///
  /// In zh, this message translates to:
  /// **'远程内容已禁用。请先在远程内容设置中启用，再检查远程数据包。'**
  String get bundleRemoteDisabled;

  /// No description provided for @bundleRemoteRecommendedCount.
  ///
  /// In zh, this message translates to:
  /// **'推荐：{count}'**
  String bundleRemoteRecommendedCount({required int count});

  /// No description provided for @bundleRemoteAvailableCount.
  ///
  /// In zh, this message translates to:
  /// **'可用：{count}'**
  String bundleRemoteAvailableCount({required int count});

  /// No description provided for @bundleRemoteInstalledCount.
  ///
  /// In zh, this message translates to:
  /// **'已安装：{count}'**
  String bundleRemoteInstalledCount({required int count});

  /// No description provided for @bundleRemoteUnavailableCount.
  ///
  /// In zh, this message translates to:
  /// **'不可用：{count}'**
  String bundleRemoteUnavailableCount({required int count});

  /// No description provided for @bundleRemoteRecommendedSection.
  ///
  /// In zh, this message translates to:
  /// **'推荐'**
  String get bundleRemoteRecommendedSection;

  /// No description provided for @bundleRemoteRecommendedSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'根据已安装清单元数据，为已安装数据包选择最佳后续下载。同一数据包的较旧产物会保留为备选项。'**
  String get bundleRemoteRecommendedSectionDescription;

  /// No description provided for @bundleRemoteAvailableSection.
  ///
  /// In zh, this message translates to:
  /// **'可用备选'**
  String get bundleRemoteAvailableSection;

  /// No description provided for @bundleRemoteAvailableSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'可导入但不是首选推荐的完整数据包或补丁。'**
  String get bundleRemoteAvailableSectionDescription;

  /// No description provided for @bundleRemoteInstalledSection.
  ///
  /// In zh, this message translates to:
  /// **'已安装'**
  String get bundleRemoteInstalledSection;

  /// No description provided for @bundleRemoteInstalledSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'与已安装数据包清单匹配的远程产物。'**
  String get bundleRemoteInstalledSectionDescription;

  /// No description provided for @bundleRemoteUnavailableSection.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get bundleRemoteUnavailableSection;

  /// No description provided for @bundleRemoteUnavailableSectionDescription.
  ///
  /// In zh, this message translates to:
  /// **'由于应用版本或本地基线元数据不匹配，当前无法导入的产物。'**
  String get bundleRemoteUnavailableSectionDescription;

  /// No description provided for @bundleRemoteSelectionSummaryTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择建议'**
  String get bundleRemoteSelectionSummaryTitle;

  /// No description provided for @bundleRemoteSelectionSummaryDescription.
  ///
  /// In zh, this message translates to:
  /// **'当增量补丁匹配已安装基线清单时，会优先推荐增量补丁。完整数据包仍可手动用于新安装或替换安装。'**
  String get bundleRemoteSelectionSummaryDescription;

  /// No description provided for @bundleRemoteRecommendationIncremental.
  ///
  /// In zh, this message translates to:
  /// **'推荐为 {bundleId} 使用增量更新。'**
  String bundleRemoteRecommendationIncremental({required String bundleId});

  /// No description provided for @bundleRemoteRecommendationFullInstall.
  ///
  /// In zh, this message translates to:
  /// **'推荐完整安装数据包：{bundleId}。'**
  String bundleRemoteRecommendationFullInstall({required String bundleId});

  /// No description provided for @bundleRemoteRecommendationFullReplacement.
  ///
  /// In zh, this message translates to:
  /// **'当前没有匹配的增量路径；请使用 {bundleId} 的完整替换包。'**
  String bundleRemoteRecommendationFullReplacement({required String bundleId});

  /// No description provided for @bundleRemoteRecommendedFallback.
  ///
  /// In zh, this message translates to:
  /// **'推荐的远程数据包。'**
  String get bundleRemoteRecommendedFallback;

  /// No description provided for @bundleRemoteAvailableDescription.
  ///
  /// In zh, this message translates to:
  /// **'此产物可以下载并导入。'**
  String get bundleRemoteAvailableDescription;

  /// No description provided for @bundleRemoteInstalledDescription.
  ///
  /// In zh, this message translates to:
  /// **'此产物已存在于已安装数据包历史中。'**
  String get bundleRemoteInstalledDescription;

  /// No description provided for @bundleRemoteUnknownAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get bundleRemoteUnknownAppVersion;

  /// No description provided for @bundleRemoteUnavailableAppVersion.
  ///
  /// In zh, this message translates to:
  /// **'需要应用版本 {requiredVersion}；当前应用为 {currentVersion}。'**
  String bundleRemoteUnavailableAppVersion({
    required String requiredVersion,
    required String currentVersion,
  });

  /// No description provided for @bundleRemoteUnavailableIncompatibleSchema.
  ///
  /// In zh, this message translates to:
  /// **'数据包架构 v{version} 不被当前应用版本支持。'**
  String bundleRemoteUnavailableIncompatibleSchema({required int version});

  /// No description provided for @bundleRemoteUnavailableMissingIncrementalMetadata.
  ///
  /// In zh, this message translates to:
  /// **'增量产物缺少基线数据包元数据。'**
  String get bundleRemoteUnavailableMissingIncrementalMetadata;

  /// No description provided for @bundleRemoteUnavailableBaseNotInstalled.
  ///
  /// In zh, this message translates to:
  /// **'请先安装基线数据包 {bundleId}，再应用此增量补丁。'**
  String bundleRemoteUnavailableBaseNotInstalled({required String bundleId});

  /// No description provided for @bundleRemoteUnavailableInstalledManifestMissing.
  ///
  /// In zh, this message translates to:
  /// **'已安装数据包元数据没有记录清单哈希。'**
  String get bundleRemoteUnavailableInstalledManifestMissing;

  /// No description provided for @bundleRemoteUnavailableBaseManifestMismatch.
  ///
  /// In zh, this message translates to:
  /// **'已安装清单与此增量补丁基线不匹配。请改用完整数据包。'**
  String get bundleRemoteUnavailableBaseManifestMismatch;

  /// No description provided for @bundleRemoteUnavailableUnknown.
  ///
  /// In zh, this message translates to:
  /// **'此产物当前无法导入。'**
  String get bundleRemoteUnavailableUnknown;

  /// No description provided for @bundleRemoteError.
  ///
  /// In zh, this message translates to:
  /// **'远程数据包发现失败：{message}'**
  String bundleRemoteError({required String message});

  /// No description provided for @bundleRemoteArtifactDescription.
  ///
  /// In zh, this message translates to:
  /// **'{variant}数据包 {bundleId} · 构建 {gameBuild} · {gameServer}'**
  String bundleRemoteArtifactDescription({
    required String variant,
    required String bundleId,
    required String gameBuild,
    required String gameServer,
  });

  /// No description provided for @bundleRemoteDownloadAction.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get bundleRemoteDownloadAction;

  /// No description provided for @bundleRemoteDownloadImportAction.
  ///
  /// In zh, this message translates to:
  /// **'下载并导入'**
  String get bundleRemoteDownloadImportAction;

  /// No description provided for @bundleRemoteImportBehaviorHint.
  ///
  /// In zh, this message translates to:
  /// **'将导入为已安装数据包。活动数据包会保持不变，直到您在下方手动选择。'**
  String get bundleRemoteImportBehaviorHint;

  /// No description provided for @bundleRemoteArtifactSize.
  ///
  /// In zh, this message translates to:
  /// **'大小：{size}'**
  String bundleRemoteArtifactSize({required String size});

  /// No description provided for @bundleRemoteArtifactGenerated.
  ///
  /// In zh, this message translates to:
  /// **'生成时间：{time}'**
  String bundleRemoteArtifactGenerated({required String time});

  /// No description provided for @bundleRemoteArtifactBaseBundle.
  ///
  /// In zh, this message translates to:
  /// **'修补已安装基线：{bundleId}'**
  String bundleRemoteArtifactBaseBundle({required String bundleId});

  /// No description provided for @bundleRemoteArtifactBaseManifest.
  ///
  /// In zh, this message translates to:
  /// **'基线清单：{hash}'**
  String bundleRemoteArtifactBaseManifest({required String hash});

  /// No description provided for @bundleRemoteSchemaVersionWarning.
  ///
  /// In zh, this message translates to:
  /// **'架构 v{version} — 可能与当前应用架构不同'**
  String bundleRemoteSchemaVersionWarning({required int version});

  /// No description provided for @bundleRemoteProgressPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备远程请求'**
  String get bundleRemoteProgressPreparing;

  /// No description provided for @bundleRemoteProgressDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在下载归档'**
  String get bundleRemoteProgressDownloading;

  /// No description provided for @bundleRemoteProgressVerifying.
  ///
  /// In zh, this message translates to:
  /// **'正在校验大小和 SHA-256'**
  String get bundleRemoteProgressVerifying;

  /// No description provided for @bundleRemoteProgressUnpacking.
  ///
  /// In zh, this message translates to:
  /// **'正在解包归档'**
  String get bundleRemoteProgressUnpacking;

  /// No description provided for @bundleRemoteProgressImporting.
  ///
  /// In zh, this message translates to:
  /// **'正在导入数据包文件'**
  String get bundleRemoteProgressImporting;

  /// No description provided for @bundleRemoteProgressApplyingIncrementalPatch.
  ///
  /// In zh, this message translates to:
  /// **'正在应用增量补丁'**
  String get bundleRemoteProgressApplyingIncrementalPatch;

  /// No description provided for @bundleRemoteProgressRefreshingRegistry.
  ///
  /// In zh, this message translates to:
  /// **'正在刷新已安装数据包列表'**
  String get bundleRemoteProgressRefreshingRegistry;

  /// No description provided for @bundleRemoteProgressCompleted.
  ///
  /// In zh, this message translates to:
  /// **'已导入，未激活'**
  String get bundleRemoteProgressCompleted;

  /// No description provided for @bundleRemoteProgressCancelled.
  ///
  /// In zh, this message translates to:
  /// **'导入已取消'**
  String get bundleRemoteProgressCancelled;

  /// No description provided for @bundleRemoteProgressQueued.
  ///
  /// In zh, this message translates to:
  /// **'等待开始'**
  String get bundleRemoteProgressQueued;

  /// No description provided for @bundleRemoteProgressDownloadingKnown.
  ///
  /// In zh, this message translates to:
  /// **'{received} / {total}（{percent}%）'**
  String bundleRemoteProgressDownloadingKnown({
    required String received,
    required String total,
    required String percent,
  });

  /// No description provided for @bundleRemoteProgressDownloadingUnknown.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {received}'**
  String bundleRemoteProgressDownloadingUnknown({required String received});

  /// No description provided for @bundleRemoteProgressCompletedDescription.
  ///
  /// In zh, this message translates to:
  /// **'{bundleId} 已安装。需要切换应用活动数据时，请手动选择它。'**
  String bundleRemoteProgressCompletedDescription({required String bundleId});

  /// No description provided for @bundleRemoteProgressCancelledDescription.
  ///
  /// In zh, this message translates to:
  /// **'当前数据包保持不变。'**
  String get bundleRemoteProgressCancelledDescription;

  /// No description provided for @bundleRemoteProgressFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'导入失败'**
  String get bundleRemoteProgressFailedTitle;

  /// No description provided for @bundleRemoteProgressFailedDescription.
  ///
  /// In zh, this message translates to:
  /// **'在“{stage}”阶段失败：{message}'**
  String bundleRemoteProgressFailedDescription({required String stage, required String message});

  /// No description provided for @bundleRemoteProgressRetryAction.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get bundleRemoteProgressRetryAction;

  /// No description provided for @bundleRemoteProgressKeepCurrentAction.
  ///
  /// In zh, this message translates to:
  /// **'保留当前数据包'**
  String get bundleRemoteProgressKeepCurrentAction;

  /// No description provided for @bundleRemoteProgressViewInstalledAction.
  ///
  /// In zh, this message translates to:
  /// **'查看已安装数据包'**
  String get bundleRemoteProgressViewInstalledAction;

  /// No description provided for @bundleRemoteProgressLoadBundleAction.
  ///
  /// In zh, this message translates to:
  /// **'加载此数据包'**
  String get bundleRemoteProgressLoadBundleAction;

  /// No description provided for @bundleRemoteImportConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'要下载远程数据包吗？'**
  String get bundleRemoteImportConfirmTitle;

  /// No description provided for @bundleRemoteImportConfirmDescription.
  ///
  /// In zh, this message translates to:
  /// **'下载、校验并导入 {artifactId}？当前活动数据包不会自动切换。'**
  String bundleRemoteImportConfirmDescription({required String artifactId});

  /// No description provided for @bundleRemoteImportSucceeded.
  ///
  /// In zh, this message translates to:
  /// **'远程数据包已导入。'**
  String get bundleRemoteImportSucceeded;

  /// No description provided for @bundleRemoteImportFailed.
  ///
  /// In zh, this message translates to:
  /// **'远程数据包导入失败：{message}'**
  String bundleRemoteImportFailed({required String message});

  /// No description provided for @bundleManagerErrorMissingPath.
  ///
  /// In zh, this message translates to:
  /// **'缺少必要路径：{path}'**
  String bundleManagerErrorMissingPath({required String path});

  /// No description provided for @bundleManagerErrorExpectFile.
  ///
  /// In zh, this message translates to:
  /// **'该位置应为文件：{fileName}'**
  String bundleManagerErrorExpectFile({required String fileName});

  /// No description provided for @bundleManagerErrorExpectDirectory.
  ///
  /// In zh, this message translates to:
  /// **'该位置应为目录：{dirName}'**
  String bundleManagerErrorExpectDirectory({required String dirName});

  /// No description provided for @bundleManagerErrorBadDescriptor.
  ///
  /// In zh, this message translates to:
  /// **'无法读取数据包元数据。'**
  String get bundleManagerErrorBadDescriptor;

  /// No description provided for @bundleManagerErrorBadPatch.
  ///
  /// In zh, this message translates to:
  /// **'数据包历史记录无效：{reason}'**
  String bundleManagerErrorBadPatch({required String reason});

  /// No description provided for @bundleManagerDetailUnavailableMessage.
  ///
  /// In zh, this message translates to:
  /// **'在修复或重新导入数据包元数据之前，无法显示该数据包详情。'**
  String get bundleManagerDetailUnavailableMessage;

  /// No description provided for @fallbackTypeUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'物品数据不可用（{typeId}）'**
  String fallbackTypeUnavailable({required int typeId});

  /// No description provided for @fallbackGroupUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'组数据不可用（{groupId}）'**
  String fallbackGroupUnavailable({required int groupId});

  /// No description provided for @fallbackCategoryUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'分类数据不可用（{categoryId}）'**
  String fallbackCategoryUnavailable({required int categoryId});

  /// No description provided for @fallbackMarketGroupUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'市场组数据不可用（{marketGroupId}）'**
  String fallbackMarketGroupUnavailable({required int marketGroupId});

  /// No description provided for @itemDetailTabInfo.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get itemDetailTabInfo;

  /// No description provided for @itemDetailTabAttributes.
  ///
  /// In zh, this message translates to:
  /// **'属性'**
  String get itemDetailTabAttributes;

  /// No description provided for @itemDetailTabSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get itemDetailTabSkills;

  /// No description provided for @itemDetailTabDynamic.
  ///
  /// In zh, this message translates to:
  /// **'动态'**
  String get itemDetailTabDynamic;

  /// No description provided for @itemDetailDynamicUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'动态物品数据暂不可用。'**
  String get itemDetailDynamicUnavailable;

  /// No description provided for @itemDetailDynamicMissing.
  ///
  /// In zh, this message translates to:
  /// **'当前装配已不再引用该动态物品数据。'**
  String get itemDetailDynamicMissing;

  /// No description provided for @itemDetailDynamicBaseItem.
  ///
  /// In zh, this message translates to:
  /// **'基础物品'**
  String get itemDetailDynamicBaseItem;

  /// No description provided for @itemDetailDynamicMutator.
  ///
  /// In zh, this message translates to:
  /// **'深渊物质'**
  String get itemDetailDynamicMutator;

  /// No description provided for @itemDetailDynamicReset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get itemDetailDynamicReset;

  /// No description provided for @itemDetailDynamicReroll.
  ///
  /// In zh, this message translates to:
  /// **'重新随机'**
  String get itemDetailDynamicReroll;

  /// No description provided for @itemDetailDynamicBaseAttributeUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'属性 {attributeId} 的基础数据不可用。'**
  String itemDetailDynamicBaseAttributeUnavailable({required int attributeId});

  /// No description provided for @itemDetailDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get itemDetailDescription;

  /// No description provided for @itemDetailClassification.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get itemDetailClassification;

  /// No description provided for @itemDetailTypeId.
  ///
  /// In zh, this message translates to:
  /// **'类型 ID'**
  String get itemDetailTypeId;

  /// No description provided for @itemDetailCategory.
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get itemDetailCategory;

  /// No description provided for @itemDetailGroup.
  ///
  /// In zh, this message translates to:
  /// **'组'**
  String get itemDetailGroup;

  /// No description provided for @itemDetailMarketGroup.
  ///
  /// In zh, this message translates to:
  /// **'市场组'**
  String get itemDetailMarketGroup;

  /// No description provided for @itemDetailTraits.
  ///
  /// In zh, this message translates to:
  /// **'特性'**
  String get itemDetailTraits;

  /// No description provided for @itemDetailTraitRoleBonuses.
  ///
  /// In zh, this message translates to:
  /// **'特有加成'**
  String get itemDetailTraitRoleBonuses;

  /// No description provided for @itemDetailTraitMiscBonuses.
  ///
  /// In zh, this message translates to:
  /// **'其他加成'**
  String get itemDetailTraitMiscBonuses;

  /// No description provided for @itemDetailTraitPerLevel.
  ///
  /// In zh, this message translates to:
  /// **'{skillName} 每级加成'**
  String itemDetailTraitPerLevel({required String skillName});

  /// No description provided for @itemDetailRequirements.
  ///
  /// In zh, this message translates to:
  /// **'需求'**
  String get itemDetailRequirements;

  /// No description provided for @itemDetailFitting.
  ///
  /// In zh, this message translates to:
  /// **'装配信息'**
  String get itemDetailFitting;

  /// No description provided for @itemDetailSlotClass.
  ///
  /// In zh, this message translates to:
  /// **'槽位类别'**
  String get itemDetailSlotClass;

  /// No description provided for @itemDetailBooleanFalse.
  ///
  /// In zh, this message translates to:
  /// **'否'**
  String get itemDetailBooleanFalse;

  /// No description provided for @itemDetailBooleanTrue.
  ///
  /// In zh, this message translates to:
  /// **'是'**
  String get itemDetailBooleanTrue;

  /// No description provided for @dogmaUnitSizeSmall.
  ///
  /// In zh, this message translates to:
  /// **'小型'**
  String get dogmaUnitSizeSmall;

  /// No description provided for @dogmaUnitSizeMedium.
  ///
  /// In zh, this message translates to:
  /// **'中型'**
  String get dogmaUnitSizeMedium;

  /// No description provided for @dogmaUnitSizeLarge.
  ///
  /// In zh, this message translates to:
  /// **'大型'**
  String get dogmaUnitSizeLarge;

  /// No description provided for @dogmaUnitSizeXLarge.
  ///
  /// In zh, this message translates to:
  /// **'超大型'**
  String get dogmaUnitSizeXLarge;

  /// No description provided for @dogmaUnitSizeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'尺寸 {value}'**
  String dogmaUnitSizeUnknown({required String value});

  /// No description provided for @dogmaUnitSexMale.
  ///
  /// In zh, this message translates to:
  /// **'男性'**
  String get dogmaUnitSexMale;

  /// No description provided for @dogmaUnitSexUnisex.
  ///
  /// In zh, this message translates to:
  /// **'中性'**
  String get dogmaUnitSexUnisex;

  /// No description provided for @dogmaUnitSexFemale.
  ///
  /// In zh, this message translates to:
  /// **'女性'**
  String get dogmaUnitSexFemale;

  /// No description provided for @dogmaUnitSexUnknown.
  ///
  /// In zh, this message translates to:
  /// **'性别 {value}'**
  String dogmaUnitSexUnknown({required String value});

  /// No description provided for @itemDetailAttributes.
  ///
  /// In zh, this message translates to:
  /// **'属性'**
  String get itemDetailAttributes;

  /// No description provided for @itemDetailAttributeOverview.
  ///
  /// In zh, this message translates to:
  /// **'属性概览'**
  String get itemDetailAttributeOverview;

  /// No description provided for @itemDetailAttributeType.
  ///
  /// In zh, this message translates to:
  /// **'物品'**
  String get itemDetailAttributeType;

  /// No description provided for @itemDetailAttributeBaseValue.
  ///
  /// In zh, this message translates to:
  /// **'基础值'**
  String get itemDetailAttributeBaseValue;

  /// No description provided for @itemDetailAttributeCurrentValue.
  ///
  /// In zh, this message translates to:
  /// **'当前值'**
  String get itemDetailAttributeCurrentValue;

  /// No description provided for @itemDetailAttributeDelta.
  ///
  /// In zh, this message translates to:
  /// **'变化量'**
  String get itemDetailAttributeDelta;

  /// No description provided for @itemDetailAttributeBaseAndCurrent.
  ///
  /// In zh, this message translates to:
  /// **'基础：{base}  当前：{current}'**
  String itemDetailAttributeBaseAndCurrent({required String base, required String current});

  /// No description provided for @itemDetailUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'不可用'**
  String get itemDetailUnavailable;

  /// No description provided for @itemDetailEffectChain.
  ///
  /// In zh, this message translates to:
  /// **'效果链'**
  String get itemDetailEffectChain;

  /// No description provided for @itemDetailNoEffectChain.
  ///
  /// In zh, this message translates to:
  /// **'该属性当前没有可用的配置修正链信息。'**
  String get itemDetailNoEffectChain;

  /// No description provided for @itemDetailOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原始值'**
  String get itemDetailOriginal;

  /// No description provided for @itemDetailNormalized.
  ///
  /// In zh, this message translates to:
  /// **'归一化'**
  String get itemDetailNormalized;

  /// No description provided for @itemDetailPenalized.
  ///
  /// In zh, this message translates to:
  /// **'惩罚后'**
  String get itemDetailPenalized;

  /// No description provided for @itemDetailPenalty.
  ///
  /// In zh, this message translates to:
  /// **'惩罚'**
  String get itemDetailPenalty;

  /// No description provided for @itemDetailNet.
  ///
  /// In zh, this message translates to:
  /// **'净变化'**
  String get itemDetailNet;

  /// No description provided for @itemDetailApplied.
  ///
  /// In zh, this message translates to:
  /// **'应用值'**
  String get itemDetailApplied;

  /// No description provided for @itemDetailModifierValueSource.
  ///
  /// In zh, this message translates to:
  /// **'来源值'**
  String get itemDetailModifierValueSource;

  /// No description provided for @itemDetailModifierValueTransformed.
  ///
  /// In zh, this message translates to:
  /// **'转换后'**
  String get itemDetailModifierValueTransformed;

  /// No description provided for @itemDetailModifierValueAppliedAfterPenalty.
  ///
  /// In zh, this message translates to:
  /// **'惩罚后应用值'**
  String get itemDetailModifierValueAppliedAfterPenalty;

  /// No description provided for @itemDetailModifierEffectivePercent.
  ///
  /// In zh, this message translates to:
  /// **'等效 {value}%'**
  String itemDetailModifierEffectivePercent({required String value});

  /// No description provided for @itemDetailModifierSetAttribute.
  ///
  /// In zh, this message translates to:
  /// **'将该属性直接设为 {value}'**
  String itemDetailModifierSetAttribute({required String value});

  /// No description provided for @itemDetailModifierAddsAttribute.
  ///
  /// In zh, this message translates to:
  /// **'为该属性增加 {value}'**
  String itemDetailModifierAddsAttribute({required String value});

  /// No description provided for @itemDetailModifierSubtractsAttribute.
  ///
  /// In zh, this message translates to:
  /// **'为该属性减少 {value}'**
  String itemDetailModifierSubtractsAttribute({required String value});

  /// No description provided for @itemDetailModifierIncreaseCurrentValue.
  ///
  /// In zh, this message translates to:
  /// **'使当前值提高 {value}%'**
  String itemDetailModifierIncreaseCurrentValue({required String value});

  /// No description provided for @itemDetailModifierReduceCurrentValue.
  ///
  /// In zh, this message translates to:
  /// **'使当前值降低 {value}%'**
  String itemDetailModifierReduceCurrentValue({required String value});

  /// No description provided for @itemDetailModifierIncreaseCurrentValueAfterDivision.
  ///
  /// In zh, this message translates to:
  /// **'在除法后使当前值提高 {value}%'**
  String itemDetailModifierIncreaseCurrentValueAfterDivision({required String value});

  /// No description provided for @itemDetailModifierReduceCurrentValueAfterDivision.
  ///
  /// In zh, this message translates to:
  /// **'在除法后使当前值降低 {value}%'**
  String itemDetailModifierReduceCurrentValueAfterDivision({required String value});

  /// No description provided for @itemDetailModifierAppliesBonusPercent.
  ///
  /// In zh, this message translates to:
  /// **'施加 {value}% 加成'**
  String itemDetailModifierAppliesBonusPercent({required String value});

  /// No description provided for @itemDetailModifierAppliesReductionPercent.
  ///
  /// In zh, this message translates to:
  /// **'施加 {value}% 减益'**
  String itemDetailModifierAppliesReductionPercent({required String value});

  /// No description provided for @itemDetailModifierStackingPenaltyHint.
  ///
  /// In zh, this message translates to:
  /// **'叠加惩罚会在实际应用前降低转换后的数值。'**
  String get itemDetailModifierStackingPenaltyHint;

  /// No description provided for @itemDetailBuffSource.
  ///
  /// In zh, this message translates to:
  /// **'增益 {buffId}'**
  String itemDetailBuffSource({required int buffId});

  /// No description provided for @itemDetailModifierSourceShip.
  ///
  /// In zh, this message translates to:
  /// **'舰船'**
  String get itemDetailModifierSourceShip;

  /// No description provided for @itemDetailModifierSourceModule.
  ///
  /// In zh, this message translates to:
  /// **'模块 {index}'**
  String itemDetailModifierSourceModule({required int index});

  /// No description provided for @itemDetailModifierSourceImplant.
  ///
  /// In zh, this message translates to:
  /// **'植入体 {index}'**
  String itemDetailModifierSourceImplant({required int index});

  /// No description provided for @itemDetailModifierSourceBooster.
  ///
  /// In zh, this message translates to:
  /// **'增效剂 {index}'**
  String itemDetailModifierSourceBooster({required int index});

  /// No description provided for @itemDetailModifierSourceSkill.
  ///
  /// In zh, this message translates to:
  /// **'技能 {index}'**
  String itemDetailModifierSourceSkill({required int index});

  /// No description provided for @itemDetailModifierSourceCharge.
  ///
  /// In zh, this message translates to:
  /// **'弹药 {index}'**
  String itemDetailModifierSourceCharge({required int index});

  /// No description provided for @itemDetailModifierSourceCharacter.
  ///
  /// In zh, this message translates to:
  /// **'角色'**
  String get itemDetailModifierSourceCharacter;

  /// No description provided for @itemDetailModifierSourceStructure.
  ///
  /// In zh, this message translates to:
  /// **'建筑'**
  String get itemDetailModifierSourceStructure;

  /// No description provided for @itemDetailModifierSourceTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get itemDetailModifierSourceTarget;

  /// No description provided for @itemDetailEffectOperatorPreAssign.
  ///
  /// In zh, this message translates to:
  /// **'预赋值'**
  String get itemDetailEffectOperatorPreAssign;

  /// No description provided for @itemDetailEffectOperatorPreMul.
  ///
  /// In zh, this message translates to:
  /// **'预乘'**
  String get itemDetailEffectOperatorPreMul;

  /// No description provided for @itemDetailEffectOperatorPreDiv.
  ///
  /// In zh, this message translates to:
  /// **'预除'**
  String get itemDetailEffectOperatorPreDiv;

  /// No description provided for @itemDetailEffectOperatorAdd.
  ///
  /// In zh, this message translates to:
  /// **'增加'**
  String get itemDetailEffectOperatorAdd;

  /// No description provided for @itemDetailEffectOperatorSub.
  ///
  /// In zh, this message translates to:
  /// **'减少'**
  String get itemDetailEffectOperatorSub;

  /// No description provided for @itemDetailEffectOperatorPostMul.
  ///
  /// In zh, this message translates to:
  /// **'后乘'**
  String get itemDetailEffectOperatorPostMul;

  /// No description provided for @itemDetailEffectOperatorPostDiv.
  ///
  /// In zh, this message translates to:
  /// **'后除'**
  String get itemDetailEffectOperatorPostDiv;

  /// No description provided for @itemDetailEffectOperatorPercent.
  ///
  /// In zh, this message translates to:
  /// **'百分比'**
  String get itemDetailEffectOperatorPercent;

  /// No description provided for @itemDetailEffectOperatorPostAssign.
  ///
  /// In zh, this message translates to:
  /// **'后赋值'**
  String get itemDetailEffectOperatorPostAssign;

  /// No description provided for @itemDetailEffectCategoryPassive.
  ///
  /// In zh, this message translates to:
  /// **'被动'**
  String get itemDetailEffectCategoryPassive;

  /// No description provided for @itemDetailEffectCategoryOnline.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get itemDetailEffectCategoryOnline;

  /// No description provided for @itemDetailEffectCategoryActive.
  ///
  /// In zh, this message translates to:
  /// **'激活'**
  String get itemDetailEffectCategoryActive;

  /// No description provided for @itemDetailEffectCategoryOverload.
  ///
  /// In zh, this message translates to:
  /// **'过载'**
  String get itemDetailEffectCategoryOverload;

  /// No description provided for @itemDetailEffectCategoryTarget.
  ///
  /// In zh, this message translates to:
  /// **'目标'**
  String get itemDetailEffectCategoryTarget;

  /// No description provided for @itemDetailEffectCategoryArea.
  ///
  /// In zh, this message translates to:
  /// **'区域'**
  String get itemDetailEffectCategoryArea;

  /// No description provided for @itemDetailEffectCategoryDungeon.
  ///
  /// In zh, this message translates to:
  /// **'副本'**
  String get itemDetailEffectCategoryDungeon;

  /// No description provided for @itemDetailEffectCategorySystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get itemDetailEffectCategorySystem;

  /// No description provided for @loadingTextExtractingBundle.
  ///
  /// In zh, this message translates to:
  /// **'正在解压 {archiveName}...'**
  String loadingTextExtractingBundle({required String archiveName});

  /// No description provided for @dontShowAgain.
  ///
  /// In zh, this message translates to:
  /// **'下次不再提示'**
  String get dontShowAgain;

  /// No description provided for @showDetails.
  ///
  /// In zh, this message translates to:
  /// **'显示详情'**
  String get showDetails;

  /// No description provided for @startupBundleUpdateTitle.
  ///
  /// In zh, this message translates to:
  /// **'有可用的数据包更新'**
  String get startupBundleUpdateTitle;

  /// No description provided for @startupBundleUpdateSingleDescription.
  ///
  /// In zh, this message translates to:
  /// **'有一个新的推荐数据包更新可用。请在数据包管理中查看后再下载。'**
  String get startupBundleUpdateSingleDescription;

  /// No description provided for @startupBundleUpdateMultipleDescription.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 个推荐的数据包更新可用。请在数据包管理中查看后再下载。'**
  String startupBundleUpdateMultipleDescription({required int count});

  /// No description provided for @startupBundleUpdateSummaryRecommended.
  ///
  /// In zh, this message translates to:
  /// **'{firstId} 被推荐'**
  String startupBundleUpdateSummaryRecommended({required String firstId});

  /// No description provided for @startupBundleUpdateSummaryWithCount.
  ///
  /// In zh, this message translates to:
  /// **'{firstId} 及其他 {moreCount} 个被推荐'**
  String startupBundleUpdateSummaryWithCount({required String firstId, required int moreCount});

  /// No description provided for @reportPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'报告与反馈'**
  String get reportPageTitle;

  /// No description provided for @reportSectionGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用反馈'**
  String get reportSectionGeneral;

  /// No description provided for @reportTileGitHub.
  ///
  /// In zh, this message translates to:
  /// **'GitHub Issues'**
  String get reportTileGitHub;

  /// No description provided for @reportTileGitHubDescription.
  ///
  /// In zh, this message translates to:
  /// **'通过 GitHub 提交 Issue 报告问题或提出建议。'**
  String get reportTileGitHubDescription;

  /// No description provided for @reportTileTencentForm.
  ///
  /// In zh, this message translates to:
  /// **'腾讯收集表'**
  String get reportTileTencentForm;

  /// No description provided for @reportTileTencentFormDescription.
  ///
  /// In zh, this message translates to:
  /// **'通过腾讯收集表提交反馈（中文用户）。'**
  String get reportTileTencentFormDescription;

  /// No description provided for @reportTileTencentSheet.
  ///
  /// In zh, this message translates to:
  /// **'腾讯反馈汇总'**
  String get reportTileTencentSheet;

  /// No description provided for @reportTileTencentSheetDescription.
  ///
  /// In zh, this message translates to:
  /// **'查看已提交反馈的汇总表格。'**
  String get reportTileTencentSheetDescription;

  /// No description provided for @reportSectionCommunity.
  ///
  /// In zh, this message translates to:
  /// **'社区交流'**
  String get reportSectionCommunity;

  /// No description provided for @reportTileQQOfficial.
  ///
  /// In zh, this message translates to:
  /// **'EFA 官方 QQ 群'**
  String get reportTileQQOfficial;

  /// No description provided for @reportTileQQOfficialDescription.
  ///
  /// In zh, this message translates to:
  /// **'QQ 群聊 1031146601'**
  String get reportTileQQOfficialDescription;

  /// No description provided for @reportSectionSecurity.
  ///
  /// In zh, this message translates to:
  /// **'安全报告'**
  String get reportSectionSecurity;

  /// No description provided for @reportTileSecurityEmail.
  ///
  /// In zh, this message translates to:
  /// **'安全邮件'**
  String get reportTileSecurityEmail;

  /// No description provided for @reportTileSecurityEmailDescription.
  ///
  /// In zh, this message translates to:
  /// **'发送安全报告至 security@efa-tech.dev'**
  String get reportTileSecurityEmailDescription;

  /// No description provided for @reportTileSecurityQQ.
  ///
  /// In zh, this message translates to:
  /// **'安全联系 QQ'**
  String get reportTileSecurityQQ;

  /// No description provided for @reportTileSecurityQQDescription.
  ///
  /// In zh, this message translates to:
  /// **'联系 QQ 3562377918'**
  String get reportTileSecurityQQDescription;

  /// No description provided for @reportCopyQQSuccess.
  ///
  /// In zh, this message translates to:
  /// **'已复制 QQ 号到剪贴板'**
  String get reportCopyQQSuccess;

  /// No description provided for @reportCopyQQError.
  ///
  /// In zh, this message translates to:
  /// **'复制 QQ 号到剪贴板失败'**
  String get reportCopyQQError;

  /// No description provided for @reportOpenError.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接'**
  String get reportOpenError;

  /// No description provided for @workspaceTabReportTitle.
  ///
  /// In zh, this message translates to:
  /// **'报告与反馈'**
  String get workspaceTabReportTitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
