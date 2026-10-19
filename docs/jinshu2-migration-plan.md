# 《山河问道》×《金书江湖2》系统迁移 Action Plan

> 版本：v1（2026-10-19）
> 适用基线：`main` @ `6131bc1`（0.174.2，SAVE_VERSION 13，77 个测试脚本）
> 目标：把《金书江湖2》中**经过验证的系统耦合方式**，按可发布切片逐步移植进《山河问道》，不打断现有主线、存档与发行节奏。

---

## 0. 一页结论

- **搬什么**：门派职位、建筑门槛、主修武学、江湖委托、装备词条、周目继承——六件事。
- **不搬什么**：50 个门派、400 个敌人、1000 件物品、几百条硬编码例外、VIP 解锁。
- **怎么搬**：每个里程碑 = 一个可独立发布的版本，先纯规则 + 单测，再接 UI，最后跑隔离验收与导出。
- **顺序**：职守（0.175）→ 建筑门槛（0.176）→ 主修武学（0.177）→ 江湖委托（0.178）→ 装备实例/词条（0.179–0.180）→ 周目（0.181）。
- **总工期**：约 33–48 个工作日（单人 + AI 辅助，含测试与验收），建议按 9–13 周排期，预留 30% 缓冲。

---

## 1. 目标与边界

### 1.1 目标（可检验）

1. **提高每周决策密度**：让玩家在每个“结束本周”前至少有 2 个有意义的取舍（岗位/建筑/主修/委托）。
2. **让经营反哺战斗**：门派投入必须能变成战斗中的可见优势，而不是一次性解锁。
3. **让收集变成搭配**：新增“主修”与“装备词条”，使获得新武学/新装备时要做选择，而不是线性变强。
4. **提高长线留存**：通关后有一个明确的“再来一周目”的理由。
5. **不增加存档事故**：每次 schema 变更都有迁移测试与旧档回放；不出现“读档丢进度”。

### 1.2 非目标（本阶段不做）

- 不做 50 门派/大地图沙盒/并派灭派——你们是六章叙事 + 三结局，不是沙盒。
- 不改“每名角色每周 1 次行动”“104 周硬期限”“所有已学招式都能用”“三档难度”。
- 不替换现有战斗框架（ATB 行动条 + 2 行动点已经接近金书的 CTB，不需要重写）。
- 不搬金书的 415 状态/400 敌人/1000 物品；只借“少量状态 + 数据驱动效果”的方法。
- 不动 Demo（`export_presets.cfg` 的 Windows Demo 预设与 `build/windows-demo/` 保持 0.122.0.0）。

### 1.3 成功标准（每个里程碑都要回答）

| 问题 | 通过标准 |
| --- | --- |
| 玩家多做了什么选择？ | 新界面里至少 1 个“有代价的选择”，且不选也能通关 |
| 系统之间连起来了吗？ | 新系统至少影响 1 个既有资源/战斗数值/结局评价 |
| 旧存档还能玩吗？ | 0.174.2 的自动档/手动档能直接读，数值不倒退 |
| 测试覆盖了吗？ | 纯规则单测 + 至少 1 个界面/流程测试 + 全旅程回归 |
| 能发布吗？ | 版本号、导出预设、README、QA 报告、EXE/PCK 校验全部完成 |

---

## 2. 现状基线（决定“怎么搬最省力”）

| 系统 | 现状 | 可复用的钩子 | 缺口 |
| --- | --- | --- | --- |
| 时间/行动 | 104 周、每周 1 行动、结束本周结算 | `GameState.spend_action/end_week` | 无 |
| 门派建设 | 4 建筑 × 3 级（演武场/藏经阁/药圃/铸造坊） | `SectBuildingRules` 的 `level/effect/cost/options` | 建筑只是数值加成，没有“解锁” |
| 同伴/弟子 | 林清霜 + 2 名可招募弟子；可派“赚钱/修炼/采集”持续任务 | `WeeklyTaskRules.resolve_companion`、`companion_growth` | 任务没有岗位差异，收益不随属性成长 |
| 武学 | 5 招式 / 3 内功 / 3 轻功；内功/轻功单槽装备；招式全部可用 | `WuxueRules` 的等级/加成/装备函数 | 没有“主修”概念；招式之间只靠伤害区分 |
| 战斗 | 网格 + 每单位 ATB 行动条（speed→100）+ 2 行动点 | `BattleEngine.advance_turn`、各招式函数 | 状态少、招式效果硬编码 |
| 装备 | `owned_weapons` 是 `id -> 数量` 字典，无实例 | `EquipmentRules` 的占用/数量校验 | 无随机词条、无法区分同名装备 |
| 江湖 | 5 地点、4 门派关系、声望、自由探索、事件委托 | `renown`、`faction_relations`、`RewardRules` | 没有委托板/好感门槛/循环产出 |
| 结局 | 3 结局、`complete_game()`、`_show_ending()` | `ending` 字典、`quest_progress("finale")` | 无周目/继承 |
| 测试 | 77 个脚本，纯规则 + 视图测试齐全 | `tests/test_*_rules.gd` 模式 | 无旧档 fixture、无迁移回归 |

