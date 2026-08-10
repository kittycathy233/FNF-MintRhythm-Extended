---
name: keyviewerposstate_mobile_touchpad_fix
overview: 修复 KeyViewerPosState 在移动端缺少返回/重置（B/C）虚拟按键的问题，评估并改用更健壮的 FlxVirtualPad 方案，使移动端操作与其余 State 一致。
todos:
  - id: confirm-virtualpad-api
    content: 使用 [subagent:code-explorer] 确认 FlxVirtualPad 的 FlxActionMode 枚举与 B/C 按钮接口
    status: completed
  - id: replace-touchpad-with-virtualpad
    content: 修改 KeyViewerPosState，移除 TouchPad 调用并加入 FlxVirtualPad（B_C）
    status: completed
    dependencies:
      - confirm-virtualpad-api
  - id: rewire-input-and-cleanup
    content: 将 update/destroy 中 touchPad 判读改为 _virtualpad 并清理资源
    status: completed
    dependencies:
      - replace-touchpad-with-virtualpad
---

## 用户需求

针对 `source/options/KeyViewerPosState.hx` 这个 KeyViewer 位置校准界面，移动端缺少「返回(B)」与「重置(C)」虚拟按键，而项目内其它 state 的虚拟按钮正常。需要修复该 state 在移动端的返回/重置操作，使其与项目内其它界面表现一致，并评估用户提出的改用 `virtualpad` 方案。

## 产品概述

KeyViewerPosState 是一个用于拖动校准游戏中 KeyViewer 面板位置的界面。当前在移动端（Android）进入时，底部应有的 B（返回并保存）与 C（重置为默认位置）虚拟按钮不显示，导致用户无法在移动端退出或重置该界面。

## 核心特性

- 移动端必须显示可用的「返回(B)」与「重置(C)」虚拟按键。
- 点击 B 触发 `commitSave()` 并返回 OptionsState；点击 C 将偏移量重置为 0 并重建 KeyViewer。
- 按钮需始终渲染在界面最上层，不被背景或 KeyViewer 面板遮挡。
- 与项目内其它 state（如编辑器）一致的 virtualpad 交互方式，避免依赖易失效的 touchPadCam 与手动坐标重定位。

## 技术栈

- 语言：Haxe（OpenFL / Flixel），目标平台 Android。
- 现有虚拟输入组件：`backend.MusicBeatState.addTouchPad`（基于 `mobile.objects.TouchPad`）、`android.FlxVirtualPad`（基于 `FlxSpriteGroup`）。
- 参考示例：`source/states/editors/old/OldChartingState073.hx` 中 `new FlxVirtualPad(FlxDPadMode.CHART_EDITOR, FlxActionMode.CHART_EDITOR)` 的用法。

## 实现方式

采用**方案 B（改用 FlxVirtualPad）**，理由：当前 TouchPad 方案依赖 `addTouchPadCamera()` 创建的独立相机，而 `MusicBeatState.create()` → `initPsychCamera()` 会在已初始化后跳过相机重置，使 touchPad 渲染层级与坐标定位非常脆弱；同时 KeyViewerPosState 未设置 `controls.isInSubstate`，与能正常工作的 NotesColorSubState/BaseOptionsMenu 不同。相比之下，`FlxVirtualPad` 作为 `FlxSpriteGroup` 直接 `add` 进 state 成员列表，渲染始终在最上层，无需单独相机，且项目内编辑器界面已验证该方式稳健，符合用户倾向。

### 关键技术决策

