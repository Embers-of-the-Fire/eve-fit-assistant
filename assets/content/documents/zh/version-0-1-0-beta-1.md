---
id: version-0-1-0-beta-1
kind: version
publishedAt: 2026-06-06T08:44:24Z
appVer: 0.1.0-beta.1
tags:
  - release-note
  - version
---

# v0.1.0-beta.1 发布说明
- 实现远程内容管道，支持 S3/MinIO 存储、发布/导入工作流、ETag 缓存与会话管理
- 实现 Bundle 管理功能，包含 schema 版本化、影响分析、技能方案校验与已安装验证
- 集成 git-cliff 实现变更日志自动生成，新增发布版本管理命令行工具
- 将频道从 Alpha 重命名为 Testing，完成跨平台迁移
- 新增应用版本工具，支持最低版本警告和系统语言检测
- 实现文档存储，支持未读追踪与启动时更新通知
- 优化用户界面：舰船船体查看、自适应网格布局和技能编辑器改版
- 增强开发者配置与环境管理命令
- 修复 S3 空桶场景下的发布和远程状态获取问题
- artifact 标识符改为从 bundleId 而非 gameServer 派生
- 修复发布工具链：命令行标志位置、分支范围标签查找及 Flutter 构建属性
- S3 目标跳过不必要的桶创建
- 修复热重启时过期的 ETag 缓存问题
- 修复缺失 Alpha Max 技能的处理及窄布局下 Bundle 标题显示
- 定义远程内容存储契约，文档化本地基线
- 更新运行时与构建依赖
- 重命名包标识符、更新原始 URL，移除遗留的 S3 回滚逻辑
- 更新开发者文档，开发环境增加 MinIO CLI 支持

## [v0.1.0-beta.1] - 2026-06-06


### Added

- Detect system locale (#71) ([#71])
- Add advanced fit validation and surface issues in UI (#72) ([#72])
- **character:** Use slide actions for profile rows (#74) ([#74])
- Enhance bundle skill profile management and validation (#75) ([#75])
- Restyle skill group selector and editor layout (#77) ([#77])
- Add configurable list return behavior for nested selectors (#78) ([#78])
- Add bundle impact analysis and warning preferences (#79) ([#79])
- Add mock origin fixtures and document launch workflow (#90) ([#90])
- Enhance remote content settings with controls and persistence (#91) ([#91])
- Add S3 publish command and document workflow (#92) ([#92])
- Sync remote documents and improve error logging (#93) ([#93])
- Add and test installed bundle verification service and UI (#94) ([#94])
- Enhance remote bundle management and documentation (#95) ([#95])
- Enhance remote bundle selection and recommendation logic (#96) ([#96])
- Enhance remote bundle import with progress reporting and UI updates (#98) ([#98])
- Stabilize and reload active bundle providers (#99) ([#99])
- Implement centralized Dio factory, ETag caching, and incremental fetch (#100) ([#100])
- Implement adaptive grid layout for workspace shortcut cards (#101) ([#101])
- Enable ship hull inspection and add hyperlink handler in description (#103) ([#103])
- Add startup bundle update notification dialog and localization (#105) ([#105])
- Enhance document storage with unread tracking and versioning features (#104) ([#104])
- Refactor remote configuration to support nested MinIO and S3 models (#106) ([#106])
- Add session management module and enhance remote CLI features (#107) ([#107])
- Refactor app version retrieval and remove `pubspec.yaml` from assets (#108) ([#108])
- Enhance remote upload with integrity verification and config options (#110) ([#110])
- Add minAppVer warning features and version comparison utilities (#111) ([#111])
- Implement bundle schema versioning and related UI updates (#112) ([#112])
- Introduce Channel enum and migrate alpha to testing across platforms (#113) ([#113])
- Add SECURITY.md and implement report page features (#115) ([#115])
- Enhance release management with versioning, syncing, and checks (#114) ([#114])
- Enhance changelog generation with git-cliff integration (#116) ([#116])
- Add version publishing model and CLI support for remote operations (#117) ([#117])
- Add write-changelog opencode command
- Implement auto-generated IDs and generation support for remote features (#118) ([#118])
- Refactor session management and validation in remote module (#119) ([#119])
### Changed

- Enhance developer configuration and environment commands (#89) ([#89])
### Documentation

- **readme:** Update alpha development guide (#70) ([#70])
- **remote-content:** Document local baseline (#87) ([#87])
- **remote-content:** Define v1 storage contract (#88) ([#88])
- Update releasing guide
### Fixed

- **bundle-manager:** Preserve bundle title in narrow layouts (#73) ([#73])
- **skills:** Treat missing alpha max as unavailable (#76) ([#76])
- **http:** Handle stale ETag in fetchRemoteJson on hot restart (#102) ([#102])
- **cli:** Skip bucket creation and anonymous policy for S3 target
- Fix flutter build properties and include build number in version (#109) ([#109])
- **release:** Scope tag discovery to current branch
- **release:** Correct -f flag position in generate all command
- **remote:** Handle empty S3 bucket in fetch_remote_state_s3
- **remote:** Derive artifact_id from bundleId instead of gameServer
- **remote:** Fix S3 publish upload failures on empty R2 buckets
