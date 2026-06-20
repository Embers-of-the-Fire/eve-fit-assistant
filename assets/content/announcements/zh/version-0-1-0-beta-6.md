---
id: version-0-1-0-beta-6
publishedAt: 2026-06-16T14:24:42Z
tags: [release-note]
channels: [testing]
platforms: [android, ios]
appVersion: "0.1.0-beta.6"
---

# v0.1.0-beta.6 发布说明
- 新增伤害配置文件的本地化、目录和用户界面对话框
- 新增在配装列表长按以打开舰船信息页面
- 新增新船型验证器于原生层

## [v0.1.0-beta.6] - 2026-06-16


### Added

- **site:** Add variant param redirects and URL param defaults for reports (#143) ([#143])
- **fit-list:** Add longpress to open ship info page
- Add damage profile localization, catalog, and UI dialog (#152) ([#152])
### Documentation

- **opencode:** Scope changelog to exclude non-EFA-app commits
### Fixed

- **ci:** Wrap setup ci dev config in nix develop shell
- **ci,codegen:** Correct -f flag position in generate command (#148) ([#148])
- **native:** Add new ship type validator
