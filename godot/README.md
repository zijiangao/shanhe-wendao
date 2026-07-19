# 山河问道 Godot Steam版

这是与现有网页版并存的独立Godot 4工程。当前垂直切片包含：

- 主菜单与自动存档
- 青云门修炼
- 天下地图旅行
- 黑苇渡五格回合战斗
- 三档本地存档
- 现有水墨地图、战斗背景和角色立绘

## 运行

1. 安装Godot 4稳定版。
2. 在Godot项目管理器中选择“导入”。
3. 打开本目录的 `project.godot`。
4. 按 `F6` 或右上角运行按钮。

项目使用Compatibility渲染器，目标分辨率为1280×720，方便低配置Windows电脑和后续Steam Deck测试。

## 下一步

1. 在Godot编辑器中运行并修复首次导入发现的问题。
2. 将程序化UI逐步拆成可视化场景。
3. 迁移对话系统、任务数据和洛阳章节。
4. 接入手柄焦点导航。
5. 建立Windows导出预设与Steam测试App配置。

## 当前架构

- `autoload/game_state.gd`：版本化游戏状态与存档迁移入口
- `autoload/save_manager.gd`：自动存档和三档手动存档
- `autoload/content_db.gd`：剧情JSON加载与查询
- `data/story_content.json`：章节信息和已迁移对白
- `scenes/ui/dialogue_view.tscn`：独立对话界面，通过信号推进剧情
- `scenes/ui/choice_view.tscn`：独立抉择界面，通过信号返回选项
- `scenes/world/world_map_view.tscn`：独立天下舆图，只发送旅行、进入地点和调息请求
- `scenes/world/location_view.tscn`：通用地点界面，根据行动数据生成可交互热点
- `scenes/battle/tactical_battle_view.tscn`：独立战棋视图，负责棋盘、头像、范围颜色、操作栏和特效
- `main.gd`：当前流程协调器与战斗规则层；寻路、伤害、AI和结算不依赖战棋视图

华山试炼支持双人战棋：点击沈羽或林清霜切换当前角色，两人共享行动点并独立移动、普攻；敌方AI会优先接近距离最近的队员。

林清霜拥有“霜华刺”（两格突进攻击）与“寒锋守势”（获得护卫并恢复真气）。流云剑法、霜华刺和寒锋守势都会积累熟练度，每使用三次提升对应伤害或护卫值。

第四章“峨眉迷踪”开场已接入：华山完成后解锁峨眉，可通过华山引荐、江湖声望或帮助山民三种方式入山；选择影响峨眉关系与后续事件。

DEBUG构建顶部包含“开发”菜单，可直接跳转章节并热重载剧情JSON。正式Release导出不会显示该入口。
