---
id: version-0-1-0-beta-5
kind: version
publishedAt: 2026-06-13T10:40:31Z
appVer: 0.1.0-beta.5
tags:
  - release-note
  - version
---

# v0.1.0-beta.5 发布说明
- CI 矩阵命令与 GitHub Actions 测试工作流
- 本地化支持与 AvailableUpdateGate 对话框
- 反馈页面
- 增强的综合报告表单，支持元数据及 API
- Issue 重定向 Cloudflare Worker
- 站点相对链接锚点
- 单元测试基础设施
- 更新 codeart
- 移除未维护的编辑器配置

## [v0.1.0-beta.5] - 2026-06-13


### Added

- **worker:** Add issue-redirect Cloudflare Worker (#130) ([#130])
- Enhance integrated report form with metadata and API support (#135) ([#135])
- **site:** Add feedback page
- Add localization and integrate `AvailableUpdateGate` dialog (#137) ([#137])
- Add CI matrix command and GitHub Actions workflow for testing (#138) ([#138])
### Fixed

- **issue:** Fix wrangler config and route config
- **site:** Fix relative link anchor