**结论**：不要新建六套系统；**把现有钩子升级**——分派任务→职守、建筑效果→门槛、内功/轻功装备→主修槽、门派关系→委托、数量装备→实例装备、结局→周目。

---

## 3. 迁移原则（每次违反都会付出代价）

1. **机制移植，内容不搬**：先搬“规则形状”，数值按你们的 104 周/小经济重算；不搬金书的 9999 威力。
2. **一个里程碑一个版本**：每个版本必须能独立发布、独立回滚；不做“半成品上线”。
3. **规则先行**：新逻辑先写成 `RefCounted` 纯规则类 + 单测，UI 只做展示与路由。
4. **存档只增不删**：新字段给默认值，旧字段保留；每次 schema 变更 `SAVE_VERSION + 1`，并在 `_migrate_and_validate()` 里归一化。
5. **零新增美术**：优先复用 `ChoiceView`、`UI_THEME`、现有卡牌/图标；词条颜色用现有颜色常量。
6. **一次只动一个杠杆**：不同时改战斗公式与装备模型；M5 这种大重构单独排期。
7. **每个系统四件套**：一个资源（产出）、一个消耗（投入）、一个反馈（战斗/探索变强）、一个可见数字（UI 上能读到）。
8. **保留设计承诺**：所有已学招式可用、每周 1 行动、104 周、三档难度、三结局——除非明确决策要改。

---

## 4. 路线图总览

| 里程碑 | 版本 | 玩家可见变化 | 新增状态 | 估时 | 风险 | 依赖 |
| --- | --- | --- | --- | ---: | --- | --- |
| M0 基线冻结 | — | 无 | 旧档 fixture、测试基线 | 1 d | 低 | — |
| M1 门派职守 | 0.175.0 | 同伴可任 4 种职守，每周产出不同 | `companion_tasks` 语义升级 | 4–6 d | 低 | M0 |
| M2 建筑门槛 | 0.176.0 | 专精/武学突破需要对应建筑等级 | 无（派生计算） | 3–5 d | 低–中 | M1 |
| M3 主修武学 | 0.177.0 | 可设 1 门主修招式，获得额外威力 | `main_move` | 4–6 d | 低 | M2 |
| M4 江湖委托 | 0.178.0 | 每周 3 个委托，声望/门派好感可换特权 | `commissions` | 5–7 d | 中 | M3 |
| M5a 装备实例 | 0.179.0 | 同名装备可区分（为词条铺路） | 装备实例数组 | 6–8 d | 高 | M4 |
| M5b 装备词条 | 0.180.0 | 锻造出带词条/颜色的装备 | 词条表 | 5–7 d | 中–高 | M5a |
| M6 周目继承 | 0.181.0 | 通关后可开新周目，保留图鉴/传家宝 | `cycle/legacy` | 6–9 d | 中 | M5 |
| **合计** |  |  |  | **34–49 d** |  |  |

> 版本号只是建议；如果 M5 拆分，M6 顺延为 0.181/0.182 均可，关键是**每次只上一个系统**。

---

## 5. 里程碑详规

### M0 — 基线冻结（1 天，不发布）

**目的**：在任何改动前，锁住“现在的游戏是什么样”。

- [ ] 从 `main` 切分支 `feat/jinshu2-migration`。
- [ ] 跑完整测试套件，记录通过数（当前 77 个脚本）与耗时。
- [ ] 生成 3 份旧档 fixture 放进 `godot/tests/fixtures/`：
  - `save_v13_fresh.json`（新开局）
  - `save_v13_mid.json`（第 30 周、有同伴/建筑/武学）
  - `save_v13_end.json`（通关、有 ending）
- [ ] 给 `Godot_v4.7.1-stable_win64_console.exe` 建一个本地脚本 `tools/run-tests.ps1`（避免每次手敲路径）。
- [ ] 记录基线性能：主菜单→地图→门派→战斗各界面打开耗时（后续里程碑对比）。

