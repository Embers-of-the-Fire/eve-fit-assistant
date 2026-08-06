---
title: 网页版应用
summary: 直接在浏览器中使用 EFA —— 无需安装。
---

# 网页版应用

EFA 提供在线网页版应用 —— 同一套装配工具，完全在浏览器中运行。无需安装：打开网站，完成首次启动设置，即可开始装配。

## 站点

- **稳定版** —— <https://app.efa-tech.dev>：跟随正式版本更新，日常使用请选择此站点。
- **nightly 预览版** —— <https://app-preview.efa-tech.dev>：跟随开发分支更新，可以更早体验新功能，但可能随时出现问题。

## 浏览器要求

网页版依赖两项现代浏览器能力：

- **SharedArrayBuffer**（跨源隔离）—— 装配引擎在后台 Worker 中运行所需。参见[浏览器兼容性](https://developer.mozilla.org/zh-CN/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer#%E6%B5%8F%E8%A7%88%E5%99%A8%E5%85%BC%E5%AE%B9%E6%80%A7)。
- **OPFS**（源私有文件系统）—— 本地数据存储所需。参见[浏览器兼容性](https://developer.mozilla.org/zh-CN/docs/Web/API/File_System_API/Origin_private_file_system#%E6%B5%8F%E8%A7%88%E5%99%A8%E5%85%BC%E5%AE%B9%E6%80%A7)。

本站已在基于 Chromium 的浏览器（Chrome、Edge 等）和 Firefox 上测试。**Safari 可能无法完全支持。**

## 存储说明

所有数据 —— 已下载的游戏数据、装配、角色和设置 —— 都保存在你当前所用站点的浏览器本地存储（OPFS）中：

- 在浏览器中清除该站点的数据会删除应用存储的全部内容。
- 稳定版站点与 nightly 预览版站点的存储相互独立，在一个站点创建的装配在另一个站点不可见。
- 网页版与原生应用之间不共享数据。如需在网页版与原生应用之间迁移装配，请导出一侧的数据并在另一侧导入。参见[导出装配](efa://manual/sharing/exporting-fits)与[导入装配](efa://manual/sharing/importing-fits)。

下一步：[首次启动设置](efa://manual/getting-started/first-run-setup)。
