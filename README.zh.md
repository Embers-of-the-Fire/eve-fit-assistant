# EVE Fit Assistant

![Banner | EFA](docs/images/banner.png)

<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <a href="https://github.com/Embers-of-the-Fire/eve-fit-assistant/releases"><img src="https://img.shields.io/github/v/release/Embers-of-the-Fire/eve-fit-assistant?display_name=release" alt="Latest Release" /></a>
  <a href="https://github.com/Embers-of-the-Fire/eve-fit-assistant/actions/workflows/ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/Embers-of-the-Fire/eve-fit-assistant/ci.yml?branch=dev&amp;label=CI" alt="CI" /></a>
  <a href="https://app.efa-tech.dev"><img src="https://img.shields.io/website?url=https%3A%2F%2Fapp.efa-tech.dev&amp;label=web%20app" alt="Web App Status" /></a>
  <a href="LICENSE-MIT"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT" /></a>
  <a href="LICENSE-APACHE"><img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License: Apache 2.0" /></a>
</p>

**EFA** 是一款免费、开源、跨平台的 [EVE Online](https://www.eveonline.com/)
舰船装配工具。离线编辑舰船配置、查阅物品与船体详情、加载角色技能档案 ——
全部基于版本化数据包与增量更新,无需持续联网即可使用。

**[下载](https://efa-tech.dev/download) · [打开网页版](https://app.efa-tech.dev) · [使用手册](https://docs.efa-tech.dev) · [社区平台](https://platform.efa-tech.dev) · [反馈问题](https://efa-tech.dev/report/bug)**

> EFA 目前处于公开测试阶段(0.x)。版本之间可能会有变动和问题
> —— 非常欢迎你的反馈。

## 功能特性

- **本地装配编辑** —— 直接在设备上创建、编辑和尝试舰船装配,所有计算均在
  本地运行,并内置校验(CPU/能量栅格、无人机与铁骑舰载机容量、装备状态限制)。
- **物品与船体查阅** —— 浏览完整的 EVE 物品数据库,包含完整统计数据、属性和
  装配需求。
- **角色技能档案** —— 管理多个角色,精确查看技能如何影响装备性能与舰船整体
  能力。
- **伤害类型与战术模式** —— 为每个配置切换伤害类型、切换战术模式,管理无人机/
  铁骑舰载机与植入体套装。
- **配置估价** —— 估算配置成本,包含买入/卖出总额与逐项明细,支持 Tranquility
  与 Serenity 市场。
- **离线数据包** —— 静态游戏数据以版本化、按服务器划分的数据包(Tranquility /
  Serenity / Singularity)发布,支持增量更新与回滚。
- **配置分享与社区** —— 通过快照与深链接分享配置,或一键发布到
  [社区平台](https://platform.efa-tech.dev),并在应用内浏览其他玩家的配置。
- **AI 助手** —— 可选的内置聊天(自带 API 密钥),可以阅读、分析和修改配置。
- **跨平台** —— 一个应用覆盖网页、Android 与桌面平台。
- **多语言** —— 完整的英文与简体中文界面。

市场统计与更广泛的 EVE 查询工具已在计划中,但尚未推出。

## 应用截图

<!-- 占位图片:请将 docs/images/*.placeholder.png 替换为去掉 `.placeholder`
     后缀的真实截图。 -->

<p align="center">
  <img src="docs/images/fitting.png" alt="装配编辑" width="45%" />
  <img src="docs/images/item-detail.png" alt="物品详情查阅" width="45%" />
</p>
<p align="center">
  <img src="docs/images/characters.png" alt="角色技能档案" width="45%" />
  <img src="docs/images/community.png" alt="社区配置分享" width="45%" />
</p>

## 获取 EFA

| 平台 | 状态 | 获取方式 |
| ---- | ---- | -------- |
| **网页版** | 稳定版与每日构建 | 使用 [app.efa-tech.dev](https://app.efa-tech.dev)(稳定版)或 [app-preview.efa-tech.dev](https://app-preview.efa-tech.dev)(每日构建,可能不稳定)。需要现代 Chromium 内核浏览器或 Firefox;Safari 可能不受完整支持。 |
| **Android** | 官方支持 | 从 [efa-tech.dev/download](https://efa-tech.dev/download) 下载对应 CPU 架构的签名 APK。应用内也可自动检测并后台下载更新。 |
| **Windows** | 预览版 | 从[下载页面](https://efa-tech.dev/download)获取原生 zip 或单用户 MSI 安装包。 |
| **Linux** | 预览版 | 从[下载页面](https://efa-tech.dev/download)获取 AppImage 或原生 zip。 |
| **iOS** | 仅自行构建 | 不提供预构建二进制文件;请按照[开发指南](docs/dev/development.md#build)从源码构建。 |

应用以手机为主要目标形态;平板与桌面窗口可以使用,但并非首要目标。

## 文档

- **[使用手册](https://docs.efa-tech.dev)** —— 入门指南、装配教程、分享、数据
  管理、常见问题与已知限制(English & 中文)。
- **更新日志** —— 各版本更新说明位于[使用手册](https://docs.efa-tech.dev)
  侧边栏的「更新日志」分组(最新版本在前)。
- **[项目主页](https://efa-tech.dev)** —— 项目落地页。

## 支持与反馈

- 发现了 Bug 或有功能建议?使用[反馈表单](https://efa-tech.dev/report/bug)
  (会自动创建可跟踪的 GitHub Issue),或直接在
  [GitHub](https://github.com/Embers-of-the-Fire/eve-fit-assistant/issues)
  上提交 Issue。
- 在 [EFA 社区平台](https://platform.efa-tech.dev)与其他玩家交流,或加入
  [QQ 群](https://qm.qq.com/q/bLyF0dNYTm)。
- 安全问题:请参阅 [SECURITY.md](SECURITY.md)。

## 项目状态

本仓库的 `dev` 分支处于活跃开发中,所有版本均从该分支发布;`main` 分支已弃用。
当前发布频道为 `testing` —— 可能会有不完善之处,欢迎反馈你遇到的问题。

## 开发者

EFA 采用 Flutter/Dart 应用与 Rust 装配引擎(通过
[`flutter_rust_bridge`](https://github.com/fzyzcjy/flutter_rust_bridge),核心逻辑
位于 [`eve-fit-os`](https://github.com/Embers-of-the-Fire/eve-fit-os)),
辅以 Python 数据工具链与 TypeScript/SvelteKit Web 服务。

如需从源码构建或参与贡献,请从[开发指南](docs/dev/development.md)与
[AGENTS.md](AGENTS.md) 开始。

EFA 在设计上不关心数据来源:与姊妹项目
[EVE Multitools](https://github.com/Embers-of-the-Fire/EVE-Multitools) 不同,
它从不在意游戏数据来自何处。

## 许可证

EVE Fit Assistant 采用 [MIT 许可证](LICENSE-MIT) 与
[Apache 许可证 2.0](LICENSE-APACHE) 双重许可,由你选择适用其一。

---

<sub>EVE Online 和 EVE 标志是 CCP hf 的注册商标。保留所有权利。所有其他商标均为其
各自所有者的财产。EVE Fit Assistant 是第三方工具,未经 CCP hf 认可。</sub>