**产出**：绿色基线 + fixture + 测试脚本。**不提交任何游戏逻辑改动。**

---

### M1 — 门派职守（0.175.0，4–6 天）

#### 玩家体验

- 人物界面里，每名同伴的“分派任务”改为“**门派职守**”，4 选 1：
  - **传功长老**：该同伴修炼，同时每周给沈羽额外修为。
  - **掌柜**：该同伴跑买卖，银两收益提高。
  - **总管**：该同伴采集，额外带回药材与矿石。
  - **知客**：该同伴游历，每周带回声望。
- 每个选项显示“预计每周收益”，数值随同伴成长属性变化。
- 结束本周时，日志逐条写出“周慕白（掌柜）带回 9 两”这类可读结算。

#### 规则与数值（按你们的小经济重算，不照搬金书）

| 职守 | 基础行为 | 额外加成（建议初值） | 成长缩放 |
| --- | --- | --- | --- |
| 传功长老 `instructor` | 同伴修炼 | 沈羽每周 +1 修为 | `+ insight/12`（向下取整，最多 +3） |
| 掌柜 `steward` | 同伴赚钱 | 银两收益 +25% | `+ insight/20`（最多 +5%） |
| 总管 `quartermaster` | 同伴采集 | 额外 +1 药材、+1 矿石 | `+ strength/15`（最多 +2） |
| 知客 `envoy` | 新增“游历”任务 | 每周 +1 声望 | 固定 +1（声望稀缺，不再放大） |

> 设计理由：金书的 9 职位是“大后期全局加成”；你们只有 3 名同伴、104 周，4 个岗位、每周个位数收益已经足够形成取舍，不会让经济失控。

#### 数据与存档

- 复用 `companion_tasks`，**职守 id 与旧任务 id 完全一致**（`train/earn/gather`），只新增 `envoy`；因此不需要改存档结构、不需要迁移、`SAVE_VERSION` 保持 13。
- 旧存档的 `train/earn/gather` 直接按新职守生效（等于老玩家自动获得岗位加成，属于增强而非破坏）。
- 如果后续决定把职守拆成独立 id，再单独加 `companion_posts` 字段并升版本。

#### 代码触点

| 文件 | 改动 |
| --- | --- |
| 新增 `godot/scripts/progression/sect_post_rules.gd` | 职位表、`post_for_task`、`assignment_options`、`weekly_forecast`、`apply_bonus` |
| `godot/scripts/progression/weekly_task_rules.gd` | 增加 `envoy`；`resolve_companion` 调 `SectPostRules.apply_bonus`；`options_companion` 改为职守文案 |
| `godot/autoload/game_state.gd` | `assign_companion_task` 校验职守 id；`end_week` 读取返回的 `post_bonus` 写日志 |
| `godot/main.gd` | `_show_companion_tasks` 文案/选项；`_show_character` 的同伴行显示职守；`_resolve_choice` 的 `companion_task` 分支不变 |
| `godot/tests/test_sect_post_rules.gd` | 新增：4 职守预测=实际、旧任务映射、空值安全 |
| `godot/tests/test_weekly_task_rules.gd` | 更新：`envoy`、职守加成、旧断言 |
| `godot/tests/test_character_view.gd` / `test_management_flow.gd` | 更新文案与流程断言 |

#### 测试与验收

- [ ] `test_sect_post_rules.gd` 全绿：同一同伴在不同属性下预测值正确；`apply_bonus` 与 `weekly_forecast` 完全一致。
- [ ] 旧档 fixture 读入后 `companion_tasks` 正确映射，不丢同伴。
- [ ] 每周结算：3 名同伴各任不同职守，日志与资源增量精确匹配。
- [ ] `test_full_journey.gd` 在隔离副本中通过。
- [ ] 手工：新开局→招募周慕白→任职守→结束本周→读档→数值不变。

#### 风险与回退

- 风险：职守加成让早期银两/修为过快 → 用上表保守值，并在 `qa` 中记录 10 周资源曲线。
- 回退：把 `SectPostRules.apply_bonus` 返回空字典即可退回“纯任务”行为（保留字段不删）。

---

### M2 — 建筑门槛（0.176.0，3–5 天）

#### 玩家体验

- 专精界面：等级 30/60/100 的突破被锁，提示“需演武场 Lv.1/2/3”。
- 武学升级：高阶等级被锁，提示“需藏经阁 Lv.1/2/3”。
- 建筑卡片：显示“解锁：精通上限/大成上限/武学 8 级”等新效果，升级有明确目标。

