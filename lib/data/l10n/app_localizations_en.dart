// THIS IS A GENERATED FILE, DO NOT EDIT.
// ALL YOUR CHANGES WILL BE DISCARDED.

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get hello => 'Hello';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get ok => 'Ok';

  @override
  String get save => 'Save';

  @override
  String get appTitle => 'EVE Fit Assistant';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get confirm => 'Confirm';

  @override
  String get showInfo => 'Show Info';

  @override
  String get copy => 'Copy';

  @override
  String get share => 'Share';

  @override
  String get dynamicConvert => 'Abyssal';

  @override
  String get dynamicRevert => 'Revert';

  @override
  String get dynamicSelectTitle => 'Select mutaplasmid';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String get loading => 'Loading...';

  @override
  String get applyAfterRestart => 'Apply after restart';

  @override
  String get useCategorySelectList => 'Category';

  @override
  String get useMarketGroupSelectList => 'Market Group';

  @override
  String get typeListReturnBehaviorPreviousPage => 'Previous Page';

  @override
  String get typeListReturnBehaviorExit => 'Exit List';

  @override
  String get highSlot => 'High Slot';

  @override
  String get midSlot => 'Mid Slot';

  @override
  String get lowSlot => 'Low Slot';

  @override
  String get rigSlot => 'Rig Slot';

  @override
  String get subsystemSlot => 'Subsystem';

  @override
  String get implantSlot => 'Implant';

  @override
  String get boosterSlot => 'Booster';

  @override
  String get serviceSlot => 'Service Slot';

  @override
  String get tacticalMode => 'Tactical Mode';

  @override
  String get drone => 'Drone';

  @override
  String get fighter => 'Fighter';

  @override
  String get charge => 'Charge';

  @override
  String get frontPageTitleWorkspace => 'Workspaces';

  @override
  String get frontPageTitleFitList => 'Fits';

  @override
  String get frontPageTitleCharacter => 'Character';

  @override
  String get frontPageTitleSetting => 'Settings';

  @override
  String get characterBuiltInProfiles => 'Built-in profiles';

  @override
  String get characterCustomProfiles => 'Custom profiles';

  @override
  String get characterCreateProfile => 'Create profile';

  @override
  String characterCreateProfileError({required String message}) {
    return 'Could not create profile: $message';
  }

  @override
  String get characterNewProfileName => 'New Character';

  @override
  String characterClonedProfileName({required String name}) {
    return '$name Copy';
  }

  @override
  String characterCloneProfileError({required String name, required String message}) {
    return 'Could not clone $name: $message';
  }

  @override
  String get characterNoCustomProfiles =>
      'No custom profiles yet. Create one from All V to start editing local skills.';

  @override
  String characterLastModified({required String time}) {
    return 'Modified $time';
  }

  @override
  String get characterDeleteProfileTitle => 'Delete profile';

  @override
  String characterDeleteProfileContent({required String name}) {
    return 'Delete $name? Fits using this profile will keep the profile id until you choose another one.';
  }

  @override
  String characterDeleteProfileError({required String name, required String message}) {
    return 'Could not delete $name: $message';
  }

  @override
  String get characterProfileInfoTab => 'Info';

  @override
  String get characterProfileNameLabel => 'Character name';

  @override
  String get characterProfileDescriptionLabel => 'Description';

  @override
  String get characterProfileNameRequired => 'Please enter a character name.';

  @override
  String get characterSkillAllGroups => 'All skill groups';

  @override
  String get workspaceTabActionCreateFitName => 'Create Fit';

  @override
  String get bundleAccessRequiredTitle => 'Bundle required';

  @override
  String get bundleAccessNotSelectedDescription =>
      'Fit creation and import stay disabled until you select an active data bundle.';

  @override
  String get bundleAccessLoadingDescription =>
      'The current data bundle is still loading. Wait for it to finish, then try again.';

  @override
  String get bundleAccessInvalidDescription =>
      'The current data bundle is incomplete or invalid. Import a valid archive or switch bundles before continuing.';

  @override
  String get bundleAccessReadyDescription => 'The active data bundle is ready.';

  @override
  String get bundleAccessManageAction => 'Open Bundle Manager';

  @override
  String startupPersistenceRepairSummary({required String details}) {
    return 'Recovered local storage: $details.';
  }

  @override
  String startupPersistenceRepairSummaryWithWarnings({
    required String details,
    required int unreadableCount,
  }) {
    return 'Recovered local storage: $details. $unreadableCount fit files still need manual cleanup.';
  }

  @override
  String get startupPersistenceRepairFoundUnreadableFits => 'detected unreadable fit files';

  @override
  String get startupPersistenceRepairRebuiltMetadata => 'rewrote local metadata';

  @override
  String startupPersistenceRepairRemovedMissingFits({required int count}) {
    return 'removed $count missing fits';
  }

  @override
  String startupPersistenceRepairRestoredFits({required int count}) {
    return 'restored $count saved fits';
  }

  @override
  String startupPersistenceRepairRemovedMissingBundles({required int count}) {
    return 'removed $count missing bundle entries';
  }

  @override
  String startupPersistenceRepairRestoredBundles({required int count}) {
    return 'recovered $count installed bundles';
  }

  @override
  String get startupPersistenceRepairUpdatedSelectedBundle => 'updated the selected bundle';

  @override
  String get settingTileAppSettingsTitle => 'App Settings';

  @override
  String get settingTileRemoteContentTitle => 'Remote Content';

  @override
  String get settingTileBundleManagerTitle => 'Data Bundle';

  @override
  String get settingTileVersionTitle => 'Version';

  @override
  String get settingTileVersionSubtitle => 'Release notes and changelog';

  @override
  String get appSettingsPageSectionBundle => 'Data bundle';

  @override
  String get appSettingsPageBundleImpactWarningTitle => 'Bundle impact warnings';

  @override
  String get appSettingsPageBundleImpactWarningDescription =>
      'Warn before switching bundles or importing incremental patches when saved fits or characters may be affected.';

  @override
  String get bundleImpactDisableConfirmTitle => 'Disable bundle impact warnings?';

  @override
  String get bundleImpactDisableConfirmDescription =>
      'Bundle switches and incremental patch imports will continue without warning until you enable this setting again.';

  @override
  String get bundleImpactWarningTitle => 'Potential bundle impacts';

  @override
  String bundleImpactSwitchWarningDescription({required Object bundleId}) {
    return 'Switching to bundle $bundleId may affect saved local data.';
  }

  @override
  String bundleImpactIncrementalWarningDescription({required Object bundleId}) {
    return 'Importing this incremental patch for bundle $bundleId may affect saved local data.';
  }

  @override
  String get bundleImpactContinueAction => 'Continue';

  @override
  String bundleImpactFitsSummary({required Object count}) {
    return '$count fits are influenced';
  }

  @override
  String bundleImpactCharactersSummary({required Object count}) {
    return '$count characters are influenced';
  }

  @override
  String get bundleImpactBundleDataSummary => 'Bundle data will be updated';

  @override
  String get bundleImpactDetailPageTitle => 'Bundle impacts';

  @override
  String bundleImpactDetailDescription({required Object bundleId}) {
    return 'Potential impacts when using bundle $bundleId.';
  }

  @override
  String get bundleImpactNoImpacts => 'No local impacts were found.';

  @override
  String get bundleImpactFitsSection => 'Fits';

  @override
  String get bundleImpactCharactersSection => 'Characters';

  @override
  String get bundleImpactBundleDataSection => 'Bundle data';

  @override
  String get bundleImpactSavedBundleLabel => 'Saved bundle: ';

  @override
  String get bundleImpactTargetBundleLabel => 'Target bundle: ';

  @override
  String get bundleImpactReasonLabel => 'Reason: ';

  @override
  String get bundleImpactReasonBundleMismatch => 'Bundle id differs';

  @override
  String get bundleImpactReasonMissingRevision => 'Comparable revision metadata is missing';

  @override
  String get bundleImpactReasonManifestMismatch => 'Manifest hash differs';

  @override
  String get bundleImpactReasonGenerationMismatch => 'Generation timestamp differs';

  @override
  String get bundleImpactReasonBuildMismatch => 'Game build differs';

  @override
  String get bundleImpactReasonAppVersionMismatch => 'App version differs';

  @override
  String get bundleImpactReasonIncrementalPatch => 'Incremental patch contains changes';

  @override
  String get bundleImpactReasonFullReplacement => 'Full replacement contains changes';

  @override
  String get workspaceTabAnnouncementTitle => 'Updates';

  @override
  String get documentAnnouncementPageTitle => 'Updates';

  @override
  String get documentVersionPageTitle => 'Version';

  @override
  String get documentAnnouncementEmptyTitle => 'No updates yet';

  @override
  String get documentVersionEmptyTitle => 'No version notes yet';

  @override
  String get documentEmptyDescription =>
      'Bundled announcements, information entries, and version notes appear here, and future online updates can still be separated by source.';

  @override
  String get documentLoadErrorTitle => 'Unable to load documents';

  @override
  String get documentLoadErrorDescription => 'Try again later or restart the app.';

  @override
  String get documentSelectPrompt => 'Select an entry to read its content.';

  @override
  String get documentKindAnnouncement => 'Announcement';

  @override
  String get documentKindInformation => 'Information';

  @override
  String get documentKindVersion => 'Version';

  @override
  String get documentOpenHint => 'Open to read';

  @override
  String documentVersionBadge({required String version}) {
    return 'App $version';
  }

  @override
  String get documentMarkAllRead => 'Mark all read';

  @override
  String get documentMarkAllUnread => 'Mark all unread';

  @override
  String documentMinAppVerWarning({required String version}) {
    return 'Requires app v$version or above';
  }

  @override
  String versionBumpCardTitle({required String version}) {
    return 'What\'s new in v$version';
  }

  @override
  String versionBumpCardSubtitle({required int count}) {
    return '$count new updates';
  }

  @override
  String get versionBumpCardCloseTooltip => 'Close';

  @override
  String get versionBumpCardSubtitleFallback => 'See version notes';

  @override
  String get fitCreationPageTitle => 'Create New Fit';

  @override
  String fitCreationPageDialogHint({required int count}) {
    return 'New Fit $count';
  }

  @override
  String get fitCreationPageDialogErrorText => 'Please enter fit name.';

  @override
  String get fitCreationPageDialogDeleteFitTitle => 'Delete Fit';

  @override
  String fitCreationPageDialogDeleteFitContent({required String fitName}) {
    return 'Are you sure you want to delete fit $fitName?';
  }

  @override
  String fitPageTitle({required String fitName, required String shipName}) {
    return '$fitName - $shipName';
  }

  @override
  String get fitPageUnavailableTitle => 'Fit unavailable';

  @override
  String get fitPageMissingMessage => 'This fit could not be found.';

  @override
  String get fitPageBrokenMessage => 'This fit could not be loaded.';

  @override
  String get fitPageShipUnavailableMessage =>
      'This fit references ship data that is not available in the current bundle.';

  @override
  String get fitBundleChangedTitle => 'Bundle changed';

  @override
  String get fitBundleChangedDescription =>
      'This fit was saved against an older revision of the active bundle. You can inspect and export it, but editing stays disabled until you re-import a compatible bundle revision or recreate the fit under the current data set.';

  @override
  String get fitBundleLegacyTitle => 'Bundle check required';

  @override
  String get fitBundleLegacyDescription =>
      'This fit was saved before bundle revision tracking was available. You can inspect and export it, but editing stays disabled until you reopen it from compatible bundle data or recreate it under the current bundle.';

  @override
  String get fitBundleMismatchTitle => 'Bundle mismatch';

  @override
  String fitBundleMismatchDescription({
    required String savedBundleId,
    required String activeBundleId,
  }) {
    return 'This fit was saved against bundle $savedBundleId, but the active bundle is $activeBundleId. You can inspect and export it, but editing stays disabled.';
  }

  @override
  String fitBundleMismatchSwitchDescription({
    required String savedBundleId,
    required String activeBundleId,
  }) {
    return 'This fit was saved against bundle $savedBundleId, but the active bundle is $activeBundleId. Switch back to $savedBundleId to edit it as-is, or export and import it again after reviewing the current bundle data if you want a new editable copy here.';
  }

  @override
  String fitBundleMismatchImportDescription({
    required String savedBundleId,
    required String activeBundleId,
  }) {
    return 'This fit was saved against bundle $savedBundleId, but the active bundle is $activeBundleId. Re-import bundle $savedBundleId to edit this fit as-is, or export and import it again under the current bundle if you want to migrate it.';
  }

  @override
  String get fitBundleSwitchLabel => 'Switch bundle to edit';

  @override
  String get fitBundleImportLabel => 'Re-import bundle data';

  @override
  String get fitBundleSwitchAction => 'Switch bundle';

  @override
  String get fitBundleSwitchErrorMessage => 'Could not switch bundles. Keeping the current bundle.';

  @override
  String get fitBundleOpenManagerAction => 'Open bundle manager';

  @override
  String get fitBundleUnavailableTitle => 'Bundle unavailable';

  @override
  String get fitBundleUnavailableDescription =>
      'No active bundle is loaded, so compatibility cannot be confirmed. Fit editing stays disabled until a bundle is available.';

  @override
  String fitBundleUnavailableSwitchDescription({required String savedBundleId}) {
    return 'No active bundle is loaded. Select bundle $savedBundleId to edit this fit again, or leave it read-only until you are ready to switch the app\'s data context.';
  }

  @override
  String get fitBundleUnavailableImportDescription =>
      'No active bundle is loaded, and this fit\'s saved bundle is not installed. Import the required bundle data from Bundle Manager before editing, or recreate the fit under a currently available bundle.';

  @override
  String get fitPageStatsUnavailableTitle => 'Stats unavailable';

  @override
  String get fitPageStatsUnavailableMessage =>
      'You can still inspect and edit the fit while calculations recover.';

  @override
  String get fitPageSaveErrorTitle => 'Changes not saved';

  @override
  String get fitPageSaveErrorMessage => 'The latest fit changes could not be saved.';

  @override
  String get fitPageReadOnlyMessage =>
      'This fit stays read-only until a compatible bundle is active.';

  @override
  String get fitPageRetryAction => 'Retry';

  @override
  String get fitPageBackAction => 'Back';

  @override
  String get fitIssueDialogTitle => 'Fit issues';

  @override
  String fitIssueMissingDynamic({required String slotName, required int index}) {
    return '$slotName #$index references missing dynamic item data.';
  }

  @override
  String fitIssueMissingItemType({required String slotName, required int index}) {
    return '$slotName #$index references item data that is not available.';
  }

  @override
  String fitIssueMissingChargeType({required String slotName, required int index}) {
    return '$slotName #$index references charge data that is not available.';
  }

  @override
  String get fitIssueIncompatibleChargeSize => 'Charge size does not match.';

  @override
  String fitIssueIncompatibleChargeSizeDetails({required String expected, required String actual}) {
    return 'Expected $expected; actual $actual.';
  }

  @override
  String get fitIssueIncompatibleChargeCapacity => 'Charge volume exceeds module capacity.';

  @override
  String fitIssueIncompatibleChargeCapacityDetails({required String max, required String actual}) {
    return 'Maximum $max m³; actual $actual m³.';
  }

  @override
  String get fitIssueIncompatibleChargeGroup => 'Charge type is not accepted by this module.';

  @override
  String fitIssueIncompatibleChargeGroupDetails({
    required String expected,
    required String actual,
  }) {
    return 'Expected charge group: $expected; actual $actual.';
  }

  @override
  String get fitIssueTooMuchTurret => 'Too many turrets fitted.';

  @override
  String fitIssueTooMuchTurretDetails({required int expected, required int actual}) {
    return 'Maximum $expected; actual $actual.';
  }

  @override
  String get fitIssueTooMuchLauncher => 'Too many launchers fitted.';

  @override
  String fitIssueTooMuchLauncherDetails({required int expected, required int actual}) {
    return 'Maximum $expected; actual $actual.';
  }

  @override
  String get fitIssueConflictItem => 'Conflicting active modules.';

  @override
  String fitIssueConflictItemDetails({required String groupName}) {
    return 'More than one active module from group $groupName is enabled.';
  }

  @override
  String get fitIssueDuplicateBooster => 'Duplicate booster slot.';

  @override
  String fitIssueDuplicateBoosterDetails({required int slot}) {
    return 'Booster slot $slot is already occupied.';
  }

  @override
  String get fitIssueIncompatibleShipGroup => 'Item cannot be fitted to this ship group.';

  @override
  String fitIssueIncompatibleShipGroupDetails({required String expected}) {
    return 'Expected ship group: $expected.';
  }

  @override
  String get fitIssueIncompatibleShipType => 'Item cannot be fitted to this ship type.';

  @override
  String fitIssueIncompatibleShipTypeDetails({required String expected}) {
    return 'Expected ship type: $expected.';
  }

  @override
  String get fitIssueIncompatibleRigSize => 'Rig size does not match.';

  @override
  String fitIssueIncompatibleRigSizeDetails({required String expected, required String actual}) {
    return 'Expected $expected; actual $actual.';
  }

  @override
  String get fitIssueMissingCharge => 'Charge is missing.';

  @override
  String get fitIssueUnknownValidationIssue => 'Unknown validation issue.';

  @override
  String get fitTabsCharacter => 'Char';

  @override
  String get fitTabsEquipment => 'Equip';

  @override
  String get fitTabsAttributes => 'Attrib';

  @override
  String get fitTabsDrone => 'Drone';

  @override
  String get fitTabsFighter => 'Fighter';

  @override
  String get fitTabsUtils => 'Utils';

  @override
  String fitSkillPolicyPresetTitle({required String profileName}) {
    return 'Skill profile: $profileName';
  }

  @override
  String get fitSkillPolicyPresetDescription =>
      'This build uses preset skill profiles instead of real character data.';

  @override
  String get fitSkillProfileAll5 => 'All V';

  @override
  String get fitSkillProfileAlphaMax => 'Alpha Max';

  @override
  String get fitSkillProfileAll0 => 'All 0';

  @override
  String get fitSkillPolicyUnsupportedTitle =>
      'Skill-aware simulation is not available in this build.';

  @override
  String get fitSkillPolicyUnsupportedDescription =>
      'Fits are simulated without character skill modifiers. Implants and boosters still apply.';

  @override
  String fitAddItemDialogTitle({required String slotName}) {
    return 'Add Item: $slotName';
  }

  @override
  String fitAddItemDialogTitleWithIndex({required String slotName, required int index}) {
    return 'Add Item: $slotName #$index';
  }

  @override
  String fitSlotEmpty({required String slotName}) {
    return '$slotName (Empty)';
  }

  @override
  String get fitActionFill => 'Fill';

  @override
  String get fitActionSet => 'Set';

  @override
  String fitUnknownImplantAtSlot({required int slot}) {
    return 'Implant unavailable at slot $slot';
  }

  @override
  String fitUnknownImplant({required int typeId}) {
    return 'Implant unavailable ($typeId)';
  }

  @override
  String fitUnknownBoosterAtSlot({required int slot}) {
    return 'Booster unavailable at slot $slot';
  }

  @override
  String fitUnknownBooster({required int typeId}) {
    return 'Booster unavailable ($typeId)';
  }

  @override
  String fitUnknownItemAtSlot({required int slot}) {
    return 'Item data unavailable at slot $slot';
  }

  @override
  String fitUnknownItemWithIdAtSlot({required int itemId, required int slot}) {
    return 'Item data unavailable ($itemId) at slot $slot';
  }

  @override
  String fitUnknownFighterAtSlot({required int slot}) {
    return 'Fighter data unavailable at slot $slot';
  }

  @override
  String fitUnknownFighterWithIdAtSlot({required int itemId, required int slot}) {
    return 'Fighter data unavailable ($itemId) at slot $slot';
  }

  @override
  String fitUnknownShip({required int typeId}) {
    return 'Ship data unavailable ($typeId)';
  }

  @override
  String fitUnknownSubsystemAtSlot({required int slot}) {
    return 'Subsystem data unavailable at slot $slot';
  }

  @override
  String fitUnknownSubsystemWithIdAtSlot({required int itemId, required int slot}) {
    return 'Subsystem data unavailable ($itemId) at slot $slot';
  }

  @override
  String fitUnknownTacticalMode({required int typeId}) {
    return 'Tactical mode unavailable ($typeId)';
  }

  @override
  String get fitUtilsNameRequired => 'Fit name is required';

  @override
  String get fitUtilsExportButton => 'Export fit';

  @override
  String get fitUtilsExportImageButton => 'Export image';

  @override
  String get fitUtilsNameLabel => 'Fit name';

  @override
  String get fitUtilsDescriptionLabel => 'Description';

  @override
  String get fitExportDialogTitle => 'Export fit';

  @override
  String get fitExportLoadError => 'Unable to load this fit for export.';

  @override
  String get fitExportFormatNative => 'EFA native code';

  @override
  String get fitExportFormatNativeDescription =>
      'Full-fidelity export for sharing with another EVE Fit Assistant installation.';

  @override
  String get fitExportFormatFittingLink => 'In-game fitting link';

  @override
  String get fitExportFormatFittingLinkDescription =>
      'Copy a fitting link that can be pasted into EVE. Modules, charges, drones, and fighters are preserved where the game format supports them.';

  @override
  String get fitExportFormatEft => 'EFT text';

  @override
  String get fitExportFormatEftDescription =>
      'Copy EFT text for tools such as pyfa and other text-based fitting workflows.';

  @override
  String get fitExportLossyWarning =>
      'This export format is lossy and does not preserve every fit detail.';

  @override
  String get fitExportCopied => 'Fit export copied to clipboard.';

  @override
  String get fitExportClipboardError => 'Unable to copy this fit export right now.';

  @override
  String get fitExportShareError => 'Unable to share this fit export right now.';

  @override
  String get fitListActionExport => 'Export';

  @override
  String get fitListActionImport => 'Import';

  @override
  String get fitImportDialogTitle => 'Import fit';

  @override
  String get fitImportDialogDescription =>
      'Paste exported fit text below. App-native EFA codes and EFT text are supported in this first import flow.';

  @override
  String get fitImportInputLabel => 'Fit text';

  @override
  String get fitImportPasteButton => 'Paste';

  @override
  String get fitImportConfirmButton => 'Import';

  @override
  String get fitImportErrorEmpty => 'Paste fit text before importing.';

  @override
  String get fitImportErrorUnsupportedFormat => 'This text is not a supported fit import format.';

  @override
  String get fitImportErrorUnsupportedFittingLink =>
      'In-game fitting links are not supported for import in this release.';

  @override
  String get fitImportErrorUnsupportedNativeVersion =>
      'This EFA export was created by a newer app version and cannot be imported here yet.';

  @override
  String get fitImportErrorInvalidNativePayload => 'This EFA export is damaged or incomplete.';

  @override
  String get fitImportErrorInvalidEft =>
      'This EFT text is invalid or uses sections that are not supported in this release.';

  @override
  String fitImportErrorUnknownType({required String typeName}) {
    return 'The current data bundle does not recognize \"$typeName\".';
  }

  @override
  String fitImportErrorUnavailableShip({required String shipName}) {
    return 'The ship \"$shipName\" is not available in the current data bundle.';
  }

  @override
  String get fitImportErrorUnavailableData =>
      'Fit import data is not available right now. Try again after the app finishes loading its bundle.';

  @override
  String fitImportSuccess({required String fitName}) {
    return 'Imported $fitName';
  }

  @override
  String get fitImportUnknownError => 'Unable to import this fit.';

  @override
  String get fitScreenshotPageTitle => 'Fit image export';

  @override
  String get fitScreenshotSave => 'Save image';

  @override
  String get fitScreenshotShare => 'Share image';

  @override
  String fitScreenshotSaved({required String path}) {
    return 'Saved screenshot to $path';
  }

  @override
  String get fitScreenshotDamageProfile => 'Damage profile';

  @override
  String get fitScreenshotEquipment => 'Equipment';

  @override
  String get fitScreenshotSupport => 'Implants & boosters';

  @override
  String get fitScreenshotMinions => 'Drones & fighters';

  @override
  String get fitScreenshotStats => 'Quick stats';

  @override
  String get fitScreenshotEmpty => 'None';

  @override
  String get fitScreenshotStatsUnavailable => 'Stats unavailable';

  @override
  String get fitScreenshotFighterCapacity => 'Fighter capacity';

  @override
  String get fitScreenshotShieldHp => 'Shield HP';

  @override
  String get fitScreenshotArmorHp => 'Armor HP';

  @override
  String get fitScreenshotHullHp => 'Hull HP';

  @override
  String get fitScreenshotCapacitor => 'Capacitor';

  @override
  String get fitScreenshotDroneBandwidth => 'Drone bandwidth';

  @override
  String fitAttributeTabCapacitorStable({required String percent}) {
    return '$percent% Stable';
  }

  @override
  String get fitFighterAbilityTurret => 'Turret';

  @override
  String get fitFighterAbilityMissiles => 'Missiles';

  @override
  String get fitFighterAbilityVolley => 'Volley';

  @override
  String get fitFighterAbilityBomb => 'Bomb';

  @override
  String get fitDroneTabAddDroneTitle => 'Add Drone';

  @override
  String get appSettingsPageTitle => 'App Settings';

  @override
  String get appSettingsPageSectionGeneral => 'General';

  @override
  String get appSettingsPageLocaleTitle => 'Locale';

  @override
  String get appSettingsPageLocaleSubtitle => 'Select Locale';

  @override
  String get appSettingsPageFontScaleTitle => 'Font Scale';

  @override
  String get appSettingsPageFontScaleDescription =>
      'Adjust the app text scale. Changes apply immediately.';

  @override
  String get appSettingsPageFontScaleXS => 'XS';

  @override
  String get appSettingsPageFontScaleS => 'S';

  @override
  String get appSettingsPageFontScaleM => 'M';

  @override
  String get appSettingsPageFontScaleL => 'L';

  @override
  String get appSettingsPageFontScaleXL => 'XL';

  @override
  String get appSettingsPageSectionSelectList => 'Display List';

  @override
  String get appSettingsPageShipSelectTypeTitle => 'Ship Select List Type';

  @override
  String get appSettingsPageShipSelectTypeDescription =>
      'The list format used when selecting ships.\nCategory grouping organizes ships based on in-game item categories.\nMarket group grouping organizes ships based on market groups.';

  @override
  String get appSettingsPageListReturnBehaviorTitle => 'List Back Action';

  @override
  String get appSettingsPageListReturnBehaviorDescription =>
      'Choose what the system back action does inside nested selector lists. Previous Page steps back through list groups before closing. Exit List closes the selector immediately.';

  @override
  String get appSettingsPageSectionRemoteContent => 'Remote Content';

  @override
  String get appSettingsPageRemoteContentPanelVisibleTitle => 'Show Remote Content Settings';

  @override
  String get appSettingsPageRemoteContentVisibleTitle => 'Show Remote Content Entry';

  @override
  String get appSettingsPageRemoteContentVisibleDescription =>
      'Show or hide the Remote Content entry on the Settings page.';

  @override
  String get appSettingsPageRemoteContentOpenTitle => 'Open Remote Content Settings';

  @override
  String get appSettingsPageRemoteContentOpenDescription =>
      'Configure remote content runtime parameters.';

  @override
  String get appSettingsPageRemoteContentWarningTitle => 'Open remote content settings?';

  @override
  String get appSettingsPageRemoteContentWarningDescription =>
      'Remote content settings are experimental and can affect future document, release, and bundle metadata discovery. Continue only if you know what endpoint to use.';

  @override
  String get appSettingsPageRemoteContentEnabledTitle => 'Enable Remote Content';

  @override
  String get appSettingsPageRemoteContentEnabledDescription =>
      'Allow the app to discover documents, releases, and bundle metadata from a configured remote origin when runtime sync is available.';

  @override
  String get appSettingsPageRemoteContentEndpointTitle => 'Remote Content Endpoint';

  @override
  String appSettingsPageRemoteContentEndpointDescription({
    required String origin,
    required String resourceRoot,
    required String channel,
  }) {
    return 'Origin: $origin\nRoot: $resourceRoot\nChannel: $channel';
  }

  @override
  String get appSettingsPageRemoteContentNotSet => 'Not set';

  @override
  String get appSettingsPageRemoteContentOriginUrlLabel => 'Origin URL';

  @override
  String get appSettingsPageRemoteContentResourceRootLabel => 'Resource Root';

  @override
  String get appSettingsPageRemoteContentChannelLabel => 'Channel';

  @override
  String get appSettingsPageRemoteContentChannelTesting => 'Testing';

  @override
  String get appSettingsPageRemoteContentChannelStable => 'Stable';

  @override
  String get appSettingsPageCollectLogsEntryTitle => 'Collect Logs';

  @override
  String get appSettingsPageCollectLogsEntryDescription =>
      'Select and share application logs for debugging and issue reporting';

  @override
  String get collectLogsPageTitle => 'Collect Logs';

  @override
  String get collectLogsQuickFilter => 'Quick filter';

  @override
  String get collectLogsFilterAll => 'All';

  @override
  String get collectLogsFilter1Hour => '1h';

  @override
  String get collectLogsFilter24Hours => '24h';

  @override
  String get collectLogsFilter7Days => '7d';

  @override
  String get collectLogsFilter30Days => '30d';

  @override
  String get collectLogsFileActive => '(active)';

  @override
  String get collectLogsNoLogFiles => 'No log files found';

  @override
  String get collectLogsShareButton => 'Share';

  @override
  String collectLogsTotalSize({required String size, required int count}) {
    return '$size across $count files';
  }

  @override
  String get collectLogsLoadError => 'Failed to load log files';

  @override
  String get appSettingsPageSectionDeveloper => 'Developer';

  @override
  String get appSettingsPageDebugLogTitle => 'Enable Debug Log';

  @override
  String get appSettingsPageDebugLogDescription =>
      'The application will print all logs to the logging directory when this feature is activated.\nIt\'s suggested not to enable this unless a developer requires the activation.';

  @override
  String get bundleManagerPageTitle => 'Bundle Manager';

  @override
  String get bundleImportOverwriteTitle => 'Replace existing bundle?';

  @override
  String get bundleManagerBundleAppVersion => 'App Version: ';

  @override
  String get bundleManagerBundleBuild => 'Build: ';

  @override
  String get bundleManagerBundleGameVersion => 'Game Version: ';

  @override
  String get bundleManagerBundleServer => 'Server: ';

  @override
  String get bundleManagerBundleRegion => 'Region: ';

  @override
  String get bundleManagerBundleBranch => 'Branch: ';

  @override
  String bundleManagerBundleSchemaVersion({required int num}) {
    return 'Schema v$num';
  }

  @override
  String get bundleManagerDeleteBundleConfirmTitle => 'Delete Bundle';

  @override
  String bundleManagerDeleteBundleConfirmContent({required String bundleId}) {
    return 'Do you want to delete bundle $bundleId?';
  }

  @override
  String get bundleManagerDeleteBundleInUseWarning =>
      'This bundle is currently in use, deleting it may cause some features to not work properly.';

  @override
  String get bundleManagerDetailPageTitle => 'Bundle Info';

  @override
  String get bundleManagerDetailSectionTitleLatestPatch => 'Latest Patch';

  @override
  String get bundleManagerDetailSectionTitleHistory => 'History';

  @override
  String get bundleManagerDetailVariantFull => 'FULL';

  @override
  String get bundleManagerDetailVariantIncremental => 'INCREMENTAL';

  @override
  String get bundleManagerDetailGeneratedAt => 'Generated At: ';

  @override
  String get bundleManagerDetailLoadedAt => 'Loaded At: ';

  @override
  String get bundleVerificationTitle => 'Verification';

  @override
  String get bundleVerificationAction => 'Verify installed files';

  @override
  String get bundleVerificationConfirmTitle => 'Verify installed bundle files?';

  @override
  String get bundleVerificationConfirmMessage =>
      'This will read installed bundle files and compare their size and SHA-256 hashes against the local manifest. It may take a while for large bundles. No files will be changed.';

  @override
  String get bundleVerificationValid => 'Installed files match the local manifest.';

  @override
  String get bundleVerificationWarning => 'Verification completed with warnings.';

  @override
  String get bundleVerificationInvalid => 'Verification found bundle integrity problems.';

  @override
  String get bundleVerificationNeverRun => 'Verification has not run yet.';

  @override
  String bundleVerificationCheckedAt({required String time}) {
    return 'Checked at: $time';
  }

  @override
  String bundleVerificationMissingFiles({required int count}) {
    return 'Missing: $count';
  }

  @override
  String bundleVerificationHashMismatches({required int count}) {
    return 'Hash mismatches: $count';
  }

  @override
  String bundleVerificationSizeMismatches({required int count}) {
    return 'Size mismatches: $count';
  }

  @override
  String bundleVerificationExtraFiles({required int count}) {
    return 'Extra files: $count';
  }

  @override
  String bundleVerificationMoreIssues({required int count}) {
    return '+$count more issue(s)';
  }

  @override
  String get bundleVerificationRemoteRepairUnavailable =>
      'Remote repair is unavailable until matching remote bundle metadata is available.';

  @override
  String bundleVerificationIssueMissingManifest({required String path}) {
    return 'Missing manifest: $path';
  }

  @override
  String bundleVerificationIssueInvalidManifest({required String path, required String error}) {
    return 'Invalid manifest $path: $error';
  }

  @override
  String get bundleVerificationIssueManifestHashMissing =>
      'Registrar does not record the latest manifest hash.';

  @override
  String bundleVerificationIssueManifestHashMismatch({
    required String expected,
    required String actual,
  }) {
    return 'Manifest hash mismatch: expected $expected, got $actual';
  }

  @override
  String bundleVerificationIssueUnsafeManifestPath({required String path}) {
    return 'Unsafe manifest path: $path';
  }

  @override
  String bundleVerificationIssueMissingFile({required String path}) {
    return 'Missing file: $path';
  }

  @override
  String bundleVerificationIssueSizeMismatch({
    required String path,
    required int expected,
    required int actual,
  }) {
    return 'Size mismatch for $path: expected $expected, got $actual';
  }

  @override
  String bundleVerificationIssueHashMismatch({
    required String path,
    required String expected,
    required String actual,
  }) {
    return 'Hash mismatch for $path: expected $expected, got $actual';
  }

  @override
  String bundleVerificationIssueExtraFile({required String path}) {
    return 'Extra file: $path';
  }

  @override
  String bundleVerificationIssueReadError({required String path, required String error}) {
    return 'Read error for $path: $error';
  }

  @override
  String bundleVerificationIssueUnsupportedSchemaVersion({
    required int version,
    required int min,
    required int max,
  }) {
    return 'Bundle schema v$version is not supported (supported: v$min–v$max).';
  }

  @override
  String bundleVerificationIssueSchemaVersionMismatch({
    required int version,
    required int current,
  }) {
    return 'Bundle schema v$version differs from current app schema v$current.';
  }

  @override
  String get bundleManagerSetupTitle => 'Import your first bundle';

  @override
  String get bundleManagerSetupDescription =>
      'The app needs one valid data bundle before fitting and related tools can load. Import a bundle archive to get started.';

  @override
  String get bundleManagerAlphaScope =>
      'Alpha scope: you can install multiple bundles, but only one bundle is active across the app at a time.';

  @override
  String get bundleManagerImportSelectionBehavior =>
      'Importing a bundle keeps the current active bundle. Select another installed bundle below only when you want to switch the app\'s data context.';

  @override
  String get bundleManagerSelectionTitle => 'Select an active bundle';

  @override
  String get bundleManagerSelectionDescription =>
      'Choose one of the installed bundles below, or import a newer archive if you need to recover your data.';

  @override
  String get bundleManagerLoadingTitle => 'Loading bundle';

  @override
  String bundleManagerLoadingDescription({required String bundleId}) {
    return 'Preparing bundle $bundleId for use.';
  }

  @override
  String get bundleManagerInvalidTitle => 'Bundle needs attention';

  @override
  String get bundleManagerInvalidDescription =>
      'The selected bundle is missing required files or metadata. Import a valid archive or switch to another installed bundle.';

  @override
  String get bundleManagerReadyTitle => 'Bundle ready';

  @override
  String bundleManagerReadyDescription({required String bundleId}) {
    return 'Active bundle: $bundleId';
  }

  @override
  String get bundleManagerImportAction => 'Import bundle';

  @override
  String get bundleRemoteSectionTitle => 'Remote bundles';

  @override
  String get bundleRemoteSectionDescription =>
      'Discover compatible bundle archives from the configured remote content endpoint. Downloads start only after you choose one.';

  @override
  String get bundleRemoteRefreshAction => 'Refresh remote bundles';

  @override
  String get bundleRemoteEmpty => 'No compatible remote bundles are available.';

  @override
  String get bundleRemoteChecking => 'Checking the remote bundle catalog...';

  @override
  String get bundleRemoteCatalogMissing =>
      'The remote index does not advertise a bundle catalog for this channel.';

  @override
  String get bundleRemoteCatalogEmpty => 'The remote bundle catalog is empty.';

  @override
  String get bundleRemoteAlternativesOnly =>
      'Remote bundles are available, but none is preferred over the current installed state. Review the alternatives before downloading.';

  @override
  String get bundleRemoteCurrent =>
      'The installed bundle already matches the latest compatible remote artifact.';

  @override
  String get bundleRemoteNoImportable =>
      'Remote bundle metadata was found, but no artifact can be imported on this device right now.';

  @override
  String get bundleRemoteReviewAction => 'Review bundles';

  @override
  String get bundleRemoteDownloadRecommendedAction => 'Download recommended';

  @override
  String get bundleRemoteSelectionPageTitle => 'Remote Bundles';

  @override
  String get bundleRemoteDisabled =>
      'Remote content is disabled. Enable it in Remote Content settings before reviewing remote bundles.';

  @override
  String bundleRemoteRecommendedCount({required int count}) {
    return 'Recommended: $count';
  }

  @override
  String bundleRemoteAvailableCount({required int count}) {
    return 'Available: $count';
  }

  @override
  String bundleRemoteInstalledCount({required int count}) {
    return 'Installed: $count';
  }

  @override
  String bundleRemoteUnavailableCount({required int count}) {
    return 'Unavailable: $count';
  }

  @override
  String get bundleRemoteRecommendedSection => 'Recommended';

  @override
  String get bundleRemoteRecommendedSectionDescription =>
      'Best next downloads for installed bundles based on manifest metadata. Older artifacts for the same bundle stay as alternatives.';

  @override
  String get bundleRemoteAvailableSection => 'Available alternatives';

  @override
  String get bundleRemoteAvailableSectionDescription =>
      'Importable full bundles or patches that are not the top recommendation.';

  @override
  String get bundleRemoteInstalledSection => 'Already installed';

  @override
  String get bundleRemoteInstalledSectionDescription =>
      'Remote artifacts that match an installed bundle manifest.';

  @override
  String get bundleRemoteUnavailableSection => 'Unavailable';

  @override
  String get bundleRemoteUnavailableSectionDescription =>
      'Artifacts that cannot be imported because app version or installed base metadata does not match.';

  @override
  String get bundleRemoteSelectionSummaryTitle => 'Selection guidance';

  @override
  String get bundleRemoteSelectionSummaryDescription =>
      'Incremental patches are preferred when they match an installed base manifest. Full bundles remain available for manual new installs or replacements.';

  @override
  String bundleRemoteRecommendationIncremental({required String bundleId}) {
    return 'Recommended incremental update for $bundleId.';
  }

  @override
  String bundleRemoteRecommendationFullInstall({required String bundleId}) {
    return 'Recommended full bundle for new install: $bundleId.';
  }

  @override
  String bundleRemoteRecommendationFullReplacement({required String bundleId}) {
    return 'No matching incremental path is available; use the full replacement for $bundleId.';
  }

  @override
  String get bundleRemoteRecommendedFallback => 'Recommended remote bundle.';

  @override
  String get bundleRemoteAvailableDescription => 'This artifact can be downloaded and imported.';

  @override
  String get bundleRemoteInstalledDescription =>
      'This artifact already exists in the installed bundle history.';

  @override
  String get bundleRemoteUnknownAppVersion => 'unknown';

  @override
  String bundleRemoteUnavailableAppVersion({
    required String requiredVersion,
    required String currentVersion,
  }) {
    return 'Requires app version $requiredVersion; current app is $currentVersion.';
  }

  @override
  String bundleRemoteUnavailableIncompatibleSchema({required int version}) {
    return 'Bundle schema v$version is not supported by this app version.';
  }

  @override
  String get bundleRemoteUnavailableMissingIncrementalMetadata =>
      'Incremental artifact is missing base bundle metadata.';

  @override
  String bundleRemoteUnavailableBaseNotInstalled({required String bundleId}) {
    return 'Install base bundle $bundleId before applying this incremental patch.';
  }

  @override
  String get bundleRemoteUnavailableInstalledManifestMissing =>
      'Installed bundle metadata does not record a manifest hash.';

  @override
  String get bundleRemoteUnavailableBaseManifestMismatch =>
      'Installed manifest does not match this incremental patch base. Use a full bundle instead.';

  @override
  String get bundleRemoteUnavailableUnknown => 'This artifact cannot be imported right now.';

  @override
  String bundleRemoteError({required String message}) {
    return 'Remote bundle discovery failed: $message';
  }

  @override
  String bundleRemoteArtifactDescription({
    required String variant,
    required String bundleId,
    required String gameBuild,
    required String gameServer,
  }) {
    return '$variant bundle $bundleId · build $gameBuild · $gameServer';
  }

  @override
  String get bundleRemoteDownloadAction => 'Download';

  @override
  String get bundleRemoteDownloadImportAction => 'Download and import';

  @override
  String get bundleRemoteImportBehaviorHint =>
      'Imports as an installed bundle. The active bundle stays unchanged until you choose one below.';

  @override
  String bundleRemoteArtifactSize({required String size}) {
    return 'Size: $size';
  }

  @override
  String bundleRemoteArtifactGenerated({required String time}) {
    return 'Generated: $time';
  }

  @override
  String bundleRemoteArtifactBaseBundle({required String bundleId}) {
    return 'Patches installed base: $bundleId';
  }

  @override
  String bundleRemoteArtifactBaseManifest({required String hash}) {
    return 'Base manifest: $hash';
  }

  @override
  String bundleRemoteSchemaVersionWarning({required int version}) {
    return 'Schema v$version — may differ from current app schema';
  }

  @override
  String get bundleRemoteProgressPreparing => 'Preparing remote request';

  @override
  String get bundleRemoteProgressDownloading => 'Downloading archive';

  @override
  String get bundleRemoteProgressVerifying => 'Verifying size and SHA-256';

  @override
  String get bundleRemoteProgressUnpacking => 'Unpacking archive';

  @override
  String get bundleRemoteProgressImporting => 'Importing bundle files';

  @override
  String get bundleRemoteProgressApplyingIncrementalPatch => 'Applying incremental patch';

  @override
  String get bundleRemoteProgressRefreshingRegistry => 'Refreshing installed bundle registry';

  @override
  String get bundleRemoteProgressCompleted => 'Imported, not active';

  @override
  String get bundleRemoteProgressCancelled => 'Import cancelled';

  @override
  String get bundleRemoteProgressQueued => 'Waiting to start';

  @override
  String bundleRemoteProgressDownloadingKnown({
    required String received,
    required String total,
    required String percent,
  }) {
    return '$received of $total ($percent%)';
  }

  @override
  String bundleRemoteProgressDownloadingUnknown({required String received}) {
    return '$received downloaded';
  }

  @override
  String bundleRemoteProgressCompletedDescription({required String bundleId}) {
    return '$bundleId is installed. Select it manually when you want to switch the app\'s active data.';
  }

  @override
  String get bundleRemoteProgressCancelledDescription => 'The current bundle was kept unchanged.';

  @override
  String get bundleRemoteProgressFailedTitle => 'Import failed';

  @override
  String bundleRemoteProgressFailedDescription({required String stage, required String message}) {
    return 'Failed while $stage: $message';
  }

  @override
  String get bundleRemoteProgressRetryAction => 'Retry';

  @override
  String get bundleRemoteProgressKeepCurrentAction => 'Keep current bundle';

  @override
  String get bundleRemoteProgressViewInstalledAction => 'View installed bundle';

  @override
  String get bundleRemoteProgressLoadBundleAction => 'Load this bundle';

  @override
  String get bundleRemoteImportConfirmTitle => 'Download remote bundle?';

  @override
  String bundleRemoteImportConfirmDescription({required String artifactId}) {
    return 'Download, verify, and import $artifactId? The active bundle will not switch automatically.';
  }

  @override
  String get bundleRemoteImportSucceeded => 'Remote bundle imported.';

  @override
  String bundleRemoteImportFailed({required String message}) {
    return 'Remote bundle import failed: $message';
  }

  @override
  String bundleManagerErrorMissingPath({required String path}) {
    return 'Missing required path: $path';
  }

  @override
  String bundleManagerErrorExpectFile({required String fileName}) {
    return 'Expected a file at: $fileName';
  }

  @override
  String bundleManagerErrorExpectDirectory({required String dirName}) {
    return 'Expected a directory at: $dirName';
  }

  @override
  String get bundleManagerErrorBadDescriptor => 'Bundle metadata could not be read.';

  @override
  String bundleManagerErrorBadPatch({required String reason}) {
    return 'Bundle history is invalid: $reason';
  }

  @override
  String get bundleManagerDetailUnavailableMessage =>
      'Bundle details are unavailable until the bundle metadata is repaired or re-imported.';

  @override
  String fallbackTypeUnavailable({required int typeId}) {
    return 'Item data unavailable ($typeId)';
  }

  @override
  String fallbackGroupUnavailable({required int groupId}) {
    return 'Group data unavailable ($groupId)';
  }

  @override
  String fallbackCategoryUnavailable({required int categoryId}) {
    return 'Category data unavailable ($categoryId)';
  }

  @override
  String fallbackMarketGroupUnavailable({required int marketGroupId}) {
    return 'Market group unavailable ($marketGroupId)';
  }

  @override
  String get itemDetailTabInfo => 'Info';

  @override
  String get itemDetailTabAttributes => 'Attributes';

  @override
  String get itemDetailTabSkills => 'Skills';

  @override
  String get itemDetailTabDynamic => 'Dynamic';

  @override
  String get itemDetailDynamicUnavailable => 'Dynamic item data is not available yet.';

  @override
  String get itemDetailDynamicMissing => 'This fit no longer references dynamic item data.';

  @override
  String get itemDetailDynamicBaseItem => 'Base Item';

  @override
  String get itemDetailDynamicMutator => 'Mutator';

  @override
  String get itemDetailDynamicReset => 'Reset';

  @override
  String get itemDetailDynamicReroll => 'Reroll';

  @override
  String itemDetailDynamicBaseAttributeUnavailable({required int attributeId}) {
    return 'Base attribute data is unavailable for $attributeId.';
  }

  @override
  String get itemDetailDescription => 'Description';

  @override
  String get itemDetailClassification => 'Classification';

  @override
  String get itemDetailTypeId => 'Type ID';

  @override
  String get itemDetailCategory => 'Category';

  @override
  String get itemDetailGroup => 'Group';

  @override
  String get itemDetailMarketGroup => 'Market Group';

  @override
  String get itemDetailTraits => 'Traits';

  @override
  String get itemDetailTraitRoleBonuses => 'Role Bonuses';

  @override
  String get itemDetailTraitMiscBonuses => 'Misc Bonuses';

  @override
  String itemDetailTraitPerLevel({required String skillName}) {
    return '$skillName per level';
  }

  @override
  String get itemDetailRequirements => 'Requirements';

  @override
  String get itemDetailFitting => 'Fitting';

  @override
  String get itemDetailSlotClass => 'Slot Class';

  @override
  String get itemDetailBooleanFalse => 'False';

  @override
  String get itemDetailBooleanTrue => 'True';

  @override
  String get dogmaUnitSizeSmall => 'Small';

  @override
  String get dogmaUnitSizeMedium => 'Medium';

  @override
  String get dogmaUnitSizeLarge => 'Large';

  @override
  String get dogmaUnitSizeXLarge => 'X-Large';

  @override
  String dogmaUnitSizeUnknown({required String value}) {
    return 'Size $value';
  }

  @override
  String get dogmaUnitSexMale => 'Male';

  @override
  String get dogmaUnitSexUnisex => 'Unisex';

  @override
  String get dogmaUnitSexFemale => 'Female';

  @override
  String dogmaUnitSexUnknown({required String value}) {
    return 'Sex $value';
  }

  @override
  String get itemDetailAttributes => 'Attributes';

  @override
  String get itemDetailAttributeOverview => 'Attribute Overview';

  @override
  String get itemDetailAttributeType => 'Type';

  @override
  String get itemDetailAttributeBaseValue => 'Base Value';

  @override
  String get itemDetailAttributeCurrentValue => 'Current Value';

  @override
  String get itemDetailAttributeDelta => 'Delta';

  @override
  String itemDetailAttributeBaseAndCurrent({required String base, required String current}) {
    return 'Base: $base  Current: $current';
  }

  @override
  String get itemDetailUnavailable => 'Unavailable';

  @override
  String get itemDetailEffectChain => 'Effect Chain';

  @override
  String get itemDetailNoEffectChain =>
      'No fit-aware modifier chain is available for this attribute.';

  @override
  String get itemDetailOriginal => 'Original';

  @override
  String get itemDetailNormalized => 'Normalized';

  @override
  String get itemDetailPenalized => 'Penalized';

  @override
  String get itemDetailPenalty => 'Penalty';

  @override
  String get itemDetailNet => 'Net';

  @override
  String get itemDetailApplied => 'Applied';

  @override
  String get itemDetailModifierValueSource => 'Source';

  @override
  String get itemDetailModifierValueTransformed => 'Transformed';

  @override
  String get itemDetailModifierValueAppliedAfterPenalty => 'Applied After Penalty';

  @override
  String itemDetailModifierEffectivePercent({required String value}) {
    return '$value% effective';
  }

  @override
  String itemDetailModifierSetAttribute({required String value}) {
    return 'sets the attribute directly to $value';
  }

  @override
  String itemDetailModifierAddsAttribute({required String value}) {
    return 'adds $value to the attribute';
  }

  @override
  String itemDetailModifierSubtractsAttribute({required String value}) {
    return 'subtracts $value from the attribute';
  }

  @override
  String itemDetailModifierIncreaseCurrentValue({required String value}) {
    return 'increases the current value by $value%';
  }

  @override
  String itemDetailModifierReduceCurrentValue({required String value}) {
    return 'reduces the current value by $value%';
  }

  @override
  String itemDetailModifierIncreaseCurrentValueAfterDivision({required String value}) {
    return 'increases the current value by $value% after division';
  }

  @override
  String itemDetailModifierReduceCurrentValueAfterDivision({required String value}) {
    return 'reduces the current value by $value% after division';
  }

  @override
  String itemDetailModifierAppliesBonusPercent({required String value}) {
    return 'applies a $value% bonus';
  }

  @override
  String itemDetailModifierAppliesReductionPercent({required String value}) {
    return 'applies a $value% reduction';
  }

  @override
  String get itemDetailModifierStackingPenaltyHint =>
      'The stacking penalty reduces the transformed value before application.';

  @override
  String itemDetailBuffSource({required int buffId}) {
    return 'Buff $buffId';
  }

  @override
  String get itemDetailModifierSourceShip => 'Ship';

  @override
  String itemDetailModifierSourceModule({required int index}) {
    return 'Module $index';
  }

  @override
  String itemDetailModifierSourceImplant({required int index}) {
    return 'Implant $index';
  }

  @override
  String itemDetailModifierSourceBooster({required int index}) {
    return 'Booster $index';
  }

  @override
  String itemDetailModifierSourceSkill({required int index}) {
    return 'Skill $index';
  }

  @override
  String itemDetailModifierSourceCharge({required int index}) {
    return 'Charge $index';
  }

  @override
  String get itemDetailModifierSourceCharacter => 'Character';

  @override
  String get itemDetailModifierSourceStructure => 'Structure';

  @override
  String get itemDetailModifierSourceTarget => 'Target';

  @override
  String get itemDetailEffectOperatorPreAssign => 'Pre Assign';

  @override
  String get itemDetailEffectOperatorPreMul => 'Pre Mul';

  @override
  String get itemDetailEffectOperatorPreDiv => 'Pre Div';

  @override
  String get itemDetailEffectOperatorAdd => 'Add';

  @override
  String get itemDetailEffectOperatorSub => 'Sub';

  @override
  String get itemDetailEffectOperatorPostMul => 'Post Mul';

  @override
  String get itemDetailEffectOperatorPostDiv => 'Post Div';

  @override
  String get itemDetailEffectOperatorPercent => 'Percent';

  @override
  String get itemDetailEffectOperatorPostAssign => 'Post Assign';

  @override
  String get itemDetailEffectCategoryPassive => 'Passive';

  @override
  String get itemDetailEffectCategoryOnline => 'Online';

  @override
  String get itemDetailEffectCategoryActive => 'Active';

  @override
  String get itemDetailEffectCategoryOverload => 'Overload';

  @override
  String get itemDetailEffectCategoryTarget => 'Target';

  @override
  String get itemDetailEffectCategoryArea => 'Area';

  @override
  String get itemDetailEffectCategoryDungeon => 'Dungeon';

  @override
  String get itemDetailEffectCategorySystem => 'System';

  @override
  String loadingTextExtractingBundle({required String archiveName}) {
    return 'Extracting $archiveName...';
  }

  @override
  String get dontShowAgain => 'Don\'t show again.';

  @override
  String get showDetails => 'Show Details';

  @override
  String get startupBundleUpdateTitle => 'Bundle updates available';

  @override
  String get startupBundleUpdateSingleDescription =>
      'A new recommended bundle update is available. Review it in Bundle Manager before downloading.';

  @override
  String startupBundleUpdateMultipleDescription({required int count}) {
    return '$count recommended bundle updates are available. Review them in Bundle Manager before downloading.';
  }

  @override
  String startupBundleUpdateSummaryRecommended({required String firstId}) {
    return '$firstId recommended';
  }

  @override
  String startupBundleUpdateSummaryWithCount({required String firstId, required int moreCount}) {
    return '$firstId and $moreCount more recommended';
  }

  @override
  String get reportPageTitle => 'Report & Feedback';

  @override
  String get reportSectionGeneral => 'General Feedback';

  @override
  String get reportTileGitHub => 'GitHub Issues';

  @override
  String get reportTileGitHubDescription => 'Report issues or suggest features via GitHub Issues.';

  @override
  String get reportTileTencentForm => 'Tencent Feedback Form';

  @override
  String get reportTileTencentFormDescription =>
      'Submit feedback through the Tencent form (Chinese users).';

  @override
  String get reportTileTencentSheet => 'Tencent Feedback Sheet';

  @override
  String get reportTileTencentSheetDescription => 'View the summary sheet of submitted feedback.';

  @override
  String get reportSectionCommunity => 'Community';

  @override
  String get reportTileQQOfficial => 'EFA Official QQ Group';

  @override
  String get reportTileQQOfficialDescription => 'QQ group 1031146601';

  @override
  String get reportSectionSecurity => 'Security Reports';

  @override
  String get reportTileSecurityEmail => 'Security Email';

  @override
  String get reportTileSecurityEmailDescription =>
      'Send a confidential report to security@efa-tech.dev';

  @override
  String get reportTileSecurityQQ => 'Security QQ';

  @override
  String get reportTileSecurityQQDescription => 'Contact QQ 3562377918';

  @override
  String get reportCopyQQSuccess => 'QQ number copied to clipboard';

  @override
  String get reportCopyQQError => 'Failed to copy QQ number to clipboard';

  @override
  String get reportOpenError => 'Could not open link';

  @override
  String get workspaceTabReportTitle => 'Report & Feedback';
}
