# 额外按键功能修复方案

## Context（背景）

移动端额外按键（`buttonExtra``buttonExtra4`~~，绑定~~ ~~`MobileInputID.EXTRA_1~4`，数量由~~ ~~`ClientPrefs.data.extraButtons`~~ ~~0~~4 控制）在游玩中被 [PlayState.onButtonPress / onButtonRelease](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/states/PlayState.hx#L6221-L6253) 里的 `EXTRA` 前缀判断**提前 return**，导致：

- 不触发音符判定（这是预期，不改变）

- **Lua/HScript 事件回调收不到**它们的按下/松开（需修复）

- **没有任何内置玩法动作**（需新增）

本次改动目标（用户已确认"两者都做"）：

1. 把额外按键的按下/松开**广播为 Lua/HScript 事件**（修复"接不到事件"）。
2. 新增**可配置的内置动作**（暂停/重开/返回），每个槽位可单独设置，默认 `None`（行为不改变，安全）。

现状补充：

- 脚本目前只能通过 `keyboardPressed(...)`/`checkExtraKeyState` [ExtraFunctions.hx#L299](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/psychlua/ExtraFunctions.hx#L299-L324) **轮询**读到这些键状态；事件路径是断的。

- 已绑定的虚拟键名存于 `ClientPrefs.data.extraKeyReturn1~4`。

## 改动清单

### 1. ClientPrefs：新增每槽内置动作字段

文件：`source/backend/ClientPrefs.hx`

- 新增 `public var extraAction1..extraAction4 : String = 'None';`（camelCase，与 `extraKeyReturn1~4` 命名风格一致，放入 `ClientPrefs.defaultData` 以便迁移）。

### 2. 语言文件：新增动作选项文案

文件：`assets/languages/zh_cn.json`、`en_us.json`、`zh_tw.json`

- 新增键：额外键给键位/槽位新增一行动作显示与选项文案，例如 `extra_bind_action`（"动作"标签）、`extra_action_none`（无）、`extra_action_pause`（暂停）、`extra_action_restart`（重开）、`extra_action_back`（返回）。

- 每个语言文件按现有 JSON 格式补 `"key": "value",`，与 `key_bind_exit` 等键保持一致。

### 3. MobileExtraControl：为每个槽位增加动作选择（循环切换）

文件：`source/mobile/substates/MobileExtraControl.hx`

- 在既有 4 个槽位下方/槽位内部新增一行"动作"显示：读取 `extraAction{n}` 并显示当前动作名（`extra_action_*` 本地化）。

- 点击该动作区 → 在 `[None, Pause, Restart, Back]` 间循环切换，写回 `extraAction{n}` 并 `ClientPrefs.saveSettings()`，同时在 `extraKeyReturn` 的写入逻辑（[L181-190](file:///e:/EXTRA/FNF/For%20Android/KathyEngine/source/mobile/substates/MobileExtraControl.hx#L181-L190)）风格保持一致。

- 布局细节实现时再定（在槽位下追加一行小按钮，避免与提示语/键位网格重叠）；禁用槽位（`i >= extraEnabled`）不显示/不可点。

### 4. PlayState：核心修复 —— 事件广播 + 内置动作分发

文件：`source/states/PlayState.hx`（`onButtonPress`/`onButtonRelease`，约 L6221-L6253）

- 移除对 `EXTRA` 的静默 early-return，改为：

  - 由按钮引用（`buttonExtra`\~`buttonExtra4`）定位槽位索引 `slot 0..3`（可用 `Reflect`/`getPropertyByName` 或显式 switch 判定，参照 TouchPad 字段名）。

  - **事件广播**：`callOnScripts('onExtraButtonPress', [slot, keyName])` / `('onExtraButtonRelease', [slot, keyName])`，其中 `keyName = ClientPrefs.data.extraKeyReturn{slot+1}`。保证 Mod/Lua 事件能收到。

  - **内置动作**：在刚按下边缘（`button.justPressed`）且非暂停/结束状态下，查 `extraAction{slot+1}` 并分发：

    - `Pause`  → `openPauseMenu()`（PlayState L4557，已有）

    - `Restart` → `PauseSubState.restartSong()`（PauseSubState L506，已有）

    - `Back`  → 退出到歌曲选择/主菜单（实现时确认沿用 Pause 菜单"返回"所用的跳转函数）

    - `None`/其它 → 不做任何事

  - 不触碰音符逻辑：`EXTRA` 按钮仍不进入 `keyPressed/keyReleased` 音符链路。

- 内置动作分发时机用 `justPressed` 边缘，避免按住每帧重复触发。

### 5. （可选）ExtraFunctions：暴露额外键专用 Lua 接口

文件：`source/psychlua/ExtraFunctions.hx`

- 保守起见本轮**不新增**独立 Lua 回调（已有 `checkExtraKeyState` 轮询 + 新增事件足够）。仅当需要按槽位直接查询时再补 `extraButtonJustPressed(index)` 等。

## 验证（Verification）

1. **编译**：执行引擎的 Haxe 编译（如 `lime build android` 或项目配置的编译命令）确认无语法/类型错误。
2. **事件**：写一个测试 Mod `.lua`，挂钩 `onExtraButtonPress(slot, keyName)` 并 `debugPrint`；进入歌曲、开启额外键（数量≥1）、按下额外按钮，确认控制台打印事件。
3. **内置动作（Pause）**：在额外控制设置页把槽位 1 的动作设为"暂停"；进歌后按该额外按钮，确认打开暂停菜单。
4. **内置动作（Restart/Back）**：类似步骤验证重开与返回。
5. **回归**：绑定虚拟键名后按额外按钮，确认 `keyboardPressed('SPACE')` 等轮询依然生效，且音符判定未被影响。

