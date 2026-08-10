---
title: 开发者工具
summary: 开发者专属的诊断与维护工具，包括频道概览、重启初始化、触发反馈与重置全部存储。
---

# 开发者工具

开发者工具页面（开发者设置 → Developer Tools）仅在开启[开发者模式](efa://manual/settings/developer-mode)后可访问，未开启时访问会被重定向回首页。该页面面向开发者，界面仅提供英文。页面包含以下工具：

- **Channel Overview（频道概览）** — 打开远程频道元数据与同步状态页面。详见[频道概览](efa://manual/pages/data/channel-overview)。
- **Restart Initialization（重启初始化）** — 重置欢迎状态，重新运行应用初始化流程。
- **Trigger Feedback Dialog（触发反馈对话框）** — 重置反馈状态并立即弹出使用体验反馈提示。
- **Reset All Storage（重置全部存储）** — 删除所有本地数据并重新进入首次使用引导流程。

> **警告：** **Reset All Storage** 会永久删除所有设置、配装、角色、数据检出、缓存的远程数据与日志，无法撤销。原生平台会清空应用目录并重启应用；网页版会清空浏览器中的数据并重新加载页面。日常的缓存与数据清理请使用[存储管理](efa://manual/pages/data/storage)。

如需随反馈附上日志，可在[开发者设置](efa://manual/pages/settings/developer-settings)中打开**收集日志**。开发者模式相关说明见[开发者模式](efa://manual/settings/developer-mode)。