#### 规则与数值（建议）

| 建筑 | 等级 | 解锁 |
| --- | --- | --- |
| 演武场 | Lv.1 | 专精可突破 30（熟手） |
| 演武场 | Lv.2 | 专精可突破 60（精通） |
| 演武场 | Lv.3 | 专精可突破 100（大成） |
| 藏经阁 | Lv.1 | 武学等级上限 6 |
| 藏经阁 | Lv.2 | 武学等级上限 8 |
| 藏经阁 | Lv.3 | 武学等级上限 10 |

- **祖父条款**：旧档已经达到的等级保留，不回退；只阻止“继续提升”。提示文案明确写“已达成的等级保留”。
- 建筑 0 级时：专精上限 29、武学上限 4（新开局可先练到 4，再决定是否投资建筑）。

#### 代码触点

- `training_minigame_rules.gd`：新增 `specialty_cap(state)`、`can_gain_specialty(state, discipline)`；`apply_training`/`complete_training` 在 cap 处截断并返回“被门槛阻止”的原因。
- `wuxue_rules.gd`：新增 `mastery_cap(state)`；`upgrade_move/internal/lightness` 前置校验。
- `sect_building_rules.gd`：`effects` 文案加入解锁说明；`options()` 显示“解锁：…”。
- `main.gd`：训练菜单、藏经阁升级行显示锁定原因；建筑卡显示解锁项。
- `tests/test_sect_building_gates.gd`（新增）+ 更新 `test_training_minigame_rules.gd`、`test_wuxue_rules.gd`、`test_sect_building_rules.gd`。

#### 验收

- [ ] 新档：专精到 29 后无法再涨；升演武场 Lv.1 后可到 59；Lv.2→99；Lv.3→100。
- [ ] 旧档：专精 80、建筑 0 时保留 80，但无法到 81；提示正确。
- [ ] 武学 10 级旧档保留；新档在藏经阁 Lv.0 时卡在 4。
- [ ] 全旅程回归；导出后 EXE 内实测一次。

#### 风险

- 前期变“卡脖子”：把 Lv.1 成本保持 300 两（现价），并让第一周的委托/战斗足够支付。
- 若试玩反馈太硬，退化为“只锁 100 大成”，保留 30/60 自由。

---

### M3 — 主修武学（0.177.0，4–6 天）

#### 玩家体验

- 藏经阁里每门已学招式可“设为主修”，同时只能有 1 门。
- 主修招式在战斗中显示 ★，伤害预览与结算都比其他招式高一截。
- 人物面板显示“主修：流云剑法（+4 伤害）”。

#### 规则与数值

- `main_move`：字符串，默认空。
- 加成：`+2 + (等级-1)/3` 伤害（10 级时 +5），并在招式描述里写明。
- **不改“所有招式可用”**——主修只是强化，不是装备槽；这与金书“只算装备中的武学”神似，但不会剥夺玩家已有选择。
- 内功/轻功已经是单槽装备，M3 顺便把三者集中到一个“武学配置”页展示（不新增数据）。

#### 代码触点

- `wuxue_rules.gd`：`main_move`、`set_main_move`、`main_move_bonus`。
- `battle_engine.gd`：5 个招式函数与 `*_damage_range` 预览统一加 `WUXUE_RULES.main_move_bonus(player, move_id)`。
- `main.gd`：藏经阁行增加“设为主修/取消主修”；战斗按钮加 ★；人物面板显示。
- `game_state.gd`：`set_main_move` 包装 + 存档迁移（默认空）。
- `tests/test_wuxue_rules.gd`、`test_battle_engine.gd`、`test_library_view.gd` 更新。

#### 验收

- [ ] 主修与非主修同等级伤害差 = 公式值；预览=实战。
- [ ] 切换主修即时生效；读档保留。
- [ ] 旧档无 `main_move` 时为空，不报错。
- [ ] 全旅程回归。

---

### M4 — 江湖委托与门派好感（0.178.0，5–7 天）

#### 玩家体验

- 正殿新增“江湖委托”入口：每周 3 个委托，来自青云/华山/峨眉/少林。
- 委托类型：送药材/矿石、缴纳银两、切磋（用现有 spar 流程或纯规则判定）、调查（消耗 1 线索）。
- 完成给银两、声望、门派好感；好感达到阈值解锁特权：
  - 华山 ≥3：秘籍费用 -5%
  - 峨眉 ≥3：回春散额外 +2 治疗
  - 青云 ≥5：门派建设费用 -5%
  - 少林 ≥5：战斗开始获得 2 点护体（先只做 2 个，避免跨系统过多）

