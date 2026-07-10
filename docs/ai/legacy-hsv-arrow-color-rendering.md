# 旧版 HSV 箭头颜色渲染移植 —— KathyEngine

**项目**: KathyEngine（基于 Psych Engine）
**日期**: 2026-07-10
**涉及 AI**: TRAE AI Assistant（基础移植）+ CodeBuddy（解析器重写与修复）

---

## 概述

本文档汇总了将 Psych Engine v0.6.3 旧版 HSV（色相/饱和度/亮度）箭头颜色渲染系统移植到 KathyEngine 的所有改动，以及 CodeBuddy 在此基础上做的一系列改进和 bug 修复。

---

## 第一部分：基础移植（TRAE AI Assistant）

---

### 1. 核心 HSV 着色器实现

#### 新建文件

##### `source/shaders/ColorSwap.hx`
- 从旧版 PE v0.6.3 ColorSwap 着色器逐字移植
- 包含 `ColorSwap` 类，通过 hue/saturation/brightness setter 写入着色器 uniform 值
- 包含 `ColorSwapShader` 类，内含 GLSL HSV 变换逻辑：rgb2hsv → 叠加色相/饱和度、乘法亮度 → hsv2rgb
- 提供 `copyValues()` 方法用于复制着色器状态

##### `source/options/NotesColorSubStateLegacy.hx`
- 旧版 PE `NotesSubState.hx` 的移植，适配 KathyEngine
- 使用 `ClientPrefs.data.arrowHSV` 存储 HSV 值
- 使用 `Note.globalColorSwapShaders[i]` 进行实时预览
- UI 布局：4 个音符纵向排列，搭配 H/S/B 三列数字输入
- 使用 `CoolUtil.getCachedGrid()` 作为背景
- 使用 `addTouchPad('LEFT_FULL', 'A_B_C')` 处理控制器输入
- `destroy()` 中重置 `Note.globalColorSwapShaders = []`

#### 修改文件

##### `source/backend/ClientPrefs.hx`
- 新增 `arrowColorMode:String = 'RGB'` — 确定渲染模式（`'RGB'` 或 `'HSV'`）
- 新增 `arrowHSV:Array<Array<Int>>` — 旧版 HSV 箭头颜色（4 方向 × [色相, 饱和度, 亮度]）
  - 范围：色相 -180..180，饱和度/亮度 -100..100
  - 全部为 0 = 无偏移（纹理按原样渲染）

##### `source/objects/Note.hx`
- 新增 `import shaders.ColorSwap;`
- 新增字段：
  - `public var colorSwap:ColorSwap;`
  - `public static var globalColorSwapShaders:Array<ColorSwap> = [];`
  - `public var noteSplashHue:Float = 0;`
  - `public var noteSplashSat:Float = 0;`
  - `public var noteSplashBrt:Float = 0;`
- 新增 `defaultHSV()` 方法 —— 从 arrowHSV 值设置 colorSwap
- 新增 `initializeGlobalColorSwapShader(noteData:Int):ColorSwap` 静态方法
- 构造函数新增 HSV/RGB 分支
- `set_noteType` 修改：`if(ClientPrefs.data.arrowColorMode == 'HSV') defaultHSV(); else defaultRGB();`
- Hurt Note 分支：HSV 下创建局部的 `new ColorSwap()`，避免污染全局共享着色器

##### `source/objects/StrumNote.hx`
- 新增 `import shaders.ColorSwap;`
- 新增 `public var colorSwap:ColorSwap;` 字段
- 构造函数：HSV 分支创建 `colorSwap = Note.initializeGlobalColorSwapShader(leData);`
- `playAnim`：HSV 分支按动画类型切换着色器

##### `source/objects/NoteSplash.hx`
- 新增 `import shaders.ColorSwap;`
- 新增 `public var colorSwap:ColorSwap;` 字段
- 构造函数：`colorSwap = new ColorSwap();`（每个飞溅局部拥有）
- `spawnSplashNote`：HSV/RGB 分支 —— HSV 从 `ClientPrefs.data.arrowHSV[nd]` 计算色值，由 `note.noteSplashHue/Sat/Brt` 覆写

##### `source/options/OptionsState.hx`
- 修改 `openSelectedSubstate()`：根据 `ClientPrefs.data.arrowColorMode` 条件性打开 `NotesColorSubStateLegacy` 或 `NotesColorSubState`

##### `source/options/VisualsSettingsSubState.hx`
- 在 noteSkins 区块之前新增 "Arrow Color Mode" 选项
- 新增 `onChangeArrowColorMode()` —— 清除着色器缓存并重建预览笔记/飞溅
- 修改 `changeNoteSkin()` —— 使用 `getNoteSkinPath()` 并同时检查 HSV/RGB 路径
- 修改 `destroy()` —— 重置 `Note.globalColorSwapShaders = []`

