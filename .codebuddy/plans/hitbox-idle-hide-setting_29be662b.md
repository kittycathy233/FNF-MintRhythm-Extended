---
name: hitbox-idle-hide-setting
overview: 为移动端 Hitbox 触屏控制新增一个自定义设置，允许在「未触摸判定时」隐藏/移除带颜色的实体方块显示，避免遮挡视野。仅在按下时才显示视觉反馈。
todos:
  - id: add-pref
    content: 在 ClientPrefs 的 SaveVariables 新增 hitboxHideIdle:Bool 默认 false
    status: completed
  - id: apply-hitbox
    content: 在 Hitbox.createHint 依据设置将未触摸方块与标签 alpha 设为 0
    status: completed
    dependencies:
      - add-pref
  - id: add-option
    content: 在 MobileOptionsSubState 的 HITBOX 区块新增对应 BOOL 开关选项
    status: completed
    dependencies:
      - add-pref
  - id: verify-rebuild
    content: 为选项补充 onChange 实时重建逻辑并验证作用域仅 HITBOX 模式
    status: completed
    dependencies:
      - apply-hitbox
      - add-option
---

## 用户需求

移动端 HITBOX 触屏控制模式（PlayState 游玩时）在未进行触摸判定时，屏幕上始终存在带颜色的实体方块（4 个彩色区域），部分情况下会遮挡视野。用户希望新增一个自定义设置（开关），用于移除「未触摸时的显示」，使未触摸时不再绘制/显示彩色方块，仅保留触摸按下时的视觉反馈。

## 产品概述

在移动端设置菜单的 HITBOX 选项区新增一个开关项「未触摸时隐藏 Hitbox」。开启后，游戏内未触摸状态下完全不显示彩色方块实体，避免遮挡视野；触摸按下时仍正常显示反馈，不影响任何触摸判定逻辑与功能。

## 核心功能

- 新增保存设置项 `hitboxHideIdle`（Bool，默认关闭），自动持久化
- HITBOX 构造时读取该设置：开启则不绘制/不显示未触摸状态的彩色方块（标签细条与实体方块 alpha 归零）
- 触摸按下时仍按原有动画/alpha 逻辑正常显示反馈
- 在移动端设置的 HITBOX 区块新增对应开关选项
- 仅影响 HITBOX 模式（MobileData.mode == 3），不影响 TouchPad 模式，不破坏命中判定区域

## 技术栈

- 语言：Haxe（OpenFL / Flixel 引擎）
- 现有模块：`source/backend/ClientPrefs.hx`（SaveVariables 自动保存）、`source/mobile/objects/Hitbox.hx`、`source/mobile/objects/MobileControls.hx`、`source/mobile/options/MobileOptionsSubState.hx`、`source/backend/MusicBeatState.hx` 与 `MusicBeatSubstate.hx` 的 `addMobileControls()`

## 实现方案

### 总体策略

沿用现有 HITBOX 设置模式（参考 `hitboxPos`/`hitboxType`/`hitboxAnimation`），在 `ClientPrefs` 新增一个 Bool 变量，在 `Hitbox.createHint()` 构造期读取它，控制未触摸时方块与标签的可见性；并在移动端设置 UI 的 HITBOX 区块追加一个 BOOL Option。

### 关键技术决策

1. **设置项位置**：在 `ClientPrefs.SaveVariables` 新增 `public var hitboxHideIdle:Bool = false;`。依据 `ClientPrefs.hx` line 10 注释「Add a variable here and it will get automatically saved」，新增变量即可自动持久化，零额外样板。
2. **隐藏逻辑（核心）**：在 `Hitbox.createHint()`（line 206-288）中：

- 当 `hitboxHideIdle == true` 且处于「未触摸」状态时，将 `hint.alpha` 设为 `0`（而非原来的 `0.00001`）并令 `hint.label.alpha = 0`，使方块与标签完全不可见、零遮挡。
- 触摸按下回调中仍按 `controlsAlpha` 恢复显示（复用现有 onDown 逻辑，无需改动判定区域）。
- 多键动态生成分支（line 116-141）使用同一 `createHint`，因此自然生效，无需重复修改。

3. **不改动命中判定**：仅调整视觉 alpha，不改动 `TouchButton` 的坐标/尺寸/点击区域，确保功能性不变。
4. **生效时机**：`Hitbox` 在 `addMobileControls()` 时 `new Hitbox()` 构造并读取设置，与 `hitboxPos`/`hitboxType` 一致——重新进入曲目即生效。为提升体验，可在新 Option 的 `onChange` 中调用 `removeMobileControls()` + `addMobileControls()` 实时重建（与现有 Option 的 `onChange` 用法一致），避免用户退出重进。

### 性能与可靠性

- 仅增加一次构造期 Bool 读取与 alpha 赋值，无额外运行时开销；动画循环（`update`）逻辑不受影响。
- 采用「默认关闭」保证向后兼容，老用户行为不变。
- 设置项仅在 `MobileData.mode == 3` 下展示，作用域清晰，blast radius 最小。

## 实现备注

- 复用 `MobileControls.alpha = ClientPrefs.data.controlsAlpha`（line 51）整体透明度机制，新设置只控制「未触摸的基准 alpha」为 0，已触摸时仍乘以 `controlsAlpha` 显示。
- 选项描述使用 `Language.get("hitbox_hide_idle_desc")` 时，若项目无对应翻译键，可直接使用中文描述字符串（与现有部分选项风格一致），避免引入缺失键导致空文本。
- 注意不要误改 `hitboxType == "Hidden"` 分支逻辑，新设置与其正交（Hidden 隐藏的是标签，新设置隐藏的是未触摸实体方块）。

## 架构设计

```
ClientPrefs.SaveVariables (hitboxHideIdle)
        │
        ▼ (构造期读取)
Hitbox.createHint()  →  未触摸 alpha=0 / 触摸恢复
        │
        ▼ (UI 配置入口)
MobileOptionsSubState (HITBOX 区块新增 Option)
        │
        ▼ (onChange 可选实时重建)
MusicBeatState.addMobileControls() / removeMobileControls()
```

## 目录结构与文件改动

```
source/backend/ClientPrefs.hx          # [MODIFY] 在 SaveVariables 中新增 hitboxHideIdle:Bool = false（约 line 20 后）
source/mobile/objects/Hitbox.hx        # [MODIFY] createHint() 中依据 hitboxHideIdle 将未触摸 alpha/label.alpha 设为 0
source/mobile/options/MobileOptionsSubState.hx  # [MODIFY] HITBOX 区块(line 72-84)新增 BOOL Option 'Hitbox Hide Idle'
```

## 关键代码结构

无需新增类型/接口；复用现有 `Option` 构造与 `TouchButton.alpha` 字段。