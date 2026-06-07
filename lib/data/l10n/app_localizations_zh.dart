// THIS IS A GENERATED FILE, DO NOT EDIT.
// ALL YOUR CHANGES WILL BE DISCARDED.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get hello => '你好';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get ok => '好的';

  @override
  String get save => '保存';

  @override
  String get appTitle => 'EVE Fit Assistant';

  @override
  String get edit => '编辑';

  @override
  String get add => '添加';

  @override
  String get confirm => '确认';

  @override
  String get showInfo => '显示详情';

  @override
  String get copy => '复制';

  @override
  String get share => '分享';

  @override
  String get dynamicConvert => '深渊';

  @override
  String get dynamicRevert => '还原';

  @override
  String get dynamicSelectTitle => '选择深渊物质';

  @override
  String get enable => '启用';

  @override
  String get disable => '禁用';

  @override
  String get loading => '加载中...';

  @override
  String get applyAfterRestart => '重启应用程序后生效';

  @override
  String get useCategorySelectList => '组别分类';

  @override
  String get useMarketGroupSelectList => '市场组别分类';

  @override
  String get typeListReturnBehaviorPreviousPage => '返回上一级';

  @override
  String get typeListReturnBehaviorExit => '退出列表';

  @override
  String get highSlot => '高能量槽';

  @override
  String get midSlot => '中能量槽';

  @override
  String get lowSlot => '低能量槽';

  @override
  String get rigSlot => '改装件槽';

  @override
  String get subsystemSlot => '子系统';

  @override
  String get implantSlot => '植入体槽';

  @override
  String get boosterSlot => '增效剂槽';

  @override
  String get serviceSlot => '服务设施槽';

  @override
  String get tacticalMode => '战术模式';

  @override
  String get drone => '无人机';

  @override
  String get fighter => '铁骑舰载机';

  @override
  String get charge => '弹药';

  @override
  String get frontPageTitleWorkspace => '工作台';

  @override
  String get frontPageTitleFitList => '配置';

  @override
  String get frontPageTitleCharacter => '角色';

  @override
  String get frontPageTitleSetting => '设置';

  @override
  String get characterBuiltInProfiles => '内置档案';

  @override
  String get characterCustomProfiles => '自定义档案';

  @override
  String get characterCreateProfile => '创建档案';

  @override
  String characterCreateProfileError({required String message}) {
    return '无法创建档案：$message';
  }

  @override
  String get characterNewProfileName => '新角色';

  @override
  String characterClonedProfileName({required String name}) {
    return '$name 副本';
  }

  @override
  String characterCloneProfileError({required String name, required String message}) {
    return '无法复制 $name：$message';
  }

  @override
  String get characterNoCustomProfiles => '还没有自定义档案。可以先从全 5 创建一个本地技能档案。';

  @override
  String characterLastModified({required String time}) {
    return '修改于 $time';
  }

  @override
  String get characterDeleteProfileTitle => '删除档案';

  @override
  String characterDeleteProfileContent({required String name}) {
    return '删除 $name？使用该档案的配置会保留档案 ID，直到你选择其他档案。';
  }

  @override
  String characterDeleteProfileError({required String name, required String message}) {
    return '无法删除 $name：$message';
  }

  @override
  String get characterProfileInfoTab => '信息';

  @override
  String get characterProfileNameLabel => '角色名称';

  @override
  String get characterProfileDescriptionLabel => '备注';

  @override
  String get characterProfileNameRequired => '请输入角色名称。';

  @override
  String get characterSkillAllGroups => '全部技能组';

  @override
  String get workspaceTabActionCreateFitName => '创建新配置';

  @override
  String get bundleAccessRequiredTitle => '需要数据包';

  @override
  String get bundleAccessNotSelectedDescription => '在选择活动数据包之前，无法创建或导入配置。';

  @override
  String get bundleAccessLoadingDescription => '当前数据包仍在加载中。请等待加载完成后再试。';

  @override
  String get bundleAccessInvalidDescription => '当前数据包不完整或无效。请先导入有效归档文件，或切换到其他数据包。';

  @override
  String get bundleAccessReadyDescription => '当前活动数据包已就绪。';

  @override
  String get bundleAccessManageAction => '打开数据包管理';

  @override
  String startupPersistenceRepairSummary({required String details}) {
    return '已恢复本地存储：$details。';
  }

  @override
  String startupPersistenceRepairSummaryWithWarnings({
    required String details,
    required int unreadableCount,
  }) {
    return '已恢复本地存储：$details。仍有 $unreadableCount 个配置文件需要手动清理。';
  }

  @override
  String get startupPersistenceRepairFoundUnreadableFits => '发现了无法读取的配置文件';

  @override
  String get startupPersistenceRepairRebuiltMetadata => '已重写本地元数据';

  @override
  String startupPersistenceRepairRemovedMissingFits({required int count}) {
    return '移除了 $count 条缺失配置的记录';
  }

  @override
  String startupPersistenceRepairRestoredFits({required int count}) {
    return '恢复了 $count 条已保存配置的记录';
  }

  @override
  String startupPersistenceRepairRemovedMissingBundles({required int count}) {
    return '移除了 $count 条缺失数据包的记录';
  }

  @override
  String startupPersistenceRepairRestoredBundles({required int count}) {
    return '恢复了 $count 个已安装数据包';
  }

  @override
  String get startupPersistenceRepairUpdatedSelectedBundle => '已更新当前选中的数据包';

  @override
  String get settingTileAppSettingsTitle => '设置';

  @override
  String get settingTileRemoteContentTitle => '远程内容';

  @override
  String get settingTileBundleManagerTitle => '数据包';

  @override
  String get settingTileVersionTitle => '版本';

  @override
  String get settingTileVersionSubtitle => '发布说明与更新日志';

  @override
  String get appSettingsPageSectionBundle => '数据包';

  @override
  String get appSettingsPageBundleImpactWarningTitle => '数据包影响警告';

  @override
  String get appSettingsPageBundleImpactWarningDescription => '当切换数据包或导入增量包可能影响已保存的配置或角色时显示警告。';

  @override
  String get bundleImpactDisableConfirmTitle => '关闭数据包影响警告？';

  @override
  String get bundleImpactDisableConfirmDescription => '在重新启用此设置之前，数据包切换和增量包导入将不再显示影响警告。';

  @override
  String get bundleImpactWarningTitle => '潜在数据包影响';

  @override
  String bundleImpactSwitchWarningDescription({required Object bundleId}) {
    return '切换到数据包 $bundleId 可能影响已保存的本地数据。';
  }

  @override
  String bundleImpactIncrementalWarningDescription({required Object bundleId}) {
    return '导入数据包 $bundleId 的增量补丁可能影响已保存的本地数据。';
  }

  @override
  String get bundleImpactContinueAction => '继续';

  @override
  String bundleImpactFitsSummary({required Object count}) {
    return '$count 个配置会受到影响';
  }

  @override
  String bundleImpactCharactersSummary({required Object count}) {
    return '$count 个角色会受到影响';
  }

  @override
  String get bundleImpactBundleDataSummary => '数据包内容将被更新';

  @override
  String get bundleImpactDetailPageTitle => '数据包影响';

  @override
  String bundleImpactDetailDescription({required Object bundleId}) {
    return '使用数据包 $bundleId 时的潜在影响。';
  }

  @override
  String get bundleImpactNoImpacts => '未发现本地影响。';

  @override
  String get bundleImpactFitsSection => '配置';

  @override
  String get bundleImpactCharactersSection => '角色';

  @override
  String get bundleImpactBundleDataSection => '数据包内容';

  @override
  String get bundleImpactSavedBundleLabel => '保存时数据包：';

  @override
  String get bundleImpactTargetBundleLabel => '目标数据包：';

  @override
  String get bundleImpactReasonLabel => '原因：';

  @override
  String get bundleImpactReasonBundleMismatch => '数据包 ID 不同';

  @override
  String get bundleImpactReasonMissingRevision => '缺少可比较的版本元数据';

  @override
  String get bundleImpactReasonManifestMismatch => 'Manifest 哈希不同';

  @override
  String get bundleImpactReasonGenerationMismatch => '生成时间戳不同';

  @override
  String get bundleImpactReasonBuildMismatch => '游戏构建版本不同';

  @override
  String get bundleImpactReasonAppVersionMismatch => '应用版本不同';

  @override
  String get bundleImpactReasonIncrementalPatch => '增量补丁包含变更';

  @override
  String get bundleImpactReasonFullReplacement => '完整替换包包含变更';

  @override
  String get workspaceTabAnnouncementTitle => '更新动态';

  @override
  String get documentAnnouncementPageTitle => '更新动态';

  @override
  String get documentVersionPageTitle => '版本';

  @override
  String get documentAnnouncementEmptyTitle => '当前没有更新内容';

  @override
  String get documentVersionEmptyTitle => '当前没有版本说明';

  @override
  String get documentEmptyDescription => '内置公告、信息说明和版本更新会显示在这里，后续在线更新仍可按来源单独区分。';

  @override
  String get documentLoadErrorTitle => '无法加载文档';

  @override
  String get documentLoadErrorDescription => '请稍后重试，或重新启动应用。';

  @override
  String get documentSelectPrompt => '请选择一条内容以查看详情。';

  @override
  String get documentKindAnnouncement => '公告';

  @override
  String get documentKindInformation => '信息';

  @override
  String get documentKindVersion => '版本';

  @override
  String get documentOpenHint => '点击查看';

  @override
  String documentVersionBadge({required String version}) {
    return '应用 $version';
  }

  @override
  String get documentMarkAllRead => '全部标为已读';

  @override
  String get documentMarkAllUnread => '全部标为未读';

  @override
  String documentMinAppVerWarning({required String version}) {
    return '需要应用版本 $version 或更高';
  }

  @override
  String versionBumpCardTitle({required String version}) {
    return 'v$version 更新内容';
  }

  @override
  String versionBumpCardSubtitle({required int count}) {
    return '$count 条新内容';
  }

  @override
  String get versionBumpCardCloseTooltip => '关闭';

  @override
  String get versionBumpCardSubtitleFallback => '查看版本说明';

  @override
  String get fitCreationPageTitle => '创建新配置';

  @override
  String fitCreationPageDialogHint({required int count}) {
    return '新配置 $count';
  }

  @override
  String get fitCreationPageDialogErrorText => '请输入配置名。';

  @override
  String get fitCreationPageDialogDeleteFitTitle => '删除配置';

  @override
  String fitCreationPageDialogDeleteFitContent({required String fitName}) {
    return '您确定要删除配置 $fitName 吗？';
  }

  @override
  String fitPageTitle({required String fitName, required String shipName}) {
    return '$fitName - $shipName';
  }

  @override
  String get fitPageUnavailableTitle => '配置不可用';

  @override
  String get fitPageMissingMessage => '找不到该配置。';

  @override
  String get fitPageBrokenMessage => '无法加载该配置。';

  @override
  String get fitPageShipUnavailableMessage => '该配置引用了当前数据包中不可用的舰船数据。';

  @override
  String get fitBundleChangedTitle => '数据包已变更';

  @override
  String get fitBundleChangedDescription =>
      '该配置保存于当前活动数据包的旧版本。您仍可查看和导出该配置，但在重新导入兼容的数据包版本，或基于当前数据重新创建配置前，将保持只读。';

  @override
  String get fitBundleLegacyTitle => '需要重新确认数据包';

  @override
  String get fitBundleLegacyDescription =>
      '该配置保存时尚未记录数据包版本信息。您仍可查看和导出该配置，但在使用兼容数据包重新打开，或基于当前数据包重新创建配置前，将保持只读。';

  @override
  String get fitBundleMismatchTitle => '数据包不匹配';

  @override
  String fitBundleMismatchDescription({
    required String savedBundleId,
    required String activeBundleId,
  }) {
    return '该配置保存于数据包 $savedBundleId，而当前活动数据包为 $activeBundleId。您仍可查看和导出该配置，但编辑将保持禁用。';
  }

  @override
  String fitBundleMismatchSwitchDescription({
    required String savedBundleId,
    required String activeBundleId,
  }) {
    return '该配置保存于数据包 $savedBundleId，而当前活动数据包为 $activeBundleId。如需直接编辑该配置，请切回 $savedBundleId；如果您想在当前数据包下保留一个新的可编辑副本，请先确认当前数据差异，再导出并重新导入该配置。';
  }

  @override
  String fitBundleMismatchImportDescription({
    required String savedBundleId,
    required String activeBundleId,
  }) {
    return '该配置保存于数据包 $savedBundleId，而当前活动数据包为 $activeBundleId。如需直接编辑该配置，请先重新导入数据包 $savedBundleId；如果您想迁移到当前数据包，请导出后在当前数据包下重新导入。';
  }

  @override
  String get fitBundleSwitchLabel => '切换数据包后编辑';

  @override
  String get fitBundleImportLabel => '重新导入数据包数据';

  @override
  String get fitBundleSwitchAction => '切换数据包';

  @override
  String get fitBundleSwitchErrorMessage => '无法切换数据包。将保留当前数据包。';

  @override
  String get fitBundleOpenManagerAction => '打开数据包管理';

  @override
  String get fitBundleUnavailableTitle => '数据包不可用';

  @override
  String get fitBundleUnavailableDescription => '当前没有活动数据包，无法确认兼容性。在数据包可用前，该配置将保持只读。';

  @override
  String fitBundleUnavailableSwitchDescription({required String savedBundleId}) {
    return '当前没有活动数据包。请选择 $savedBundleId 后再编辑该配置；如果您暂时不想切换应用的数据上下文，也可以继续只读查看。';
  }

  @override
  String get fitBundleUnavailableImportDescription =>
      '当前没有活动数据包，且该配置对应的已保存数据包尚未安装。请先在数据包管理中导入所需数据，再进行编辑；或者基于当前可用数据包重新创建配置。';

  @override
  String get fitPageStatsUnavailableTitle => '属性不可用';

  @override
  String get fitPageStatsUnavailableMessage => '在计算恢复期间，您仍然可以查看和编辑该配置。';

  @override
  String get fitPageSaveErrorTitle => '更改未保存';

  @override
  String get fitPageSaveErrorMessage => '最新的配置更改无法保存。';

  @override
  String get fitPageReadOnlyMessage => '在启用兼容的数据包之前，该配置将保持只读。';

  @override
  String get fitPageRetryAction => '重试';

  @override
  String get fitPageBackAction => '返回';

  @override
  String get fitIssueDialogTitle => '配置问题';

  @override
  String fitIssueMissingDynamic({required String slotName, required int index}) {
    return '$slotName #$index 引用了缺失的动态物品数据。';
  }

  @override
  String fitIssueMissingItemType({required String slotName, required int index}) {
    return '$slotName #$index 引用了当前不可用的物品数据。';
  }

  @override
  String fitIssueMissingChargeType({required String slotName, required int index}) {
    return '$slotName #$index 引用了当前不可用的弹药数据。';
  }

  @override
  String get fitIssueIncompatibleChargeSize => '弹药尺寸不匹配。';

  @override
  String fitIssueIncompatibleChargeSizeDetails({required String expected, required String actual}) {
    return '期望尺寸：$expected；实际尺寸：$actual。';
  }

  @override
  String get fitIssueIncompatibleChargeCapacity => '弹药体积超过装备容量。';

  @override
  String fitIssueIncompatibleChargeCapacityDetails({required String max, required String actual}) {
    return '最大容量：$max m³；实际体积：$actual m³。';
  }

  @override
  String get fitIssueIncompatibleChargeGroup => '该装备不接受此弹药类型。';

  @override
  String fitIssueIncompatibleChargeGroupDetails({
    required String expected,
    required String actual,
  }) {
    return '期望弹药分组：$expected；实际分组：$actual。';
  }

  @override
  String get fitIssueTooMuchTurret => '炮台数量过多。';

  @override
  String fitIssueTooMuchTurretDetails({required int expected, required int actual}) {
    return '最大数量：$expected；实际数量：$actual。';
  }

  @override
  String get fitIssueTooMuchLauncher => '发射器数量过多。';

  @override
  String fitIssueTooMuchLauncherDetails({required int expected, required int actual}) {
    return '最大数量：$expected；实际数量：$actual。';
  }

  @override
  String get fitIssueConflictItem => '主动装备冲突。';

  @override
  String fitIssueConflictItemDetails({required String groupName}) {
    return '物品组 $groupName 中启用了多个受限制装备。';
  }

  @override
  String get fitIssueDuplicateBooster => '增效剂槽位重复。';

  @override
  String fitIssueDuplicateBoosterDetails({required int slot}) {
    return '增效剂槽位 $slot 已被占用。';
  }

  @override
  String get fitIssueIncompatibleShipGroup => '物品无法安装到该舰船分组。';

  @override
  String fitIssueIncompatibleShipGroupDetails({required String expected}) {
    return '期望舰船分组：$expected。';
  }

  @override
  String get fitIssueIncompatibleShipType => '物品无法安装到该舰船类型。';

  @override
  String fitIssueIncompatibleShipTypeDetails({required String expected}) {
    return '期望舰船类型：$expected。';
  }

  @override
  String get fitIssueIncompatibleRigSize => '改装件尺寸不匹配。';

  @override
  String fitIssueIncompatibleRigSizeDetails({required String expected, required String actual}) {
    return '期望尺寸：$expected；实际尺寸：$actual。';
  }

  @override
  String get fitIssueMissingCharge => '缺少弹药。';

  @override
  String get fitIssueUnknownValidationIssue => '未知配置校验问题。';

  @override
  String get fitTabsCharacter => '角色';

  @override
  String get fitTabsEquipment => '装备';

  @override
  String get fitTabsAttributes => '属性';

  @override
  String get fitTabsDrone => '无人机';

  @override
  String get fitTabsFighter => '舰载机';

  @override
  String get fitTabsUtils => '杂项';

  @override
  String fitSkillPolicyPresetTitle({required String profileName}) {
    return '技能档案：$profileName';
  }

  @override
  String get fitSkillPolicyPresetDescription => '当前构建使用预设技能档案，而不是真实角色数据。';

  @override
  String get fitSkillProfileAll5 => '全 5';

  @override
  String get fitSkillProfileAlphaMax => 'Alpha 最高';

  @override
  String get fitSkillProfileAll0 => '全 0';

  @override
  String get fitSkillPolicyUnsupportedTitle => '当前构建暂不支持技能感知模拟。';

  @override
  String get fitSkillPolicyUnsupportedDescription => '当前配置模拟不会应用角色技能修正。植入体和增效剂仍然生效。';

  @override
  String fitAddItemDialogTitle({required String slotName}) {
    return '添加物品：$slotName';
  }

  @override
  String fitAddItemDialogTitleWithIndex({required String slotName, required int index}) {
    return '添加物品：$slotName #$index';
  }

  @override
  String fitSlotEmpty({required String slotName}) {
    return '$slotName（空）';
  }

  @override
  String get fitActionFill => '补满';

  @override
  String get fitActionSet => '设置';

  @override
  String fitUnknownImplantAtSlot({required int slot}) {
    return '槽位 $slot 的植入体不可用';
  }

  @override
  String fitUnknownImplant({required int typeId}) {
    return '植入体不可用（$typeId）';
  }

  @override
  String fitUnknownBoosterAtSlot({required int slot}) {
    return '槽位 $slot 的增效剂不可用';
  }

  @override
  String fitUnknownBooster({required int typeId}) {
    return '增效剂不可用（$typeId）';
  }

  @override
  String fitUnknownItemAtSlot({required int slot}) {
    return '槽位 $slot 的物品数据不可用';
  }

  @override
  String fitUnknownItemWithIdAtSlot({required int itemId, required int slot}) {
    return '槽位 $slot 的物品数据不可用（$itemId）';
  }

  @override
  String fitUnknownFighterAtSlot({required int slot}) {
    return '槽位 $slot 的舰载机数据不可用';
  }

  @override
  String fitUnknownFighterWithIdAtSlot({required int itemId, required int slot}) {
    return '槽位 $slot 的舰载机数据不可用（$itemId）';
  }

  @override
  String fitUnknownShip({required int typeId}) {
    return '舰船数据不可用（$typeId）';
  }

  @override
  String fitUnknownSubsystemAtSlot({required int slot}) {
    return '槽位 $slot 的子系统数据不可用';
  }

  @override
  String fitUnknownSubsystemWithIdAtSlot({required int itemId, required int slot}) {
    return '槽位 $slot 的子系统数据不可用（$itemId）';
  }

  @override
  String fitUnknownTacticalMode({required int typeId}) {
    return '战术模式数据不可用（$typeId）';
  }

  @override
  String get fitUtilsNameRequired => '请输入配置名。';

  @override
  String get fitUtilsExportButton => '导出配置';

  @override
  String get fitUtilsExportImageButton => '导出图片';

  @override
  String get fitUtilsNameLabel => '配置名称';

  @override
  String get fitUtilsDescriptionLabel => '配置备注';

  @override
  String get fitExportDialogTitle => '导出配置';

  @override
  String get fitExportLoadError => '无法加载该配置用于导出。';

  @override
  String get fitExportFormatNative => 'EFA 原生编码';

  @override
  String get fitExportFormatNativeDescription => '完整保留配置细节的导出格式，适合在另一台 EVE Fit Assistant 设备上导入。';

  @override
  String get fitExportFormatFittingLink => '游戏内装配链接';

  @override
  String get fitExportFormatFittingLinkDescription => '复制可粘贴到 EVE 的装配链接。游戏支持的模块、弹药、无人机和舰载机信息会被保留。';

  @override
  String get fitExportFormatEft => 'EFT 文本';

  @override
  String get fitExportFormatEftDescription => '复制可用于 pyfa 等第三方工具的 EFT 文本格式。';

  @override
  String get fitExportLossyWarning => '该导出格式会丢失部分配置细节。';

  @override
  String get fitExportCopied => '已复制配置导出内容。';

  @override
  String get fitExportClipboardError => '当前无法复制该配置导出内容。';

  @override
  String get fitExportShareError => '当前无法分享该配置导出内容。';

  @override
  String get fitListActionExport => '导出';

  @override
  String get fitListActionImport => '导入';

  @override
  String get fitImportDialogTitle => '导入配置';

  @override
  String get fitImportDialogDescription => '请在下方粘贴配置文本。当前导入流程支持 EFA 原生编码和 EFT 文本。';

  @override
  String get fitImportInputLabel => '配置文本';

  @override
  String get fitImportPasteButton => '粘贴';

  @override
  String get fitImportConfirmButton => '导入';

  @override
  String get fitImportErrorEmpty => '请先粘贴配置文本再导入。';

  @override
  String get fitImportErrorUnsupportedFormat => '该文本不是当前支持的配置导入格式。';

  @override
  String get fitImportErrorUnsupportedFittingLink => '当前测试版本暂不支持导入游戏内装配链接。';

  @override
  String get fitImportErrorUnsupportedNativeVersion => '该 EFA 导出内容来自较新的应用版本，当前版本暂时无法导入。';

  @override
  String get fitImportErrorInvalidNativePayload => '该 EFA 导出内容已损坏或不完整。';

  @override
  String get fitImportErrorInvalidEft => '该 EFT 文本无效，或包含当前测试版本暂不支持的段落。';

  @override
  String fitImportErrorUnknownType({required String typeName}) {
    return '当前数据包无法识别“$typeName”。';
  }

  @override
  String fitImportErrorUnavailableShip({required String shipName}) {
    return '当前数据包中没有舰船“$shipName”。';
  }

  @override
  String get fitImportErrorUnavailableData => '导入所需的数据暂未就绪。请等待应用完成数据包加载后再试。';

  @override
  String fitImportSuccess({required String fitName}) {
    return '已导入 $fitName';
  }

  @override
  String get fitImportUnknownError => '无法导入该配置。';

  @override
  String get fitScreenshotPageTitle => '配置图片导出';

  @override
  String get fitScreenshotSave => '保存图片';

  @override
  String get fitScreenshotShare => '分享图片';

  @override
  String fitScreenshotSaved({required String path}) {
    return '已保存截图到 $path';
  }

  @override
  String get fitScreenshotDamageProfile => '伤害分布';

  @override
  String get fitScreenshotEquipment => '装备';

  @override
  String get fitScreenshotSupport => '植入体与增效剂';

  @override
  String get fitScreenshotMinions => '无人机与舰载机';

  @override
  String get fitScreenshotStats => '快速属性';

  @override
  String get fitScreenshotEmpty => '无';

  @override
  String get fitScreenshotStatsUnavailable => '属性不可用';

  @override
  String get fitScreenshotFighterCapacity => '舰载机容量';

  @override
  String get fitScreenshotShieldHp => '护盾 HP';

  @override
  String get fitScreenshotArmorHp => '装甲 HP';

  @override
  String get fitScreenshotHullHp => '结构 HP';

  @override
  String get fitScreenshotCapacitor => '电容';

  @override
  String get fitScreenshotDroneBandwidth => '无人机带宽';

  @override
  String fitAttributeTabCapacitorStable({required String percent}) {
    return '$percent% 稳定';
  }

  @override
  String get fitFighterAbilityTurret => '炮塔';

  @override
  String get fitFighterAbilityMissiles => '导弹';

  @override
  String get fitFighterAbilityVolley => '齐射';

  @override
  String get fitFighterAbilityBomb => '炸弹';

  @override
  String get fitDroneTabAddDroneTitle => '添加无人机';

  @override
  String get appSettingsPageTitle => '应用设置';

  @override
  String get appSettingsPageSectionGeneral => '常规';

  @override
  String get appSettingsPageLocaleTitle => '语言';

  @override
  String get appSettingsPageLocaleSubtitle => '选择应用语言';

  @override
  String get appSettingsPageFontScaleTitle => '字体缩放';

  @override
  String get appSettingsPageFontScaleDescription => '调整应用文字缩放比例，更改立即生效。';

  @override
  String get appSettingsPageFontScaleXS => '特小';

  @override
  String get appSettingsPageFontScaleS => '小';

  @override
  String get appSettingsPageFontScaleM => '中';

  @override
  String get appSettingsPageFontScaleL => '大';

  @override
  String get appSettingsPageFontScaleXL => '特大';

  @override
  String get appSettingsPageSectionSelectList => '展示列表格式';

  @override
  String get appSettingsPageShipSelectTypeTitle => '舰船选择列表格式';

  @override
  String get appSettingsPageShipSelectTypeDescription =>
      '选择舰船时使用的列表格式。\n按组别分类会按照游戏中的物品组进行分类。\n按市场组别分类会按照市场中的分组进行分类。';

  @override
  String get appSettingsPageListReturnBehaviorTitle => '列表返回行为';

  @override
  String get appSettingsPageListReturnBehaviorDescription =>
      '选择在嵌套选择列表中触发系统返回时的行为。返回上一级会先回到上一个列表层级，然后再关闭列表；退出列表会直接关闭选择器。';

  @override
  String get appSettingsPageSectionRemoteContent => '远程内容';

  @override
  String get appSettingsPageRemoteContentPanelVisibleTitle => '显示远程内容设置';

  @override
  String get appSettingsPageRemoteContentVisibleTitle => '显示远程内容入口';

  @override
  String get appSettingsPageRemoteContentVisibleDescription => '在设置页显示或隐藏远程内容入口。';

  @override
  String get appSettingsPageRemoteContentOpenTitle => '打开远程内容设置';

  @override
  String get appSettingsPageRemoteContentOpenDescription => '配置远程内容运行时参数。';

  @override
  String get appSettingsPageRemoteContentWarningTitle => '要打开远程内容设置吗？';

  @override
  String get appSettingsPageRemoteContentWarningDescription =>
      '远程内容设置仍处于实验阶段，可能影响后续文档、版本和数据包元数据发现。仅在确认要使用的端点时继续。';

  @override
  String get appSettingsPageRemoteContentEnabledTitle => '启用远程内容';

  @override
  String get appSettingsPageRemoteContentEnabledDescription =>
      '当运行时同步可用时，允许应用从配置的远程源发现文档、版本和数据包元数据。';

  @override
  String get appSettingsPageRemoteContentEndpointTitle => '远程内容端点';

  @override
  String appSettingsPageRemoteContentEndpointDescription({
    required String origin,
    required String resourceRoot,
    required String channel,
  }) {
    return '源：$origin\n根路径：$resourceRoot\n频道：$channel';
  }

  @override
  String get appSettingsPageRemoteContentNotSet => '未设置';

  @override
  String get appSettingsPageRemoteContentOriginUrlLabel => '源 URL';

  @override
  String get appSettingsPageRemoteContentResourceRootLabel => '资源根路径';

  @override
  String get appSettingsPageRemoteContentChannelLabel => '频道';

  @override
  String get appSettingsPageRemoteContentChannelTesting => '测试版';

  @override
  String get appSettingsPageRemoteContentChannelStable => '稳定版';

  @override
  String get appSettingsPageCollectLogsEntryTitle => '收集日志';

  @override
  String get appSettingsPageCollectLogsEntryDescription => '选择和分享应用日志以进行调试和问题报告';

  @override
  String get collectLogsPageTitle => '收集日志';

  @override
  String get collectLogsQuickFilter => '快速筛选';

  @override
  String get collectLogsFilterAll => '全部';

  @override
  String get collectLogsFilter1Hour => '1小时';

  @override
  String get collectLogsFilter24Hours => '24小时';

  @override
  String get collectLogsFilter7Days => '7天';

  @override
  String get collectLogsFilter30Days => '30天';

  @override
  String get collectLogsFileActive => '(当前)';

  @override
  String get collectLogsNoLogFiles => '未找到日志文件';

  @override
  String get collectLogsShareButton => '分享';

  @override
  String collectLogsTotalSize({required String size, required int count}) {
    return '$size，共 $count 个文件';
  }

  @override
  String get collectLogsLoadError => '加载日志文件失败';

  @override
  String get appSettingsPageSectionDeveloper => '开发者选项';

  @override
  String get appSettingsPageDebugLogTitle => '启用调试日志';

  @override
  String get appSettingsPageDebugLogDescription => '启用调试日志后，应用将会输出所有日志到日志目录中。\n建议仅当开发者要求开启此功能时才开启。';

  @override
  String get bundleManagerPageTitle => '数据包管理';

  @override
  String get bundleImportOverwriteTitle => '要替换现有数据包吗？';

  @override
  String get bundleManagerBundleAppVersion => '打包应用版本：';

  @override
  String get bundleManagerBundleBuild => '构建版本：';

  @override
  String get bundleManagerBundleGameVersion => '游戏版本：';

  @override
  String get bundleManagerBundleServer => '服务器：';

  @override
  String get bundleManagerBundleRegion => '服务地区：';

  @override
  String get bundleManagerBundleBranch => '游戏分支：';

  @override
  String bundleManagerBundleSchemaVersion({required int num}) {
    return '架构 v$num';
  }

  @override
  String get bundleManagerDeleteBundleConfirmTitle => '删除数据包';

  @override
  String bundleManagerDeleteBundleConfirmContent({required String bundleId}) {
    return '您确定要删除数据包 $bundleId 吗？';
  }

  @override
  String get bundleManagerDeleteBundleInUseWarning => '该数据包正在被使用，删除后可能导致某些功能无法正常工作。';

  @override
  String get bundleManagerDetailPageTitle => '数据包详情';

  @override
  String get bundleManagerDetailSectionTitleLatestPatch => '最新补丁';

  @override
  String get bundleManagerDetailSectionTitleHistory => '历史版本';

  @override
  String get bundleManagerDetailVariantFull => '完整';

  @override
  String get bundleManagerDetailVariantIncremental => '增量';

  @override
  String get bundleManagerDetailGeneratedAt => '生成时间：';

  @override
  String get bundleManagerDetailLoadedAt => '加载时间：';

  @override
  String get bundleVerificationTitle => '完整性校验';

  @override
  String get bundleVerificationAction => '校验已安装文件';

  @override
  String get bundleVerificationConfirmTitle => '要校验已安装的数据包文件吗？';

  @override
  String get bundleVerificationConfirmMessage =>
      '此操作会读取已安装的数据包文件，并根据本地清单比较文件大小和 SHA-256 哈希。大型数据包可能需要一些时间。不会修改任何文件。';

  @override
  String get bundleVerificationValid => '已安装文件与本地清单一致。';

  @override
  String get bundleVerificationWarning => '校验完成，但存在警告。';

  @override
  String get bundleVerificationInvalid => '校验发现数据包完整性问题。';

  @override
  String get bundleVerificationNeverRun => '尚未执行校验。';

  @override
  String bundleVerificationCheckedAt({required String time}) {
    return '校验时间：$time';
  }

  @override
  String bundleVerificationMissingFiles({required int count}) {
    return '缺失：$count';
  }

  @override
  String bundleVerificationHashMismatches({required int count}) {
    return '哈希不匹配：$count';
  }

  @override
  String bundleVerificationSizeMismatches({required int count}) {
    return '大小不匹配：$count';
  }

  @override
  String bundleVerificationExtraFiles({required int count}) {
    return '额外文件：$count';
  }

  @override
  String bundleVerificationMoreIssues({required int count}) {
    return '另有 $count 个问题';
  }

  @override
  String get bundleVerificationRemoteRepairUnavailable => '在可用的远程数据包元数据实现前，暂不支持远程修复。';

  @override
  String bundleVerificationIssueMissingManifest({required String path}) {
    return '缺少清单：$path';
  }

  @override
  String bundleVerificationIssueInvalidManifest({required String path, required String error}) {
    return '清单无效 $path：$error';
  }

  @override
  String get bundleVerificationIssueManifestHashMissing => '安装记录中没有最新清单哈希。';

  @override
  String bundleVerificationIssueManifestHashMismatch({
    required String expected,
    required String actual,
  }) {
    return '清单哈希不匹配：应为 $expected，实际为 $actual';
  }

  @override
  String bundleVerificationIssueUnsafeManifestPath({required String path}) {
    return '清单路径不安全：$path';
  }

  @override
  String bundleVerificationIssueMissingFile({required String path}) {
    return '缺少文件：$path';
  }

  @override
  String bundleVerificationIssueSizeMismatch({
    required String path,
    required int expected,
    required int actual,
  }) {
    return '文件大小不匹配 $path：应为 $expected，实际为 $actual';
  }

  @override
  String bundleVerificationIssueHashMismatch({
    required String path,
    required String expected,
    required String actual,
  }) {
    return '文件哈希不匹配 $path：应为 $expected，实际为 $actual';
  }

  @override
  String bundleVerificationIssueExtraFile({required String path}) {
    return '额外文件：$path';
  }

  @override
  String bundleVerificationIssueReadError({required String path, required String error}) {
    return '读取失败 $path：$error';
  }

  @override
  String bundleVerificationIssueUnsupportedSchemaVersion({
    required int version,
    required int min,
    required int max,
  }) {
    return '数据包架构 v$version 不受支持（支持版本: v$min–v$max)。';
  }

  @override
  String bundleVerificationIssueSchemaVersionMismatch({
    required int version,
    required int current,
  }) {
    return '数据包架构 v$version 与当前应用架构 v$current 不同。';
  }

  @override
  String get bundleManagerSetupTitle => '导入第一个数据包';

  @override
  String get bundleManagerSetupDescription => '装配和相关功能需要先加载一个有效的数据包。请先导入数据包归档文件。';

  @override
  String get bundleManagerAlphaScope => 'Alpha 范围：应用可以安装多个数据包，但全局同一时间只会启用一个活动数据包。';

  @override
  String get bundleManagerImportSelectionBehavior =>
      '导入数据包时会保留当前活动数据包。只有在您确实想切换应用数据上下文时，才需要在下方选择其他已安装数据包。';

  @override
  String get bundleManagerSelectionTitle => '选择活动数据包';

  @override
  String get bundleManagerSelectionDescription => '请从下方已安装的数据包中选择一个，或重新导入新的归档文件来恢复数据。';

  @override
  String get bundleManagerLoadingTitle => '正在加载数据包';

  @override
  String bundleManagerLoadingDescription({required String bundleId}) {
    return '正在准备数据包 $bundleId。';
  }

  @override
  String get bundleManagerInvalidTitle => '数据包需要处理';

  @override
  String get bundleManagerInvalidDescription => '当前选中的数据包缺少必要文件或元数据。请导入有效归档，或切换到其他已安装的数据包。';

  @override
  String get bundleManagerReadyTitle => '数据包可用';

  @override
  String bundleManagerReadyDescription({required String bundleId}) {
    return '当前活动数据包：$bundleId';
  }

  @override
  String get bundleManagerImportAction => '导入数据包';

  @override
  String get bundleRemoteSectionTitle => '远程数据包';

  @override
  String get bundleRemoteSectionDescription => '从已配置的远程内容端点发现兼容的数据包归档。只有在您选择后才会开始下载。';

  @override
  String get bundleRemoteRefreshAction => '刷新远程数据包';

  @override
  String get bundleRemoteEmpty => '没有可用的兼容远程数据包。';

  @override
  String get bundleRemoteChecking => '正在检查远程数据包目录……';

  @override
  String get bundleRemoteCatalogMissing => '远程索引未在此频道提供数据包目录。';

  @override
  String get bundleRemoteCatalogEmpty => '远程数据包目录为空。';

  @override
  String get bundleRemoteAlternativesOnly => '存在可用的远程数据包，但当前安装状态下没有首选项。请先检查备选项再下载。';

  @override
  String get bundleRemoteCurrent => '已安装的数据包已经匹配最新兼容的远程产物。';

  @override
  String get bundleRemoteNoImportable => '已找到远程数据包元数据，但当前设备暂时没有可导入的产物。';

  @override
  String get bundleRemoteReviewAction => '检查数据包';

  @override
  String get bundleRemoteDownloadRecommendedAction => '下载推荐项';

  @override
  String get bundleRemoteSelectionPageTitle => '远程数据包';

  @override
  String get bundleRemoteDisabled => '远程内容已禁用。请先在远程内容设置中启用，再检查远程数据包。';

  @override
  String bundleRemoteRecommendedCount({required int count}) {
    return '推荐：$count';
  }

  @override
  String bundleRemoteAvailableCount({required int count}) {
    return '可用：$count';
  }

  @override
  String bundleRemoteInstalledCount({required int count}) {
    return '已安装：$count';
  }

  @override
  String bundleRemoteUnavailableCount({required int count}) {
    return '不可用：$count';
  }

  @override
  String get bundleRemoteRecommendedSection => '推荐';

  @override
  String get bundleRemoteRecommendedSectionDescription =>
      '根据已安装清单元数据，为已安装数据包选择最佳后续下载。同一数据包的较旧产物会保留为备选项。';

  @override
  String get bundleRemoteAvailableSection => '可用备选';

  @override
  String get bundleRemoteAvailableSectionDescription => '可导入但不是首选推荐的完整数据包或补丁。';

  @override
  String get bundleRemoteInstalledSection => '已安装';

  @override
  String get bundleRemoteInstalledSectionDescription => '与已安装数据包清单匹配的远程产物。';

  @override
  String get bundleRemoteUnavailableSection => '不可用';

  @override
  String get bundleRemoteUnavailableSectionDescription => '由于应用版本或本地基线元数据不匹配，当前无法导入的产物。';

  @override
  String get bundleRemoteSelectionSummaryTitle => '选择建议';

  @override
  String get bundleRemoteSelectionSummaryDescription =>
      '当增量补丁匹配已安装基线清单时，会优先推荐增量补丁。完整数据包仍可手动用于新安装或替换安装。';

  @override
  String bundleRemoteRecommendationIncremental({required String bundleId}) {
    return '推荐为 $bundleId 使用增量更新。';
  }

  @override
  String bundleRemoteRecommendationFullInstall({required String bundleId}) {
    return '推荐完整安装数据包：$bundleId。';
  }

  @override
  String bundleRemoteRecommendationFullReplacement({required String bundleId}) {
    return '当前没有匹配的增量路径；请使用 $bundleId 的完整替换包。';
  }

  @override
  String get bundleRemoteRecommendedFallback => '推荐的远程数据包。';

  @override
  String get bundleRemoteAvailableDescription => '此产物可以下载并导入。';

  @override
  String get bundleRemoteInstalledDescription => '此产物已存在于已安装数据包历史中。';

  @override
  String get bundleRemoteUnknownAppVersion => '未知';

  @override
  String bundleRemoteUnavailableAppVersion({
    required String requiredVersion,
    required String currentVersion,
  }) {
    return '需要应用版本 $requiredVersion；当前应用为 $currentVersion。';
  }

  @override
  String bundleRemoteUnavailableIncompatibleSchema({required int version}) {
    return '数据包架构 v$version 不被当前应用版本支持。';
  }

  @override
  String get bundleRemoteUnavailableMissingIncrementalMetadata => '增量产物缺少基线数据包元数据。';

  @override
  String bundleRemoteUnavailableBaseNotInstalled({required String bundleId}) {
    return '请先安装基线数据包 $bundleId，再应用此增量补丁。';
  }

  @override
  String get bundleRemoteUnavailableInstalledManifestMissing => '已安装数据包元数据没有记录清单哈希。';

  @override
  String get bundleRemoteUnavailableBaseManifestMismatch => '已安装清单与此增量补丁基线不匹配。请改用完整数据包。';

  @override
  String get bundleRemoteUnavailableUnknown => '此产物当前无法导入。';

  @override
  String bundleRemoteError({required String message}) {
    return '远程数据包发现失败：$message';
  }

  @override
  String bundleRemoteArtifactDescription({
    required String variant,
    required String bundleId,
    required String gameBuild,
    required String gameServer,
  }) {
    return '$variant数据包 $bundleId · 构建 $gameBuild · $gameServer';
  }

  @override
  String get bundleRemoteDownloadAction => '下载';

  @override
  String get bundleRemoteDownloadImportAction => '下载并导入';

  @override
  String get bundleRemoteImportBehaviorHint => '将导入为已安装数据包。活动数据包会保持不变，直到您在下方手动选择。';

  @override
  String bundleRemoteArtifactSize({required String size}) {
    return '大小：$size';
  }

  @override
  String bundleRemoteArtifactGenerated({required String time}) {
    return '生成时间：$time';
  }

  @override
  String bundleRemoteArtifactBaseBundle({required String bundleId}) {
    return '修补已安装基线：$bundleId';
  }

  @override
  String bundleRemoteArtifactBaseManifest({required String hash}) {
    return '基线清单：$hash';
  }

  @override
  String bundleRemoteSchemaVersionWarning({required int version}) {
    return '架构 v$version — 可能与当前应用架构不同';
  }

  @override
  String get bundleRemoteProgressPreparing => '正在准备远程请求';

  @override
  String get bundleRemoteProgressDownloading => '正在下载归档';

  @override
  String get bundleRemoteProgressVerifying => '正在校验大小和 SHA-256';

  @override
  String get bundleRemoteProgressUnpacking => '正在解包归档';

  @override
  String get bundleRemoteProgressImporting => '正在导入数据包文件';

  @override
  String get bundleRemoteProgressApplyingIncrementalPatch => '正在应用增量补丁';

  @override
  String get bundleRemoteProgressRefreshingRegistry => '正在刷新已安装数据包列表';

  @override
  String get bundleRemoteProgressCompleted => '已导入，未激活';

  @override
  String get bundleRemoteProgressCancelled => '导入已取消';

  @override
  String get bundleRemoteProgressQueued => '等待开始';

  @override
  String bundleRemoteProgressDownloadingKnown({
    required String received,
    required String total,
    required String percent,
  }) {
    return '$received / $total（$percent%）';
  }

  @override
  String bundleRemoteProgressDownloadingUnknown({required String received}) {
    return '已下载 $received';
  }

  @override
  String bundleRemoteProgressCompletedDescription({required String bundleId}) {
    return '$bundleId 已安装。需要切换应用活动数据时，请手动选择它。';
  }

  @override
  String get bundleRemoteProgressCancelledDescription => '当前数据包保持不变。';

  @override
  String get bundleRemoteProgressFailedTitle => '导入失败';

  @override
  String bundleRemoteProgressFailedDescription({required String stage, required String message}) {
    return '在“$stage”阶段失败：$message';
  }

  @override
  String get bundleRemoteProgressRetryAction => '重试';

  @override
  String get bundleRemoteProgressKeepCurrentAction => '保留当前数据包';

  @override
  String get bundleRemoteProgressViewInstalledAction => '查看已安装数据包';

  @override
  String get bundleRemoteProgressLoadBundleAction => '加载此数据包';

  @override
  String get bundleRemoteImportConfirmTitle => '要下载远程数据包吗？';

  @override
  String bundleRemoteImportConfirmDescription({required String artifactId}) {
    return '下载、校验并导入 $artifactId？当前活动数据包不会自动切换。';
  }

  @override
  String get bundleRemoteImportSucceeded => '远程数据包已导入。';

  @override
  String bundleRemoteImportFailed({required String message}) {
    return '远程数据包导入失败：$message';
  }

  @override
  String bundleManagerErrorMissingPath({required String path}) {
    return '缺少必要路径：$path';
  }

  @override
  String bundleManagerErrorExpectFile({required String fileName}) {
    return '该位置应为文件：$fileName';
  }

  @override
  String bundleManagerErrorExpectDirectory({required String dirName}) {
    return '该位置应为目录：$dirName';
  }

  @override
  String get bundleManagerErrorBadDescriptor => '无法读取数据包元数据。';

  @override
  String bundleManagerErrorBadPatch({required String reason}) {
    return '数据包历史记录无效：$reason';
  }

  @override
  String get bundleManagerDetailUnavailableMessage => '在修复或重新导入数据包元数据之前，无法显示该数据包详情。';

  @override
  String fallbackTypeUnavailable({required int typeId}) {
    return '物品数据不可用（$typeId）';
  }

  @override
  String fallbackGroupUnavailable({required int groupId}) {
    return '组数据不可用（$groupId）';
  }

  @override
  String fallbackCategoryUnavailable({required int categoryId}) {
    return '分类数据不可用（$categoryId）';
  }

  @override
  String fallbackMarketGroupUnavailable({required int marketGroupId}) {
    return '市场组数据不可用（$marketGroupId）';
  }

  @override
  String get itemDetailTabInfo => '信息';

  @override
  String get itemDetailTabAttributes => '属性';

  @override
  String get itemDetailTabSkills => '技能';

  @override
  String get itemDetailTabDynamic => '动态';

  @override
  String get itemDetailDynamicUnavailable => '动态物品数据暂不可用。';

  @override
  String get itemDetailDynamicMissing => '当前装配已不再引用该动态物品数据。';

  @override
  String get itemDetailDynamicBaseItem => '基础物品';

  @override
  String get itemDetailDynamicMutator => '深渊物质';

  @override
  String get itemDetailDynamicReset => '重置';

  @override
  String get itemDetailDynamicReroll => '重新随机';

  @override
  String itemDetailDynamicBaseAttributeUnavailable({required int attributeId}) {
    return '属性 $attributeId 的基础数据不可用。';
  }

  @override
  String get itemDetailDescription => '描述';

  @override
  String get itemDetailClassification => '分类';

  @override
  String get itemDetailTypeId => '类型 ID';

  @override
  String get itemDetailCategory => '分类';

  @override
  String get itemDetailGroup => '组';

  @override
  String get itemDetailMarketGroup => '市场组';

  @override
  String get itemDetailTraits => '特性';

  @override
  String get itemDetailTraitRoleBonuses => '特有加成';

  @override
  String get itemDetailTraitMiscBonuses => '其他加成';

  @override
  String itemDetailTraitPerLevel({required String skillName}) {
    return '$skillName 每级加成';
  }

  @override
  String get itemDetailRequirements => '需求';

  @override
  String get itemDetailFitting => '装配信息';

  @override
  String get itemDetailSlotClass => '槽位类别';

  @override
  String get itemDetailBooleanFalse => '否';

  @override
  String get itemDetailBooleanTrue => '是';

  @override
  String get dogmaUnitSizeSmall => '小型';

  @override
  String get dogmaUnitSizeMedium => '中型';

  @override
  String get dogmaUnitSizeLarge => '大型';

  @override
  String get dogmaUnitSizeXLarge => '超大型';

  @override
  String dogmaUnitSizeUnknown({required String value}) {
    return '尺寸 $value';
  }

  @override
  String get dogmaUnitSexMale => '男性';

  @override
  String get dogmaUnitSexUnisex => '中性';

  @override
  String get dogmaUnitSexFemale => '女性';

  @override
  String dogmaUnitSexUnknown({required String value}) {
    return '性别 $value';
  }

  @override
  String get itemDetailAttributes => '属性';

  @override
  String get itemDetailAttributeOverview => '属性概览';

  @override
  String get itemDetailAttributeType => '物品';

  @override
  String get itemDetailAttributeBaseValue => '基础值';

  @override
  String get itemDetailAttributeCurrentValue => '当前值';

  @override
  String get itemDetailAttributeDelta => '变化量';

  @override
  String itemDetailAttributeBaseAndCurrent({required String base, required String current}) {
    return '基础：$base  当前：$current';
  }

  @override
  String get itemDetailUnavailable => '不可用';

  @override
  String get itemDetailEffectChain => '效果链';

  @override
  String get itemDetailNoEffectChain => '该属性当前没有可用的配置修正链信息。';

  @override
  String get itemDetailOriginal => '原始值';

  @override
  String get itemDetailNormalized => '归一化';

  @override
  String get itemDetailPenalized => '惩罚后';

  @override
  String get itemDetailPenalty => '惩罚';

  @override
  String get itemDetailNet => '净变化';

  @override
  String get itemDetailApplied => '应用值';

  @override
  String get itemDetailModifierValueSource => '来源值';

  @override
  String get itemDetailModifierValueTransformed => '转换后';

  @override
  String get itemDetailModifierValueAppliedAfterPenalty => '惩罚后应用值';

  @override
  String itemDetailModifierEffectivePercent({required String value}) {
    return '等效 $value%';
  }

  @override
  String itemDetailModifierSetAttribute({required String value}) {
    return '将该属性直接设为 $value';
  }

  @override
  String itemDetailModifierAddsAttribute({required String value}) {
    return '为该属性增加 $value';
  }

  @override
  String itemDetailModifierSubtractsAttribute({required String value}) {
    return '为该属性减少 $value';
  }

  @override
  String itemDetailModifierIncreaseCurrentValue({required String value}) {
    return '使当前值提高 $value%';
  }

  @override
  String itemDetailModifierReduceCurrentValue({required String value}) {
    return '使当前值降低 $value%';
  }

  @override
  String itemDetailModifierIncreaseCurrentValueAfterDivision({required String value}) {
    return '在除法后使当前值提高 $value%';
  }

  @override
  String itemDetailModifierReduceCurrentValueAfterDivision({required String value}) {
    return '在除法后使当前值降低 $value%';
  }

  @override
  String itemDetailModifierAppliesBonusPercent({required String value}) {
    return '施加 $value% 加成';
  }

  @override
  String itemDetailModifierAppliesReductionPercent({required String value}) {
    return '施加 $value% 减益';
  }

  @override
  String get itemDetailModifierStackingPenaltyHint => '叠加惩罚会在实际应用前降低转换后的数值。';

  @override
  String itemDetailBuffSource({required int buffId}) {
    return '增益 $buffId';
  }

  @override
  String get itemDetailModifierSourceShip => '舰船';

  @override
  String itemDetailModifierSourceModule({required int index}) {
    return '模块 $index';
  }

  @override
  String itemDetailModifierSourceImplant({required int index}) {
    return '植入体 $index';
  }

  @override
  String itemDetailModifierSourceBooster({required int index}) {
    return '增效剂 $index';
  }

  @override
  String itemDetailModifierSourceSkill({required int index}) {
    return '技能 $index';
  }

  @override
  String itemDetailModifierSourceCharge({required int index}) {
    return '弹药 $index';
  }

  @override
  String get itemDetailModifierSourceCharacter => '角色';

  @override
  String get itemDetailModifierSourceStructure => '建筑';

  @override
  String get itemDetailModifierSourceTarget => '目标';

  @override
  String get itemDetailEffectOperatorPreAssign => '预赋值';

  @override
  String get itemDetailEffectOperatorPreMul => '预乘';

  @override
  String get itemDetailEffectOperatorPreDiv => '预除';

  @override
  String get itemDetailEffectOperatorAdd => '增加';

  @override
  String get itemDetailEffectOperatorSub => '减少';

  @override
  String get itemDetailEffectOperatorPostMul => '后乘';

  @override
  String get itemDetailEffectOperatorPostDiv => '后除';

  @override
  String get itemDetailEffectOperatorPercent => '百分比';

  @override
  String get itemDetailEffectOperatorPostAssign => '后赋值';

  @override
  String get itemDetailEffectCategoryPassive => '被动';

  @override
  String get itemDetailEffectCategoryOnline => '在线';

  @override
  String get itemDetailEffectCategoryActive => '激活';

  @override
  String get itemDetailEffectCategoryOverload => '过载';

  @override
  String get itemDetailEffectCategoryTarget => '目标';

  @override
  String get itemDetailEffectCategoryArea => '区域';

  @override
  String get itemDetailEffectCategoryDungeon => '副本';

  @override
  String get itemDetailEffectCategorySystem => '系统';

  @override
  String loadingTextExtractingBundle({required String archiveName}) {
    return '正在解压 $archiveName...';
  }

  @override
  String get dontShowAgain => '下次不再提示';

  @override
  String get showDetails => '显示详情';

  @override
  String get startupBundleUpdateTitle => '有可用的数据包更新';

  @override
  String get startupBundleUpdateSingleDescription => '有一个新的推荐数据包更新可用。请在数据包管理中查看后再下载。';

  @override
  String startupBundleUpdateMultipleDescription({required int count}) {
    return '有 $count 个推荐的数据包更新可用。请在数据包管理中查看后再下载。';
  }

  @override
  String startupBundleUpdateSummaryRecommended({required String firstId}) {
    return '$firstId 被推荐';
  }

  @override
  String startupBundleUpdateSummaryWithCount({required String firstId, required int moreCount}) {
    return '$firstId 及其他 $moreCount 个被推荐';
  }

  @override
  String get reportPageTitle => '报告与反馈';

  @override
  String get reportSectionGeneral => '通用反馈';

  @override
  String get reportTileGitHub => 'GitHub Issues';

  @override
  String get reportTileGitHubDescription => '通过 GitHub 提交 Issue 报告问题或提出建议。';

  @override
  String get reportTileTencentForm => '腾讯收集表';

  @override
  String get reportTileTencentFormDescription => '通过腾讯收集表提交反馈（中文用户）。';

  @override
  String get reportTileTencentSheet => '腾讯反馈汇总';

  @override
  String get reportTileTencentSheetDescription => '查看已提交反馈的汇总表格。';

  @override
  String get reportSectionCommunity => '社区交流';

  @override
  String get reportTileQQOfficial => 'EFA 官方 QQ 群';

  @override
  String get reportTileQQOfficialDescription => 'QQ 群聊 1031146601';

  @override
  String get reportSectionSecurity => '安全报告';

  @override
  String get reportTileSecurityEmail => '安全邮件';

  @override
  String get reportTileSecurityEmailDescription => '发送安全报告至 security@efa-tech.dev';

  @override
  String get reportTileSecurityQQ => '安全联系 QQ';

  @override
  String get reportTileSecurityQQDescription => '联系 QQ 3562377918';

  @override
  String get reportCopyQQSuccess => '已复制 QQ 号到剪贴板';

  @override
  String get reportCopyQQError => '复制 QQ 号到剪贴板失败';

  @override
  String get reportOpenError => '无法打开链接';

  @override
  String get workspaceTabReportTitle => '报告与反馈';
}