---

### 2. 多语言支持

#### 修改文件

##### `assets/languages/en_us.json`
新增条目：
- `"charting_disRGB_text": "Disable Note RGB"`
- `"charting_disRGB_text_hsv": "Disable Note RGB (HSV mode active)"`
- `"arrow_colormode_name": "Arrow Color Mode:"`
- `"arrow_colormode_desc": "RGB = new palette colors; HSV = legacy Psych v0.6.3 hue/saturation/brightness shift"`

##### `assets/languages/zh_cn.json`
新增条目：
- `"charting_disRGB_text": "禁用音符RGB效果"`
- `"charting_disRGB_text_hsv": "禁用音符RGB效果（HSV模式已启用）"`
- `"arrow_colormode_name": "箭头颜色模式："`
- `"arrow_colormode_desc": "RGB = 新调色板颜色；HSV = 旧版Psych v0.6.3色相/饱和度/亮度偏移"`

##### `source/options/VisualsSettingsSubState.hx`
- 将硬编码的 `"Arrow Color Mode:"` 替换为 `Language.get("arrow_colormode_name")`
- 将硬编码的描述替换为 `Language.get("arrow_colormode_desc")`

---

### 3. 制谱器 HSV 警告

#### 修改文件

##### `source/states/editors/ChartingState.hx`
- "Disable Note RGB" 复选框文本修改：
  - RGB 模式：`"Disable Note RGB"`
  - HSV 模式：`"Disable Note RGB (HSV mode active)"`，alpha = 0.5
- 修改 `updateNotesRGB()` —— 当 `arrowColorMode == 'HSV'` 时提前返回，防止干扰

---

### 4. HSV 皮肤/飞溅资源支持（TRAE 初版）

当 `arrowColorMode == 'HSV'` 时：
- **箭头皮肤**：检查 `images/noteSkins/hsv/` 目录，回退到 `images/noteSkins/`
- **箭头飞溅**：检查 `images/noteSplashes/hsv/` 目录，回退到 `images/noteSplashes/`
- **模组兼容**：通过 `Paths.fileExists()` 自动搜索模组目录
- **无额外后缀**：皮肤名称在两种模式下保持一致，路径解析对用户透明

相关改动文件：
- `source/objects/Note.hx` → `getNoteSkinPath(basePath)`
- `source/objects/NoteSplash.hx` → `getSplashSkinPath(basePath)`
- `source/options/VisualsSettingsSubState.hx` → `changeNoteSkin()` 使用 `getNoteSkinPath()`

---

### 5. Bug 修复（TRAE）

#### Haxe 正则语法修复
- **问题**：`String.replace()` 中使用了 JavaScript 风格的 `/pattern/flags` 语法，Haxe 不支持
- **解决**：替换为 `new EReg(pattern, flags).replace(string, replacement)`
- **涉及文件**：`Note.hx`、`NoteSplash.hx`、`VisualsSettingsSubState.hx`

#### FlxG.resetState() 修复
- **问题**：`FlxG.resetState()` 会重置父状态（OptionsState），导致未保存的修改丢失
- **解决**：移除 `FlxG.resetState()`，在 `onChangeArrowColorMode()` 中恢复手动预览重建循环

---

## 第二部分：改进与修复（CodeBuddy）

> 以下改进基于 TRAE 的基础移植之上，主要解决模组优先序、HSV 纹理解析缓存、以及切换模式后皮肤不重载等问题。

---

### 6. 统一皮肤路径解析器 `resolveSkinPath`

**文件**：`source/objects/Note.hx`

**背景**：TRAE 初版的 `getNoteSkinPath` 和 `getSplashSkinPath` 实现较为简单——仅检查 `hsv/` 文件是否存在（全局检查，不区分模组与原版）。这会导致一个严重问题：如果游玩某模组时模组只提供了白底默认箭头（`noteSkins/NOTE_assets.png`）而没有 `hsv/` 版本，旧逻辑会错误回退到**原版游戏的 hsv 箭头**，模组的箭头样式被覆盖丢失。

**新增内容**：

- **`static var _skinPathCache:Map<String, String>`** — 全局皮肤路径缓存，键为 `当前模组:arrowColorMode:基底路径`，避免每个音符/每帧重复调用 `FileSystem.exists`

- **`resolveSkinPath(basePath:String):String`** — 统一的 HSV 皮肤路径解析器，严格按以下优先序解析：

  | 优先级 | 来源 | 示例路径 |
  |--------|------|----------|
  | ① | 模组 `hsv/` | `mods/(mod)/images/noteSkins/hsv/NOTE_assets-funkarchive.png` |
  | ② | 模组默认 | `mods/(mod)/images/noteSkins/NOTE_assets-funkarchive.png` |
  | ③ | 原版 `hsv/` | `assets/shared/images/noteSkins/hsv/NOTE_assets-funkarchive.png` |
  | ④ | 原版默认（默认回退） | `assets/shared/images/noteSkins/NOTE_assets-funkarchive.png` |

  非 HSV 模式直接返回 `basePath`，由 `Paths.getSparrowAtlas` 自带模组优先逻辑加载。

