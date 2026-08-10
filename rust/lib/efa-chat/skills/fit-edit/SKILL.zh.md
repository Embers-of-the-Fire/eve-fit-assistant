---
name: fit-edit
description: 修改当前挂载的装配——添加、更换或移除模块、无人机、舰载机、植入体与增效剂
---

# 修改装配

当用户想要修改当前挂载的装配时使用此技能。如果没有挂载装配，先用
`list_user_fits` 列出用户的装配并用 `load_fit` 挂载其一（或用
`fit-create` 技能新建一个）。

## 流程

1. 调用 `get_current_fit` 查看当前布局；`remove_*` / `set_*` 操作所需
   的槽位索引来自此列表。
2. 用户提到的每个物品都用 `search_items` 解析：已知类别时传入
   `kind`，`language` 与名称的语言一致。植入体与增效剂的 `slot` 参数
   取搜索结果的 `slot_index` 字段。
3. 用 `apply_fit_edit` 应用修改。修改会立即生效并保存——没有确认环
   节——因此调用前要仔细核对 type id 与槽位索引。
4. 阅读工具结果：它会报告已应用与被拒绝的修改，以及修改后的装配数据
   与校验结果。修复或解释每一条被拒绝的修改，并把新出现的校验问题告
   知用户。
5. 总结改动及其对核心数据的影响；如需返回摘要之外的数字，调用
   `get_fit_stats`。

## 操作速查

- 添加模块：`add_module`，需要 `slot_type` + `type_id`；可选 `state`
  与 `charge_type_id`。
- 移除 / 改状态 / 换装药：`remove_module`、`set_module_state`、
  `set_module_charge`，需要来自 `get_current_fit` 的 `slot_type` +
  `index`（省略 `charge_type_id` 表示卸下载药）。
- 无人机：`add_drone`（`state` 默认 "bay"，"space" 表示放出）；
  `remove_drone` / `set_drone_state` 作用于该类型的所有无人机。
- 舰载机：`add_fighter` 可带 `ability` 位掩码（1 = 攻击炮台、2 = 导
  弹、4 = 攻击导弹、8 = 炸弹，相加可组合多项能力）；
  `remove_fighter` 按类型移除。
- 植入体：`set_implant`，`slot` 1-10（替换该槽位现有植入体）；
  `remove_implant` 按槽位移除。增效剂同理，槽位为 1-3。

## 注意

- 更换模块就是在一次 `apply_fit_edit` 调用中组合 `remove_module` 与
  `add_module`；注意移除后索引的变化。
- 绝不要编造 type id；`search_items` 找不到时，如实告诉用户，不要猜。