#### 规则

- `CommissionRules`：
  - `offers(state)`：按 `week` 做确定性种子，从 8–10 个模板抽 3 个，保证同一周读档不重抽。
  - `can_accept(state, id)`：未接、未完成、资源足够、本周未行动。
  - `accept(state, id)`：消耗 1 行动，立即结算（交付资源/判定），奖励进 `RewardRules`。
  - `faction_perk(state, faction)`：返回当前特权文本与效果 id。
- 数据：`commissions: {week, offers, completed}`、`commission_streak`；`faction_relations` 复用。
- 不新增战斗类型；切磋类委托复用 `start_qingyun_spar_battle` 的规则或直接判定。

#### 代码触点

- 新增 `scripts/progression/commission_rules.gd`。
- `main.gd`：`_show_sect_hall` 增加入口；新增 `_show_commissions()`；`_resolve_choice` 分支。
- `game_state.gd`：`accept_commission`、`end_week` 刷新 offers、迁移。
- `shop_rules.gd`/`crafting_rules.gd`/`sect_building_rules.gd`：读取门派特权。
- 测试：`test_commission_rules.gd`、`test_sect_hall_flow.gd`、`test_shop_rules`/`test_sect_building_rules` 的特权分支。

#### 验收

- [ ] 同一周反复读档，3 个委托不变；下一周变化。
- [ ] 接取消耗行动；资源不足/已接/已完成都禁用并给出原因。
- [ ] 奖励精确；好感阈值只触发一次提示。
- [ ] 旧档 `faction_relations` 缺键时补 0，不崩。

---

### M5a — 装备实例化（0.179.0，6–8 天）

> **这是唯一的高风险重构**。先做“实例化”，不加词条；确认商店/锻造/背囊/同伴装备全部回归后，再进 M5b。

#### 现状与目标

- 现在：`owned_weapons/owned_armors` 是 `id -> 数量`；同名装备不可区分。
- 目标：`owned_weapons/owned_armors` 是实例数组：
  ```gdscript
  {"uid": "w_0001", "base": "qingfeng_sword", "affixes": []}
  ```
- 装备字段从 `equipped_weapon: String(id)` 改为 `equipped_weapon_uid: String`；同伴 `companion_gear[id].weapon` 同样改 uid。
- 兼容：`EquipmentRules` 提供适配层，UI 不直接读数组。

#### 迁移

- 旧 `id -> count` → 展开为 count 个实例，uid 用确定性规则 `"w_%04d" % 序号`（按 id 排序，保证旧档每次迁移结果一致）。
- 已装备的 id → 找到第一个未被占用的同 id 实例 uid。
- 保留旧字段只读；`SAVE_VERSION 15 → 16`。

#### 代码触点

- `equipment_rules.gd`：实例 CRUD、`owned_count` 兼容、`resolve(uid)`、`wearers`/`claimed_count` 改 uid。
- `shop_rules.gd`：买卖改为实例；卖装备时先卸下。
- `crafting_rules.gd`：打造产出一个实例。
- `main.gd`：背囊/装备/同伴装备三条 UI 改为 uid；显示“第 N 件”。
- `game_state.gd`：`_migrate_owned_gear` 改为实例迁移；`_migrate_and_validate` 校验 uid 唯一。
- 测试：`test_equipment_rules.gd` 大改；`test_shop_rules.gd`、`test_crafting_rules.gd`、`test_backpack_view.gd`、`test_save_manager.gd`。

#### 验收

- [ ] 旧档迁移后“拥有数量”不变；已装备的仍然装备。
- [ ] 买/卖/打造/卸下/多人争用同一件装备的行为与旧版一致。
- [ ] 存档读写后 uid 稳定，不重复、不丢失。
- [ ] 全旅程 + 隔离导出包实测。

---

### M5b — 装备词条（0.180.0，5–7 天）

#### 规则

- 每件实例可有 0–2 条词条；词条来自数据表：
  ```gdscript
  {"id": "sharp", "title": "锋锐", "tier": 2, "stat": "attack", "mode": "flat", "value": 2}
  ```