- **`skinFileExists(relPath:String, modsOnly:Bool):Bool`** — 辅助函数，`modsOnly=true` 仅检查当前模组目录 + 全局模组；`false` 时还会回退检测原版资源（通过 `Paths.fileExists(..., ignoreMods=true)`）

- **`getNoteSkinPath()` 改为委托到 `resolveSkinPath()`**，保证 StrumNote / 流动音符 / 飞溅使用完全一致的纹理解析路径

---

### 7. 修复 `Note.reloadNote()` 的 HSV 皮肤存在检测

**文件**：`source/objects/Note.hx`

**背景**：TRAE 初版 `reloadNote` 的 `customExists` 检查只有一句概括性的 `Paths.fileExists`，不区分 HSV/RGB。在 HSV 模式下当一个模组提供了基底 `NOTE_assets.png`（白底）且用户选了非默认皮肤（如 funkarchive）时，可能检测失败导致不正确的回退。

**改进**：

- 在 `customExists` 判断中新增**完整的 HSV 分支**（`else if(ClientPrefs.data.arrowColorMode == 'HSV')`）：
  1. 先检查 `images/<folder>/hsv/<filename>.png`（模组优先 → 原版回退）
  2. 再检查 `images/<fullCustomSkin>.png`（模组优先 → 原版回退）
- 将最终加载语句从 `Paths.getSparrowAtlas(skin)` 改为 `Paths.getSparrowAtlas(getNoteSkinPath(skin))`，确保真正加载时走 `resolveSkinPath` 的完整优先序解析

---

### 8. 统一飞溅皮肤路径解析

**文件**：`source/objects/NoteSplash.hx`

**背景**：TRAE 初版为飞溅单独维护了一份类似的 hsv 目录检查逻辑（`getSplashSkinPath`），与箭头的逻辑分开但本质相同。这容易导致未来两边不同步的问题。

**改进**：

- `getSplashSkinPath()` 直接委托 `Note.resolveSkinPath(basePath)`
- `loadSplash()` 中所有 splash 路径（默认、歌曲指定、自定义）都经过 `getSplashSkinPath()` 包装，确保箭头与飞溅在任意场景下使用同一套优先序

---

### 9. StrumNote `playAnim` 着色器行为优化

**文件**：`source/objects/StrumNote.hx`

**背景**：TRAE 初版中，`playAnim` 的 HSV 分支写法为：
```haxe
shader = (anim != 'static') ? colorSwap.shader : null;
```
即 static（静止）状态不挂载 ColorSwap。这导致静止箭头看起来像是「未着色」，与流动音符行为不一致——用户修改 `arrowHSV` 后流动箭头变色了但静止箭头还是原色。

**改进**：

```haxe
// 当前版本（CodeBuddy 优化）：
if(ClientPrefs.data.arrowColorMode == 'HSV' && colorSwap != null) {
    shader = colorSwap.shader;  // 始终挂载，hue=0 时原样显示
}
```

效果：HSV 模式下静止箭头也始终挂在 ColorSwap 着色器上。当 `arrowHSV` 全部为 0（默认）时，hue=0/sat=0/brt=0 为恒等变换（纹理原样），不会产生肉眼可见的差异；但当用户调整 HSV 颜色后，静止箭头立即同步变色，与编辑器预览和流动音符保持一致。

---

### 10. 修复 `_skinPathCache` 缓存键遗漏 `arrowColorMode`

**文件**：`source/objects/Note.hx`

**问题**：`_skinPathCache` 最初实现时的缓存键格式为 `当前模组:基底路径`，缺少 `arrowColorMode` 维度。由于此缓存是 **static**（类级别），横跨 PlayState 重建持续存在。于是：

1. 在 RGB 模式下游玩一次 → 缓存 `mod:noteSkins/NOTE_assets-funkarchive → noteSkins/NOTE_assets-funkarchive`
2. 暂停 → 进入设置 → 切换到 HSV → 返回（`OptionsState.onPlayState` 触发 `new PlayState()` 重建）
3. `resolveSkinPath` 被调用 → 命中旧缓存 → 返回 RGB 基底路径 → **永远解析不到 `hsv/` 纹理**

这导致即使代码逻辑正确、资源也存在，切换模式后皮肤纹理始终停留在切换前的那一套。

**修复**：缓存键改为 `mod:arrowColorMode:basePath`（如 `aoharuTT:HSV:noteSkins/NOTE_assets-funkarchive`），RGB 与 HSV 的缓存隔离，互不污染。

