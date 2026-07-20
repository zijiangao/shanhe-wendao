# 山河问道 Godot Steam版

这是与早期网页版并存的独立Godot 4工程，也是当前的开发主线，目标是达到可在Steam上架销售的完成度。截至 0.59.0，已完整实现：

- 主菜单、自动存档与三档手动存档（原子写入+`.bak`备份恢复）
- 青云门四项修炼小游戏（剑法/刀法/采药/挖矿）与可重复的门内切磋
- 天下地图旅行与两年（104周）倒计时的资源/时间管理
- 黑苇渡、华山双人试炼、武库天门终战等多场网格回合战棋战斗，含Boss阶段转换、弓手压制、护体/破绽等机制
- 青云→黑苇渡→洛阳→华山→峨眉→终章的完整主线，含三种结局
- 专精境界（熟手/精通/大成）、药谱与矿谱收藏、青云工坊锻造
- 键盘重绑定、鼠标与手柄导航、难度分级（休闲/标准/宗师）、战斗反馈开关（震屏/命中闪光）
- 本地模拟与GodotSteam双后端的Steam成就、统计与云存档接入（详见 `STEAM_RELEASE.md`）

## 运行

1. 安装Godot 4.7.1稳定版（需与导出模板版本一致）。
2. 在Godot项目管理器中选择”导入”。
3. 打开本目录的 `project.godot`。
4. 按 `F6` 或右上角运行按钮。

项目使用Compatibility渲染器，目标分辨率为1280×720，方便低配置Windows电脑和后续Steam Deck测试。DEBUG构建（编辑器内运行、非Release导出）顶部会出现”开发”菜单，可直接跳转章节并热重载剧情JSON；正式Release导出通过 `OS.is_debug_build()` 判断自动隐藏该入口。

## 当前架构

- `autoload/game_state.gd`：版本化游戏状态、存档迁移/校验（`_migrate_and_validate`）与战斗发起/结算入口
- `autoload/save_manager.gd`：自动存档和三档手动存档，写入时临时文件+改名，失败自动回滚
- `autoload/settings_manager.gd`：音量、全屏、UI缩放、难度、按键重绑定、手柄导航
- `autoload/steam_service.gd`：读取 `data/steam_achievements.json`，桥接 `scripts/steam/{local,godot}_steam_backend.gd`，驱动成就解锁与统计上报
- `autoload/content_db.gd` + `data/story_content.json`：部分章节的对白与剧情JSON化（洛阳夜宴、峨眉入山等对白仍以字面量形式留在 `main.gd` 中，尚未完全迁移）
- `scripts/battle/`：战棋规则层（寻路、连线、AI目标选择）与执行层（技能、伤害、Boss阶段）——不依赖具体UI场景，均有对应单元测试
- `scripts/progression/`：修炼小游戏评分、专精境界、锻造、药谱/矿谱、切磋、战后奖励等纯规则脚本
- `scenes/ui/dialogue_view.tscn` / `choice_view.tscn`：独立对话与抉择界面，通过信号推进剧情
- `scenes/world/world_map_view.tscn` / `location_view.tscn`：独立天下舆图与通用地点界面
- `scenes/battle/tactical_battle_view.tscn`：独立战棋视图，负责棋盘、头像、范围颜色、操作栏和特效
- `main.gd`：流程协调器，持有屏幕状态机与尚未拆分为独立场景的程序化UI（设置、人物、成就、存档列表、结算与结局等界面）——这是仓库中最大的单文件，见下方”下一步”

华山试炼支持双人战棋：点击沈羽或林清霜切换当前角色，两人共享行动点并独立移动、普攻；敌方AI会优先接近距离最近的队员。林清霜拥有”霜华刺”（两格突进攻击）与”寒锋守势”（获得护卫并恢复真气）。流云剑法、霜华刺和寒锋守势都会积累熟练度，每使用三次提升对应伤害或护卫值。

第四章”峨眉迷踪”开场已接入：华山完成后解锁峨眉，可通过华山引荐、江湖声望或帮助山民三种方式入山；选择影响峨眉关系与后续事件。

## 下一步

现有69次提交已经走完了从网页版迁移到Steam垂直切片、再到内容完整版的路程；仍然开放的工作主要是架构收尾与Steam发行流程本身，而不是缺失的玩法系统：

1. **拆分 `main.gd` 剩余的程序化UI**——设置、人物、成就、存档列表、开发菜单等屏幕目前仍在 `main.gd` 内用代码直接搭建节点树；可仿照 `scenes/ui/dialogue_view.tscn` 等已完成的独立场景逐屏迁移。
2. **继续对白/任务数据JSON化**——`data/story_content.json` 只覆盖了部分对白事件，洛阳、峨眉、终章等章节的对白仍是 `main.gd` 里的字面量数组。
3. **Steam真机联调**——需要真实App ID才能推进：创建匹配的成就定义、启用GodotSteam现场适配器、验证云存档跨机同步与Overlay。完整清单见 `STEAM_RELEASE.md` 的”Live-integration gate”。
4. **发行前收尾**——正式图标品牌评审、Windows导出预设代码签名（`export_presets.cfg` 当前 `codesign/enable=false`）、以及 `ASSET_PROVENANCE.md`/`THIRD_PARTY_NOTICES.md` 的最终审阅，见 `BUILDING.md` 末尾。