- 品质：白/绿/蓝/紫/橙，按词条 tier 总和决定名字颜色（复用现有颜色常量）。
- 锻造时按铸造坊等级决定词条池与条数：
  - Lv.1：0–1 条，白/绿
  - Lv.2：1 条，蓝/紫
  - Lv.3：1–2 条，紫/橙
- 词条效果只走“属性修正”与“战斗开始状态”两类，不写 `if gear_id ==`。
- 商店可出售“洗练石”重roll（可选，先不做）。
- `SAVE_VERSION 16 → 17`（实例新增 `affixes`）。

#### 代码触点

- 新增 `scripts/progression/gear_affix_rules.gd`（词条表 + 生成 + 描述）。
- `crafting_rules.gd`：打造时生成词条；`equipment_rules.gd`：`stat_bonus(uid)`。
- `battle_engine.gd`/`shop_rules.gd`：读 `stat_bonus` 而不是固定 id。
- `main.gd`：背囊/装备详情显示词条与颜色；锻造结果提示。
- 测试：`test_gear_affix_rules.gd`、`test_crafting_rules.gd`、`test_battle_engine.gd`、`test_backpack_view.gd`。

#### 验收

- [ ] 同 base 的两件装备词条不同，属性不同。
- [ ] 词条数值进入伤害/防御预览，且与实战一致。
- [ ] 存档读写保留词条；旧档实例 `affixes=[]`。
- [ ] 至少 20 个词条覆盖四系，不出现“唯一最优”。

---

### M6 — 周目继承（0.181.0，6–9 天）

#### 玩家体验

- 结局界面新增“开启新周目”按钮（仅通关后可见）。
- 新周目保留：图鉴（药谱/矿谱）、已发现列表、成就（Steam 侧已持久）、1 件传家宝、周目数。
- 新周目重置：周数、主线 flags、门派建筑、同伴、银两、材料、装备（除传家宝）。
- 敌人：每周目 +10% 气血/伤害，最多 +50%（`DIFFICULTY_RULES` 增加 cycle 参数）。
- 菜单/存档显示“第 N 周目”。

#### 规则与数据

- `cycle: int`（默认 1）、`legacy: {heirloom_uid, completed_endings: []}`。
- `start_new_cycle()`：校验 `ending` 非空；保留清单；其余调 `new_game()` 后回填保留项；写新自动档。
- 旧档迁移：`cycle=1`、`legacy={}`。
- 结局记录：`completed_endings` 去重追加，用于“全结局”成就。

#### 代码触点

- `game_state.gd`：`start_new_cycle`、保留/重置清单、`_migrate_and_validate`。
- `difficulty_rules.gd`：`apply_to_battle(battle, level, cycle)` 增加倍率。
- `main.gd`：`_show_ending` 加按钮与确认；菜单版本行显示周目。
- `save_manager.gd`：新周目写入前先备份旧档（可选）。
- 测试：`test_new_cycle.gd`、`test_difficulty_rules.gd`、`test_full_journey.gd` 结局分支。

#### 验收

- [ ] 通关→新周目：保留/重置清单逐项断言。
- [ ] 敌人倍率生效；旧档仍是第 1 周目。
- [ ] 不覆盖旧通关存档；读档界面能区分周目。
- [ ] 全旅程 + 导出包实测。

---

## 6. 跨里程碑工程规范

### 6.1 存档版本表

| 版本 | 里程碑 | 变更 |
| ---: | --- | --- |
| 13 | 0.174.2 | 当前基线 |
| 14 | M3 0.177.0 | `main_move` |
| 15 | M4 0.178.0 | `commissions` |
| 16 | M5a 0.179.0 | 装备实例（uid） |
| 17 | M5b 0.180.0 | 实例 `affixes` |
| 18 | M6 0.181.0 | `cycle/legacy` |

> M1 实施时改为**复用原任务 id**，没有 schema 变更，因此不占版本号；后续里程碑从 14 起顺延。

规则：

- 每次加字段必须同时改三处：`new_game()` 默认值、`import_data()` 的兼容、`_migrate_and_validate()` 的归一化。
- 迁移测试必须从 `tests/fixtures/` 的旧 JSON 读入，而不是手工造新字典。
- `SAVE_VERSION` 只增不减；读到更高版本时保持现有“拒绝并警告”的行为。

### 6.2 测试分层

