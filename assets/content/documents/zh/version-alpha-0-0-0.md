---
id: version-alpha-0-0-0
kind: version
publishedAt: 2026-04-14T00:00:00Z
appVer: 1.0.0
tags:
  - release-note
  - version
---

# 版本 Alpha 0.0.0

## 新增

- 设置页中的版本入口。
- 首页中的“更新动态”入口卡片。
- 使用 `markdown_widget` 渲染的内置 Markdown 文档。
- 工作台中的混合更新列表，现在会同时显示公告、信息说明和版本日志。
- 新增一条面向 Alpha 测试者的说明文档，汇总已支持流程、当前限制与数据包恢复建议。

## 架构

- 内置默认文档从应用资源中加载。
- 在线更新预留为独立的存储通道。
- 文档存储带有版本号，便于后续迁移。
