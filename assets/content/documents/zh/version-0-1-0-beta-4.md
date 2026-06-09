---
id: version-0-1-0-beta-4
kind: version
publishedAt: 2026-06-09T11:23:44Z
appVer: 0.1.0-beta.4
tags:
  - release-note
  - version
---

# v0.1.0-beta.4 发布说明
- 增强bundle描述符的本地化名称与展示字段
- 新增字体缩放功能与设置页本地化
- 迁移SvelteKit落地页并增强工具链配置
- 添加setuptools配置以修复Cloudflare Pages上的pip安装失败
- 升级依赖并更新智能体上下文
- 移除误提交的生成文件

## [v0.1.0-beta.4] - 2026-06-09


### Added

- Migrate SvelteKit landing page and enhance tooling setup (#125) ([#125])
- Add font scaling feature and localization to settings (#126) ([#126])
- Enhance bundle descriptor with localized names and display fields (#127) ([#127])
### Fixed

- **build:** Add setuptools config to prevent pip install failure on Cloudflare Pages