1. **纯规则**：`tests/test_<system>_rules.gd`，无场景、无 UI，断言公式与边界。
2. **视图/流程**：`tests/test_<screen>_view.gd` 或 `test_<flow>_flow.gd`，实例化 `main.tscn` 或具体 View。
3. **全旅程**：`tests/test_full_journey.gd`，只在隔离副本（`ShanheWendao-iteration-tests` + 独立 APPDATA）跑。
4. **迁移**：`tests/test_save_migration.gd`（新增），遍历 fixtures，断言关键字段。
5. **发布验证**：`--verify-*` 流程（training/crafting/pause/steam）与导出包实测。

命令模板（路径按本机 Godot 4.7.1 console 版）：

```powershell
$godot = "C:\path\to\Godot_v4.7.1-stable_win64_console.exe"
$project = Join-Path $PWD "godot"
& $godot --headless --path $project --script res://tests/test_sect_post_rules.gd
if ($LASTEXITCODE -ne 0) { throw "test failed" }
```

### 6.3 每个版本的发布清单（Definition of Done）

- [ ] 纯规则测试全绿；视图/流程测试全绿；旧档迁移测试全绿。
- [ ] 全旅程在隔离副本通过，日志无脚本错误。
- [ ] `godot/README.md` 版本行、`godot/main.gd` 两处版本串、`export_presets.cfg` 的 Windows Desktop `file_version/product_version` 同步更新。
- [ ] 导出完整版 Windows Desktop；EXE 版本号、文件大小、PCK 大小记录进 QA。
- [ ] QA 报告：`qa/YYYY-MM-DD-<slug>/REPORT.md` + `screenshots/` + `verification-summary.json` + `artifact-manifest.json`。
- [ ] Demo 预设/构建未动（保持 0.122.0.0）。
- [ ] 提交并推送；提交信息用 `0.175.0 ...` 格式；不夹带无关文件。

### 6.4 Git 分支与提交

- 每个里程碑一条分支：`feat/post-roles`、`feat/building-gates`、`feat/main-move`、`feat/commissions`、`feat/gear-instances`、`feat/gear-affixes`、`feat/new-cycle`。
- 提交粒度：规则+测试一个提交；UI 一个提交；迁移一个提交；QA/版本一个提交。
- 合并前 rebase 到 `main`，跑一遍全旅程。
- 打 tag：`v0.175.0` 等（可选）。

---

## 7. 内容管线（系统搬完之后）

系统只是“插座”，内容才是“电器”。M3 之后建议启动一个小型内容包：

| 内容 | 现在 | 目标（1.0 前） | 做法 |
| --- | ---: | ---: | --- |
| 招式 | 5 | 10–12 | 每门一个独特效果，数据驱动 |
| 内功 | 3 | 6 | 每门一个战斗规则（护体/回气/反伤） |
| 轻功 | 3 | 5 | 位移/先手/闪避 |
| 专精 | 6 系 | 6 系 | 30/60/100 三段 perk 明确化 |
| 装备词条 | 0 | 20–30 | 四系各 5–8 条，避免唯一最优 |

**关键约束**：新武学不要复制金书的 `if skill_id ==`。给 `MOVES` 增加 `effect` 字段（如 `{"kind": "armor_break", "value": 1}`），在 `BattleEngine` 里用 `match effect.kind` 分派；这样加第 11 门武学只需要改数据，不改公式。

---

## 8. 需要你拍板的 5 件事（默认建议已给）

| # | 决策 | 选项 | 建议 |
| ---: | --- | --- | --- |
| 1 | 职守与现有“分派任务”的关系 | A 合并（职守=任务+加成）；B 并行两套 | **A**：避免两套同伴管理 |
| 2 | 建筑门槛强度 | A 30/60/100 全锁；B 只锁 100 | **A**：先按 A 做，试玩太硬再退 B |
| 3 | 主修槽 | A 只设 1 门主修招式；B 外功/内功/轻功三槽都重做 | **A**：不改“所有招式可用”的承诺 |
| 4 | 装备实例 | A 现在做（M5a）；B 先做词条卷轴、不改实例 | **A**：词条没有实例会变成“全局附魔”，不推荐 |
| 5 | 周目保留 | A 图鉴+1 传家宝+成就，门派重置；B 连门派等级一起保留 | **A**：保持新周目的新鲜感；B 会让后两章失去建设目标 |

---

## 9. 第一周执行清单（从明天就能开始）

**Day 1 — 基线**
- [ ] 切分支、跑 77 个测试、记录通过数。
- [ ] 写 `tools/run-tests.ps1`，把 Godot 路径与测试列表固化。
- [ ] 生成 3 份 fixture。

