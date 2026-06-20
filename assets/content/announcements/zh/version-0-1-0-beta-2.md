---
id: version-0-1-0-beta-2
publishedAt: 2026-06-06T11:11:56Z
tags: [release-note]
channels: [testing]
platforms: [android, ios]
appVersion: "0.1.0-beta.2"
---

# v0.1.0-beta.2 发布说明
- 新增日志收集页面与多语言键值
- 默认启用远程内容获取器
- 修复从远程文档正文剥离 YAML 前置信息的问题
- 在 Android Manifest 中添加互联网权限请求
- 向文档中添加特性介绍图片

## [v0.1.0-beta.2] - 2026-06-06


### Added

- **remote:** Enable remote content fetcher by default
- Add log collection page and localization keys (#120) ([#120])
### Documentation

- Add feature introduction images to documentation (#121) ([#121])
### Fixed

- Strip YAML frontmatter from remote document bodies (#122) ([#122])