1. **移除原 TouchPad 调用**：删除 `create()` 中的 `addTouchPad('NONE','B_C')`、`addTouchPadCamera()` 及 `buttonB/buttonC` 手动坐标重定位；删除 `update()` 中与 `touchPad` 相关的判读；删除 `update()` 末尾的 `touchPad == null` 兜底重建块。
2. **加入 FlxVirtualPad**：在 `create()` 中构造 `new FlxVirtualPad(FlxDPadMode.NONE, FlxActionMode.B_C)` 并 `add` 进 state，持有 `_virtualpad` 引用。需先读取 `source/android/FlxVirtualPad.hx` 确认 `FlxActionMode` 枚举是否含 `B_C`（应与 `mobile/ActionModes/B_C.json` 同名 key；若枚举仅含固定几项，则改用 `FlxActionMode.NONE` 并手动用 `addButton` 或拼装 B/C，或沿用 `FlxActionMode` 中可表达 B+C 的项）。
3. **按钮定位**：将 `_virtualpad` 整体锚定到右下角（设置 `x/y` 或缩放后对齐），保证 B 在右下、C 在左下，符合现有移动端操作直觉；若 `FlxVirtualPad` 默认布局已合理，则直接使用默认。
4. **输入监听**：在 `update()` 中将 `touchPad.buttonB.justPressed` 替换为 `_virtualpad.buttonB.justPressed`，`touchPad.buttonC.justPressed` 替换为 `_virtualpad.buttonC.justPressed`；桌面端继续保留 `controls.BACK`、`FlxG.keys.justPressed.R`。
5. **清理**：`destroy()` 中移除并销毁 `_virtualpad`（参照 MusicBeatState 已有 `removeTouchPad`，无需额外处理 touchPadCam）。

### 性能与可靠性

- virtualpad 为轻量 `FlxSpriteGroup`，每帧仅做按钮命中检测，开销可忽略；不引入额外相机，避免相机重置导致的渲染错位。
- 保留原「脏标记 + 延迟合并写入」存档逻辑不变，仅替换输入来源，不影响已验证的存档安全设计。
- 退出路径（`controls.BACK` 与 B 键）统一调用 `commitSave()` + `switchState`，保持单一退出出口。

## 实现注意事项

- 必须确认 `FlxVirtualPad.FlxActionMode` 枚举项名称（读取源码），避免传入不存在的枚举导致编译失败。
- 若 `FlxActionMode` 无 `B_C`，采用「`FlxActionMode.NONE` + 手动添加 B/C 按钮」或选用含 B、C 的既有枚举组合，保证语义正确。
- 重定位 `_virtualpad` 时优先使用相对 `FlxG.width/FlxG.height` 的右下锚定，避免硬编码像素导致不同分辨率错位。
- 桌面端判定逻辑（`controls.BACK`、`FlxG.keys.justPressed.R`）完全保留，确保 PC 行为不变。

## 架构设计

仅修改 `KeyViewerPosState` 单文件，复用项目已有 `FlxVirtualPad` 组件，不改动 `MusicBeatState` 基类与 `TouchPad` 体系，blast radius 最小化。移动端虚拟输入从「TouchPad + touchPadCam」切换为「FlxVirtualPad（SpriteGroup）」，与其它编辑器 state 保持一致模式。

## 目录结构

```
source/options/
└── KeyViewerPosState.hx   # [MODIFY] 移除 TouchPad/touchPadCam 调用与手动坐标重定位；改为创建并持有 FlxVirtualPad(_virtualpad)；update() 改用 _virtualpad.buttonB/buttonC.justPressed；destroy() 中清理 _virtualpad。桌面逻辑保留。
```

（仅此一个文件需修改；`source/android/FlxVirtualPad.hx` 仅作为只读参考，确认 `FlxActionMode`/`FlxDPadMode` 枚举与 `addButton` 接口，不做改动。）

## 关键代码结构

需在执行前于 `source/android/FlxVirtualPad.hx` 中确认：

- `enum FlxDPadMode { NONE; ... }`
- `enum FlxActionMode { ..., B_C, ... }`（或确认是否仅支持固定集合）
- `public function new(dpadMode:FlxDPadMode, actionMode:FlxActionMode)`
- `public var buttonB:FlxButton; public var buttonC:FlxButton;`

## Agent Extensions

### SubAgent

- **code-explorer**
- 用途：读取 `source/android/FlxVirtualPad.hx`，精确确认 `FlxDPadMode`、`FlxActionMode` 枚举项（尤其是否含 `B_C`）以及 `buttonB`/`buttonC` 字段与构造函数签名，避免编译期错误。
- 预期结果：给出 `FlxVirtualPad` 构造的确切参数与 B/C 按钮访问方式，供 KeyViewerPosState 修改使用。