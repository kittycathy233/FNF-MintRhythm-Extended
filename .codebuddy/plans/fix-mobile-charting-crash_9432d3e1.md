---
name: fix-mobile-charting-crash
overview: 修复 KathyEngine 移动端制谱器中 TouchButton 崩溃、按钮渲染异常以及 1.0.4 制谱器启动崩溃的问题。
todos:
  - id: guard-null-camera
    content: 在 TouchButton.checkTouchOverlap 中跳过 null/已销毁摄像头
    status: completed
  - id: assign-button-cameras
    content: 在 MusicBeatState 与 MusicBeatSubstate 的 addTouchPadCamera 中为每个 TouchButton 设置 cameras
    status: completed
    dependencies:
      - guard-null-camera
  - id: fix-charting-tab-nulls
    content: 修复 ChartingState.addChartingTab 在移动端添加 null 复选框导致的崩溃
    status: completed
  - id: add-touchpad-camera
    content: 在 ChartingState.create 中为移动端调用 addTouchPadCamera
    status: completed
    dependencies:
      - assign-button-cameras
  - id: typecheck-verify
    content: 使用 [subagent:code-explorer] 验证所有 charting 状态的 touchPad 初始化并执行类型检查
    status: completed
    dependencies:
      - guard-null-camera
      - assign-button-cameras
      - fix-charting-tab-nulls
      - add-touchpad-camera
---

## 产品概述

修复 KathyEngine 移动端制谱器（Charting Editor）的多处崩溃与渲染异常，确保 0.6.3、0.7.3、1.0.4-Kathy 等版本在移动设备上能正常打开、触控按钮可用且渲染正确。

## 核心功能

- 修复 0.6.3 / 0.7.3 制谱器中按触控按钮即崩溃的问题
- 修复移动端制谱器按钮渲染异常
- 修复 1.0.4-Kathy 制谱器启动时 `FlxSpriteGroup.preAdd` 空引用崩溃
- 统一各版本制谱器在移动端的 `touchPad` / `touchPadCam` 初始化逻辑

## 技术栈

- Haxe + OpenFL + Flixel
- 项目基于 FNF Psych Engine 1.0 改版（KathyEngine）

## 实现方案

### 崩溃根因

1. **按钮按下崩溃（OldChartingState063/073）**

- 堆栈：`TouchButton.updateButton -> checkTouchOverlap -> checkInput -> FlxPointer.getWorldPosition(camera, _point)`
- 原因：`cameras` 列表中存在 `null` 或已销毁的摄像头，`getWorldPosition` 空引用。
- 修复：在 `checkTouchOverlap` 遍历 `cameras` 时跳过 `null` 摄像头。

2. **按钮渲染异常**

- 原因：`TouchButton` 实例从父级 `TouchPad`（FlxGroup）继承 `cameras`，会遍历全局摄像头列表，包含旧状态遗留或已销毁的摄像头。
- 修复：在 `MusicBeatState.addTouchPadCamera()` 与 `MusicBeatSubstate.addTouchPadCamera()` 中为每个 `TouchButton` 成员显式设置 `cameras = [touchPadCam]`。

3. **1.0.4-Kathy 制谱器启动崩溃**

- 堆栈：`ChartingState.create -> addChartingTab -> FlxSpriteGroup.preAdd`
- 原因：`addChartingTab()` 在 `controls.mobileC` 为 true 时跳过创建 `rightClickDeleteCheckBox` 和 `dragHoldCheckBox`，但后续仍无条件执行 `tab_group.add(rightClickDeleteCheckBox)` 和 `tab_group.add(dragHoldCheckBox)`，传入 `null` 导致 `preAdd` 空引用。
- 修复：用 `if (!controls.mobileC)` 包裹这两个 `tab_group.add` 调用。

4. **1.0.4-Kathy 触控板未指定摄像头**

- 原因：`ChartingState.create()` 直接调用 `addTouchPad(...)` 但未调用 `addTouchPadCamera()`，而 0.6.3/0.7.3 旧编辑器都有该调用。
- 修复：在 `ChartingState.create()` 创建 `touchPad` 后，按条件调用 `addTouchPadCamera()`。

### 性能与可靠性

- 改动集中在移动端输入层与制谱器状态初始化，计算开销可忽略。
- `camera == null` 检查为防御性代码，不影响桌面端性能。

## 目录结构

```
source/
├── mobile/objects/TouchButton.hx          # [MODIFY] checkTouchOverlap 增加 null 摄像头跳过
├── backend/MusicBeatState.hx              # [MODIFY] addTouchPadCamera 为每个按钮设置 cameras
├── backend/MusicBeatSubstate.hx           # [MODIFY] addTouchPadCamera 为每个按钮设置 cameras
└── states/editors/ChartingState.hx        # [MODIFY] addChartingTab 避免添加 null 控件；create 补充 addTouchPadCamera
```

## Agent Extensions

### SubAgent

- **code-explorer**
- Purpose: 在修改后快速扫描所有 charting 状态（0.6.3、0.7.3、1.0.4-Kathy、1.0.4-Official）的 touchPad 初始化与 add 调用，确认没有遗漏的 null 引用或不一致的摄像头设置。
- Expected outcome: 输出各编辑器中 `addTouchPad` / `addTouchPadCamera` / `tab_group.add(...)` 的使用清单，供最终验证。