---
name: fix-specialvocal-loading
overview: 修复 SpecialVocal 在统一音频目录（loadSongAudio）改造后失效的问题：在 tryVoices 拼 fileBase 时补上 specialVocal 后缀，保留原有 postfix 回退链与"任一匹配即可"语义，覆盖 PlayState / ChartingState / FreeplayState 三处。
todos:
  - id: fix-playstate-vocal
    content: 修改 PlayState.hx 的 tryVoices 拼接 specialVocal 到 Voices fileBase
    status: completed
  - id: fix-charting-vocal
    content: 修改 ChartingState.hx 的 tryVoices 拼接 specialVocal 到 Voices fileBase
    status: completed
  - id: verify-freeplay
    content: 核查 FreeplayState.hx 确认无人声加载，无需改动
    status: completed
  - id: lint-verify
    content: 运行 lint 确认两文件无错误并自检回退逻辑
    status: completed
    dependencies:
      - fix-playstate-vocal
      - fix-charting-vocal
---

## 用户需求

统一音频目录改造后，SpecialVocal 无法生效，但 SpecialInst 正常。需要修复 vocal 文件加载逻辑，让 specialVocal 正确参与路径拼接。

## 产品概述

修复游戏内歌曲人声（Voices）加载逻辑，使歌曲配置了 specialVocal 时，能按约定规则加载对应后缀的人声文件，与 SpecialInst 行为对称。

## 核心功能

- 在加载人声时，将 specialVocal 拼接到文件名后缀之后，支持三种匹配规则（任一匹配即可，不必成对存在）：

1. Voices-{角色名}-SpecialVocal（如 Voices-bf-erect）
2. Voices-Player-SpecialVocal / Voices-Opponent-SpecialVocal
3. Voices-SpecialVocal

- 回退顺序：角色指定后缀（含 specialVocal） > Player/Opponent 别名（含 specialVocal） > 无后缀合并 Voices（含 specialVocal） > 普通规则回退。
- 仅一方（玩家/对手）存在 SpecialVocal 文件时，另一方回退普通 Voices，不报错。
- 无 specialVocal 时行为完全不变（fileBase 退化为 Voices / Voices-bf 等）。

## 技术栈

- 语言：Haxe（HaxeFlixel 游戏框架）
- 项目：KathyEngine（Friday Night Funkin 衍生引擎）
- 音频加载：Paths.loadSongAudio(song, fileBase, modDir)（不回退 funkin 原生，缺失即 null）

## 实现方案

### 策略

在所有调用 `Paths.loadSongAudio(..., 'Voices'..., ...)` 的 `tryVoices` 辅助函数（及等价逻辑）中，将 `specialVocal` 追加到 `fileBase` 末尾（postfix 之后）。保持与 `specialInst` 完全对称的拼接方式：`Inst-${specialInst}` 对应 `Voices-${postfix}-${specialVocal}`。

### 关键决策

1. **统一拼接逻辑**：新增辅助函数 `buildVocalBase(postfix, specialVocal)` 或在 `tryVoices` 内联拼接，避免三处代码重复。优先复用现有 `tryVoices` 结构（PlayState、ChartingState 已有，FreeplayState 仅播 Inst 无需改）。
2. **回退顺序**：保持现有 `角色 postfix → Player/Opponent → null` 三档回退，每档内部再带 specialVocal；这样天然满足"任一匹配即可"且"无 specialVocal 时退化"。
3. **数据源**：PlayState 使用 `songData.specialVocal`（songData 即 PlayState.SONG）；ChartingState 使用 `PlayState.SONG.specialVocal`。
4. **不引入新架构**：仅在现有 `tryVoices` 函数体内修改，不新增文件、不改变调用链与缓存机制（loadSongAudio 的缓存 key 与原来一致）。

### 性能与可靠性

- `loadSongAudio` 已有 `currentTrackedSounds` 缓存，重复调用无文件系统开销。
- 回退链最多 3 次 `loadSongAudio` 调用（均为缓存命中/快速 null），无性能瓶颈。
- 空字符串与 null 均做防御判断，与 `specialInst` 现有写法一致。

## 实现说明

- **PlayState.hx**（约 2245-2250）：`tryVoices` 内 `base` 改为
`var base = 'Voices' + (postfix != null ? '-$postfix' : '') + (songData.specialVocal != null && songData.specialVocal.length > 0 ? '-${songData.specialVocal}' : '');`
返回 `Paths.loadSongAudio(songData.song, base, audioModDir)`。
- **ChartingState.hx**（约 3255-3260）：同样改 `tryVoices`，用 `PlayState.SONG.specialVocal`。
- **FreeplayState.hx**：经排查仅有 `playMusic` 播 Inst，无人声 preview 加载逻辑，无需修改（计划中标注排查结论，避免误改）。
- **CommandLineLaunchState.hx**：命令行启动无 vocal，暂不改（参考项）。
- **Paths.hx**：旧 `voices()` 函数已带 specialVocal 但当前流程未使用，忽略。

## 架构设计

现有音频加载为"调用点 → tryVoices 辅助函数 → Paths.loadSongAudio → 缓存"的线性结构。本次仅修改辅助函数的 fileBase 拼接，不改变组件关系与数据流，符合最小改动原则。

## 目录结构

```
source/states/
├── PlayState.hx          # [MODIFY] 修改 tryVoices，拼接 specialVocal 到 Voices fileBase
└── editors/
    └── ChartingState.hx  # [MODIFY] 修改 tryVoices，拼接 specialVocal 到 Voices fileBase
source/states/
└── FreeplayState.hx      # [核查] 确认无人声加载逻辑，无需修改（仅记录结论）
```