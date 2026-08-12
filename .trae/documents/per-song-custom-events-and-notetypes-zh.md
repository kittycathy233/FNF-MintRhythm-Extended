# 曲目专属自定义事件与音符类型（Per-Song Custom Events & Note Types）

## 概述

本功能支持在 **data/曲名/** 文件夹内放置歌曲专属的自定义事件（custom_events）和音符类型（custom_notetypes），按歌曲粒度覆盖全局定义。在制谱器中，歌曲专属项目会以 **浅蓝色背景** 高亮标记，方便与全局项目区分。

## 目录结构

```
assets/shared/                         ← 全局（最低优先级）
├── custom_events/
│   └── 自定义事件.lua / .hx / .txt
├── custom_notetypes/
│   └── 自定义音符类型.txt
└── data/
    └── 曲名/                          ← 歌曲文件夹
        ├── custom_events/              ← 歌曲专属自定义事件
        │   ├── 自定义事件.lua          ← 事件脚本（Lua）
        │   ├── 自定义事件.hx           ← 事件脚本（HScript）
        │   └── 自定义事件.txt          ← 事件描述文本
        └── custom_notetypes/           ← 歌曲专属自定义音符类型
            ├── 自定义类型.txt          ← 音符类型配置
            ├── 自定义类型.lua          ← 音符脚本（可选）
            └── 自定义类型.hx           ← 音符脚本（可选）

mods/                                   ← 模组文件夹（相同结构）
├── 我的模组/
│   └── data/
│       └── 曲名/
│           ├── custom_events/
│           └── custom_notetypes/
```

## 优先级

1. **歌曲专属**（`data/曲名/custom_events/` 或 `custom_notetypes/`）— 优先查找
2. **全局**（`assets/shared/custom_events/` 或 `custom_notetypes/`）— 作为兜底

如果歌曲专属和全局存在**同名**文件，则**歌曲专属优先**，全局版本将被忽略。

## 工作原理

### 歌曲专属自定义事件

**游戏运行时（PlayState）：**
- 歌曲开始前，`PlayState.generateSong()` 扫描所有模组目录和共享资源中的 `data/曲名/custom_events/`
- 检测到的 `.lua` 文件通过 `FunkinLua` 加载
- 检测到的 `.hx` 文件通过 `initHScript` 加载
- 与全局事件脚本**同名**的脚本会被跳过（防止重复加载）

**制谱器：**
- 事件下拉菜单同时扫描歌曲专属和全局目录
- 歌曲专属事件的描述（`.txt`）优先于全局描述
- 歌曲专属事件在下拉菜单中以**浅蓝色背景**标记

### 歌曲专属自定义音符类型

**游戏运行时（NoteTypesConfig）：**
- `loadNoteTypeData(name)` 先查找歌曲专属 `custom_notetypes/名称.txt`
- 如果未找到则回退到全局 `custom_notetypes/名称.txt`

**制谱器：**
- 音符类型下拉菜单同时扫描两个目录
- 歌曲专属音符类型以**浅蓝色背景**标记

## 修改的文件

### 核心引擎
| 文件 | 修改内容 |
|------|---------|
| `source/states/PlayState.hx` | 在 `generateSong()` 中添加 per-song `custom_events/` 和 `custom_notetypes/` 扫描，优先于全局脚本加载 |
| `source/backend/NoteTypesConfig.hx` | 新增 `currentSongName` 静态变量；`loadNoteTypeData()` 先查找 per-song 路径，再回退全局 |
| `source/states/editors/ChartingState.hx` | 更新 `reloadNotesDropdowns()` 扫描 per-song 文件夹；新增 `_getSongDataFolder()` 辅助函数；标记 per-song 项目 |

### 制谱器 UI 组件
| 文件 | 修改内容 |
|------|---------|
| `source/backend/ui/PsychUIDropDownMenu.hx` | 新增 `markedIndices`、`markItem()`、`markItems()`；`PsychUIDropDownItem` 新增 `markedStyle` / `markedHoverStyle`（浅蓝色主题） |
| `source/states/editors/old/content/FlxUIDropDownMenuCustom.hx` | 新增 `markedIndices`、`markItem()`、`markItems()`、`clearMarks()`；标记背景渲染为独立的 `FlxSprite` 图层；更新 `setData()`、`updateButtonPositions()`、`set_visible()` |
| `source/states/editors/vanilla104/content/ui/VUIDropDownMenu.hx` | 与 `PsychUIDropDownMenu.hx` 相同的改动 |

### 制谱器集成
| 文件 | 版本 | 修改内容 |
|------|------|---------|
| `source/states/editors/ChartingState.hx` | 1.0.4-kathy | `reloadNotesDropdowns()` 扫描 per-song 文件夹，标记 per-song 项目 |
| `source/states/editors/old/OldChartingState073.hx` | 0.7.3 | `addNoteUI()` 和 `addEventsUI()` 扫描 per-song 文件夹，标记项目 |
| `source/states/editors/old/OldChartingState063.hx` | 0.6.3 | 与 0.7.3 相同 |
| `source/states/editors/vanilla104/ChartingState.hx` | vanilla 1.0.4 | `reloadNotesDropdowns()` + `_getSongDataFolder()` 辅助函数，标记 per-song 项目 |

## 视觉标记说明

制谱器下拉菜单中，per-song 项目用**浅蓝色背景**标记：
- **普通状态：** 浅蓝色（`0xFFB3E5FC`）+ 黑色文字
- **悬停状态：** 深蓝色（`0xFF0288D1`）+ 白色文字

全局项目保持原有样式（白色背景 / 蓝色悬停）。

## 使用示例

### 示例：为"Tutorial"添加歌曲专属自定义事件

```
mods/我的模组/
└── data/
    └── Tutorial/
        └── custom_events/
            ├── 闪屏.lua           ← 闪屏 Lua 脚本
            └── 闪屏.txt           ← 制谱器中显示的描述
```

**`闪屏.txt` 内容：**
```
触发时屏幕闪白
```

**`闪屏.lua` 内容：**
```lua
function onCreate()
    makeLuaSprite('whiteFlash', nil, 0, 0)
    makeGraphic('whiteFlash', 100, 100, 'FFFFFF')
    addLuaSprite('whiteFlash', true)
    setObjectCamera('whiteFlash', 'other')
    setProperty('whiteFlash.alpha', 0)
end

function onEvent(name, value1, value2)
    if name == '闪屏' then
        setProperty('whiteFlash.alpha', 1)
        doTweenAlpha('fadeFlash', 'whiteFlash', 0, 0.3)
    end
end
```

### 示例：添加歌曲专属自定义音符类型

```
mods/我的模组/
└── data/
    └── Tutorial/
        └── custom_notetypes/
            └── 钉子.txt
```

**`钉子.txt` 内容：**
```
TWEENS:0
HIT:250
DIFFICULTY:1.0
NOTE_TYPE:Spikes
SPAWN:0
BOP:0
```

## 补充说明

- 歌曲名从谱面 JSON 文件名提取（例如 `Tutorial.json` → `Tutorial`）
- Per-song 脚本在 `#if MODS_ALLOWED` 条件编译下加载
- 事件和音符类型均支持 Lua（`.lua`）和 HScript（`.hx`）
- `_getSongDataFolder()` 辅助函数通过 `Song.chartPath` 解析歌曲数据目录
- 标记索引独立于列表数据，可在 `setData()` 调用后存活

## 兼容性

- ✅ KathyEngine 1.0.4（新版制谱器）
- ✅ 旧版制谱器 v0.6.3
- ✅ 旧版制谱器 v0.7.3
- ✅ 原版 Psych Engine 1.0.4 制谱器
- ✅ 模组系统（`mods/模组名/data/曲名/`）
- ✅ 共享资源（`assets/shared/data/曲名/`）