---

## 第三部分：配置与架构

---

### 11. 默认值

- `arrowColorMode`：`'RGB'`（新调色板颜色）
- `arrowHSV`：`[[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]]`（无颜色偏移）

### 12. 模式切换

1. 进入 Options → Visuals Settings
2. 修改 "Arrow Color Mode" 为 `'HSV'` 或 `'RGB'`
3. 设置内预览立即刷新（`onChangeArrowColorMode` 重建 notes/splashes）
4. 返回游玩时游戏重建 PlayState（`loadingState.loadAndSwitchState(new PlayState())`），所有箭头和飞溅按新模式重新解析纹理

### 13. 着色器模式

| 模式 | 着色器 | 着色方式 | 适用皮肤纹理 |
|------|--------|----------|-------------|
| RGB | `RGBPalette` | 替换 R/G/B 通道 | 白底/任意底色 |
| HSV | `ColorSwap` | 色相偏移 + 饱和度叠加 + 亮度乘法 | **白底可重着色**（`hsv/` 目录） |

- **全局共享着色器**：每个方向一个 `ColorSwap`/`RGBPalette` 实例，该方向所有音符/箭头共享
- **逐精灵开关**：`shader` 为 null 时不应用着色；非 null 时应用
- **Hurt Note 例外**：HSV 下创建局部的 `new ColorSwap()`（hue/sat/brt = 0），避免污染全局共享着色器

### 14. 资源路径解析

| 模式 | 优先序 |
|------|--------|
| HSV | ① 模组 `hsv/` → ② 模组默认 → ③ 原版 `hsv/` → ④ 原版默认 |
| RGB | ① 模组默认 → ② 原版默认（`Paths.getSparrowAtlas` 自带） |

### 15. 模组支持

模组可通过创建以下目录提供 HSV 专用资源：
- `mods/{modname}/images/noteSkins/hsv/`
- `mods/{modname}/images/noteSplashes/hsv/`

无需修改模组代码 —— 路径解析（`resolveSkinPath`）自动发现这些资源并按优先序使用。

### 16. 从设置返回游戏时的重载行为

当从 Options 返回 PlayState 时，触发流程为：
```
PauseSubState → switchState(new OptionsState())
  → OptionsState.onPlayState = true
  → 用户修改设置
  → 按返回
  → LoadingState.loadAndSwitchState(new PlayState())
```

这是一个**完全重建**的 PlayState，所有 `StrumNote`、`Note`、`NoteSplash` 都会重新 `new` 并走最新设置的纹理解析。注意 `_skinPathCache` 为 static 缓存（跨 PlayState 存活），其键已包含 `arrowColorMode`，确保模式切换时新旧缓存隔离。

---

## 完整文件清单

| 类型 | 文件 | 涉及方 |
|------|------|--------|
| 新建 | `source/shaders/ColorSwap.hx` | TRAE |
| 新建 | `source/options/NotesColorSubStateLegacy.hx` | TRAE |
| 修改 | `source/backend/ClientPrefs.hx` | TRAE |
| 修改 | `source/objects/Note.hx` | TRAE + **CodeBuddy** |
| 修改 | `source/objects/StrumNote.hx` | TRAE + **CodeBuddy** |
| 修改 | `source/objects/NoteSplash.hx` | TRAE + **CodeBuddy** |
| 修改 | `source/options/OptionsState.hx` | TRAE |
| 修改 | `source/options/VisualsSettingsSubState.hx` | TRAE |
| 修改 | `source/states/editors/ChartingState.hx` | TRAE |
| 修改 | `assets/languages/en_us.json` | TRAE |
| 修改 | `assets/languages/zh_cn.json` | TRAE |

---

## CodeBuddy 改动速查

| 小节 | 改动 | 效果 |
|------|------|------|
| §6 | `resolveSkinPath` + `_skinPathCache` | HSV 下严格按「模组→原版、hsv→默认」优先序加载纹理；缓存避免重复 I/O |
| §6 | `skinFileExists()` | 精确控制模组与原版的搜索范围 |
| §7 | `reloadNote()` HSV `customExists` | 修复模组只有基底皮肤时仍错误回退到原版 hsv 的问题 |
| §7 | `Paths.getSparrowAtlas(getNoteSkinPath(skin))` | 最终加载走完整优先序 |
| §8 | `getSplashSkinPath → Note.resolveSkinPath` | 飞溅与箭头共用同一套解析器，消除重复逻辑 |
| §9 | `playAnim` 始终挂载 ColorSwap | 静止箭头与流动箭头着色一致 |
| §10 | 缓存键加入 `arrowColorMode` | 修复 RGB↔HSV 切换后纹理不更新的 static 缓存污染问题 |