**Day 2–3 — M1 规则**
- [ ] 写 `sect_post_rules.gd` + `test_sect_post_rules.gd`。
- [ ] 改 `weekly_task_rules.gd`（`envoy` + 加成钩子）。
- [ ] 单测跑绿。

**Day 4 — M1 数据/迁移**
- [ ] `game_state.gd` 的 `assign_companion_task`/`end_week`/迁移。
- [ ] `SAVE_VERSION` 13→14；旧档 fixture 回放。

**Day 5 — M1 UI**
- [ ] `_show_companion_tasks` 文案与预测行；人物面板职守徽章。
- [ ] 更新视图/流程测试。

**Day 6 — M1 验收**
- [ ] 全旅程；手工 3 场景；导出；QA 报告；版本号；提交推送。

> 如果 Day 5 还没收口，砍掉“知客”只留 3 个职守先发 0.175.0，知客放 0.175.1。

---

## 10. 进度追踪

| 里程碑 | 状态 | 开始 | 完成 | 版本 | QA 报告 |
| --- | --- | --- | --- | --- | --- |
| M0 基线 | ✅ | 2026-10-19 | 2026-10-19 | — | `tools/run-tests.ps1` |
| M1 职守 | ✅ | 2026-10-19 | 2026-10-19 | 0.175.0 | [REPORT](../qa/2026-10-19-sect-posts/REPORT.md) |
| M2 建筑门槛 | ✅ | 2026-10-19 | 2026-10-19 | 0.176.0 | [REPORT](../qa/2026-10-19-building-gates/REPORT.md) |
| M3 主修 | ⬜ |  |  | 0.177.0 |  |
| M4 委托 | ⬜ |  |  | 0.178.0 |  |
| M5a 实例 | ⬜ |  |  | 0.179.0 |  |
| M5b 词条 | ⬜ |  |  | 0.180.0 |  |
| M6 周目 | ⬜ |  |  | 0.181.0 |  |

---

## 11. 附录：金书系统 → 山河 的取舍表

| 金书系统 | 判断 | 山河落点 | 理由 |
| --- | --- | --- | --- |
| 9 门派职位 | **移植（缩为 4）** | M1 职守 | 让 3 名同伴都有用；成本最低 |
| 建筑等级 gate 专精 | **移植** | M2 | 现成 4 建筑，天然耦合 |
| 武学三槽/只算装备 | **改造** | M3 主修 | 保留“全招式可用”，只加强化 |
| 随机装备前后缀 | **移植** | M5 | 延长锻造寿命；需实例化 |
| 声望/门派好感 | **移植（轻量）** | M4 | 已有 renown/faction_relations |
| 周目/传承箱 | **移植（轻量）** | M6 | 三结局天然适合 NG+ |
| 集气 CTB | **不搬** | 现有 ATB 已足够 | 重写收益低、风险高 |
| 86 状态/封穴 | **缓做** | 后续小版本 | 先有 2–3 个状态即可 |
| 文斗/比武 | **缓做** | 可选副玩法 | 与主线关系弱 |
| 自走棋 | **不做** | — | 与产品定位不符 |
| 50 门派/400 敌人 | **不做** | — | 内容量不匹配团队 |
| 硬编码例外 | **反模式** | 数据驱动 effect | 金书后期维护地狱的根源 |
| VIP 解锁 | **不做** | — | 买断制应全内容可玩 |

---

## 12. 风险登记

| 风险 | 概率 | 影响 | 缓解 |
| --- | --- | --- | --- |
| 建筑门槛让前期变闷 | 中 | 中 | Lv.1 保持 300 两；先只锁 100 的退路 |
| 职守收益破坏经济 | 低 | 中 | 上表保守值；QA 记录 10 周曲线 |
| 装备实例化引入存档 Bug | 中 | 高 | 独立里程碑；旧档 fixture；先实例化后词条 |
| 主修让平衡倾斜 | 低 | 低 | +2~+5 伤害，占比可控 |
| 委托系统变成日常负担 | 中 | 中 | 每周最多接 1 个；不做强制 |
| 周目让叙事重复疲劳 | 中 | 低 | 可跳过已看剧情（另做） |
| 版本/导出漏改 | 低 | 高 | DoD 清单 + QA 模板 |

---

## 13. 下一步

1. 你确认第 8 节的 5 个决策（默认建议即可开工）。
2. 我按 M1 开始：先写 `sect_post_rules.gd` + 单测，再改 `weekly_task_rules.gd` 与 UI。
3. 每个里程碑结束给你一份 QA 报告与可玩的完整版导出，再决定是否进入下一个。
