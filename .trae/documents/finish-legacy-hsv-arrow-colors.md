# 完成旧版 HSV 箭头颜色渲染移植（剩余收尾工作）

## 摘要

上一个会话已批准并执行了「移植旧版 Psych v0.6.3 HSV 箭头颜色渲染逻辑」的方案。经核查，8 项任务中已完成 7 项（任务 #1–#7），仅剩任务 #8（VisualsSettingsSubState.hx 收尾）和任务 #9（构建验证）未完成。

**当前阻塞问题**：`VisualsSettingsSubState.hx` 第 43 行引用了 `onChangeArrowColorMode` 函数，但该函数尚未定义——这会导致编译失败。必须先补全此函数才能通过构建。

## 当前状态分析（已核查）

已确认完成的文件：

| 任务 | 文件 | 状态 |
|------|------|------|
| #1 | `source/shaders/ColorSwap.hx` | ✅ 已创建 |
| #2 | `source/backend/ClientPrefs.hx` | ✅ 已加 `arrowColorMode`/`arrowHSV` 字段（第 59、62 行）|
| #3 | `source/objects/Note.hx` | ✅ 已加 `colorSwap`/`globalColorSwapShaders`/`defaultHSV`/`initializeGlobalColorSwapShader`，HSV 分支齐全 |
| #4 | `source/objects/StrumNote.hx` | ✅ 已加 `colorSwap` 字段及构造/playAnim 的 HSV 分支 |
| #5 | `source/objects/NoteSplash.hx` | ✅ 已加 `colorSwap` 字段及 spawnSplashNote 的 HSV 分支 |
| #6 | `source/options/NotesColorSubStateLegacy.hx` | ✅ 已创建 |
| #7 | `source/options/OptionsState.hx` | ✅ 第 91 行已根据 `arrowColorMode` 路由到 Legacy/新版子状态 |
| #8 | `source/options/VisualsSettingsSubState.hx` | ⚠️ **部分完成**：开关选项已加（第 37-43 行），但 `onChangeArrowColorMode` 函数缺失，`destroy()` 未重置 `globalColorSwapShaders` |
| #9 | 构建验证 | ❌ 未执行 |

## 剩余改动

### 改动 1：在 VisualsSettingsSubState.hx 中添加 `onChangeArrowColorMode()` 函数

**文件**：[VisualsSettingsSubState.hx](file:///e:\EXTRA\FNF\For Android\KathyEngine\source\options\VisualsSettingsSubState.hx)

**位置**：在第 327 行 `onChangePauseMusic` 函数结束后、第 329 行 `onChangeNoteSkin` 函数开始前插入。

**原因**：第 43 行 `option.onChange = onChangeArrowColorMode;` 已引用该函数，缺失会导致编译错误。切换颜色模式时需重建预览 strums/splashes，使它们走对应的着色器路径（HSV 用 `ColorSwap`，RGB 用 `RGBPalette`），尤其保证切换到 HSV 后再触发 Note Splash 预览时走 HSV 渲染分支。

**插入代码**：

```hx
	function onChangeArrowColorMode()
	{
		// Clear both shader caches so new strums/splashes pick the correct path
		Note.globalRgbShaders = [];
		Note.globalColorSwapShaders = [];

		notes.forEachAlive(function(n) n.destroy());
		notes.clear();
		splashes.forEachAlive(function(s) s.destroy());
		splashes.clear();

		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);

			var splash:NoteSplash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
		}
	}
```

这段逻辑与第 20-34 行 `new()` 中创建预览 strums/splashes 的代码一致，保证切换模式后预览对象与初始化状态对齐。

### 改动 2：在 `destroy()` 中重置 `globalColorSwapShaders`

**文件**：同上

**位置**：第 404 行 `Note.globalRgbShaders = [];` 之后追加一行。

**原因**：退出 Visuals 设置时需清理 HSV 全局着色器缓存（与 RGB 缓存清理对称），避免下次进入时残留旧实例。

**改动后**：

```hx
	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		Note.globalRgbShaders = [];
		Note.globalColorSwapShaders = [];
		super.destroy();
	}
```

## 假设与决策

- **`onChangeArrowColorMode` 重建策略**：完全销毁并重建 notes/splashes 组，而非就地切换着色器。理由：StrumNote 构造函数会根据 `arrowColorMode` 走不同分支创建 `colorSwap` 或 `rgbShader`，重建最简单且与初始化路径一致；就地切换需在 StrumNote/NoteSplash 上补一套切换逻辑，复杂度更高且无收益。
- **预览 strum 为 static 状态**：HSV 模式下 static 会把 `shader` 设为 null（无偏移），故 strum 本身视觉上无差异；但重建保证后续触发 Note Splash 预览时 splash 走 HSV 路径正确渲染。
- **不动其他已完成的 7 个文件**：经 grep 核查它们的 HSV 集成点齐全，无需再改。

## 验证步骤

1. 完成上述两处编辑后，执行构建：
   ```
   lime build windows -D officialBuild
   ```
   （必须带 `-D officialBuild`，否则 `PlayState.hx` 引用的 `funkin.vis` 会导致编译失败——这是项目已知约束。）
2. 确认无编译错误（重点关注 `onChangeArrowColorMode` 是否被正确解析为函数）。
3. 启动游戏，进入 Options → Visuals Settings，将 "Arrow Color Mode" 切换为 HSV，确认：
   - 切换时无崩溃
   - 再进入 Options → Note Colors，应打开旧版 HSV 三列（Hue/Saturation/Brightness）UI
   - 改回 RGB，Note Colors 子状态恢复新版 RGB 调色板 UI
