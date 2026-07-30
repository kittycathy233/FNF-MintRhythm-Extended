---
name: settings-descriptions-localization
overview: 补全并本地化 Kathy Engine 所有设置选项（Settings）的介绍/描述文本到 en_us、zh_cn、zh_tw 三种语言，使其与游戏内（PlayState）相关特性一致。修复缺失键、抽取硬编码描述到语言文件并翻译。
todos:
  - id: audit-options
    content: 审计所有 Option 式设置子状态的描述来源，产出键名/硬编码/三语存在情况清单
    status: completed
  - id: write-en-us
    content: 使用 [subagent:code-explorer] 核对 PlayState 行为，编写准确的英文描述并补全到 en_us.json（复用 zh_tw 已有键）
    status: completed
    dependencies:
      - audit-options
  - id: translate-zh
    content: 补全 zh_cn.json 简体翻译与 zh_tw.json 繁体翻译，覆盖所有新键及现有缺失键
    status: completed
    dependencies:
      - write-en-us
  - id: refactor-source
    content: 将各 .hx 中硬编码描述改为 Language.get 引用规范化键名，并复用 zh_tw 已有键
    status: completed
    dependencies:
      - write-en-us
  - id: verify-no-missing
    content: 静态校验所有 Language.get 引用键在三语文件均存在，确认无原始键名回退
    status: completed
    dependencies:
      - translate-zh
      - refactor-source
---

## 用户需求

Kathy Engine（FNF 系引擎）已有多语言支持（en_us / zh_cn / zh_tw，位于 `assets/languages/*.json`，由 `Language.get(key)` 读取；键不存在时返回原始键名本身）。用户发现设置中的「选项介绍文本（每个选项的 desc）」不完整，要求全面补全，并尽可能与游戏内 PlayState 相关特性保持一致。

## 核心范围（已与用户确认）

- **全部设置选项本地化**：覆盖所有「Option 列表式」设置子状态。
- **补全到全部三种语言**：en_us（权威源）、zh_cn（简体）、zh_tw（繁体）。
- **允许修改 .hx 源码**：将硬编码的描述字符串改为 `Language.get("键名")` 引用语言文件。

## 需处理的问题类型

1. **缺失键**：`Language.get` 已引用但在三语文件中均不存在的键（运行时原样显示原始键名，如 `hitsound_desc`、`ratcounter_anim_desc`）。
2. **硬编码描述**：源码中直接写死的中/英文字符串（如 ExtraGameplay 中的 `Health Overflow Icons`、`Low-Latency Mode`，Graphics 中的 `PlayState Adaptive Width` 等），未走本地化。
3. **已定义未使用**：zh_tw.json 已存在部分键（如 `single_hold_note_animation_desc`、`sound_tray_style_desc`），但 .hx 仍用硬编码英文 —— 应改回 `Language.get` 复用，并补齐 en_us / zh_cn。

## 涉及的目标设置子状态

Gameplay、ExtraGameplay、Graphics、Visuals、FPSCounter、SimpleInfo、Mobile、OptionsState（主菜单各子项描述）。

## 技术栈与实现机制

- **语言**：Haxe + OpenFL（`Language.get(key, ?params)` 读取 `assets/languages/<lang>.json`；键缺失时返回 key 字符串本身 —— 这是「介绍文本残缺」的根因）。
- **数据载体**：三个 JSON 文件，键命名沿用现有 `snake_case` + `_desc` 约定。

## 实现策略

1. **全量审计**：逐文件枚举各 `Option(name, desc, ...)` 的 desc 来源（Language.get 键 / 硬编码串），记录键名与在三语中的存在情况，产出统一清单。
2. **键规范化**：

- 缺失键与硬编码描述统一分配规范化键名（如 `lane_cover_p1_desc`、`precise_hit_desc`、`health_overflow_desc`、`low_latency_desc`、`hold_note_tail_fix_desc`、`stage_quality_desc` 等）。
- 优先复用 zh_tw 已存在的键（如 `single_hold_note_animation_desc`、`auto_reset_strum_anim_desc`、`fallback_perfect_to_sick_desc`、`sound_tray_style_desc`、`hold_note_behind_desc`），避免重复定义。

3. **描述准确性（匹配 PlayState）**：每键的英文描述需对照 `source/states/PlayState.hx`、`source/backend/ClientPrefs.hx`、`objects/Note.hx` 等确认真实行为，例如 `preciseHit`（毫秒级音频时钟判定）、`inputSystem`（default/rhythm）、`healthOverflow`/`smoothHP`、`lowLatency`、`holdTailFix`、`holdScoreBonus`、`laneCover`、`singleHoldNoteAnimation` 等，确保文字与游戏内表现一致。
4. **源码改造**：将硬编码描述串替换为 `Language.get("键名")`，保留/补全 zh_tw 已用键；不改动选项逻辑、变量名与顺序（最小爆炸半径）。
5. **三语补全**：en_us 写权威英文，zh_cn 写简体，zh_tw 写繁体（已有键直接复用）。保持 JSON 结构、逗号、缩进一致。
6. **静态校验**：扫描所有 `Language.get("..._desc")` 引用键，确认在 en_us/zh_cn/zh_tw 三语中均存在（不再出现原始键名回退）。

## 性能与风险

- 纯数据 + 极小源码改动，无运行时额外开销（语言文件仅在加载时解析一次）。
- 严格保持向后兼容：仅替换文本来源，不改 `Option` 的 `variable`/`type`/回调，避免误伤逻辑或编译。
- 使用已有 `Language.get` 模式，不引入新国际化机制。

## 目录结构（将修改/新增的文件）

```
assets/languages/
├── en_us.json   # [MODIFY] 补全所有缺失/新键的英文 _desc
├── zh_cn.json   # [MODIFY] 补全简体翻译（含当前缺失的 fps_*/simpleinfo_*_desc）
└── zh_tw.json   # [MODIFY] 补全繁体翻译（复用已有键）

source/options/
├── GameplaySettingsSubState.hx        # [MODIFY] 缺失键 + 12 个硬编码中文描述 → Language.get
├── ExtraGameplaySettingSubState.hx    # [MODIFY] ratcounter_anim_desc/enable_console_log_desc + ~18 硬编码英文 → Language.get
├── GraphicsSettingsSubState.hx        # [MODIFY] 5 个硬编码英文 → Language.get
├── VisualsSettingsSubState.hx         # [MODIFY] ~18 硬编码英文 → Language.get（含复用 zh_tw 已有键）
├── MobileOptionsSubState.hx           # [MODIFY] 8 个硬编码英文 → Language.get
├── OptionsState.hx                    # [MODIFY 核对] 主菜单子项描述三语完整性
├── FPSCounterSettingsState.hx         # [核对] 已用 Language.get，补 zh_cn 缺失键
└── SimpleInfoDisplaySettingsState.hx  # [核对] 已用 Language.get，补 zh_cn 缺失键
```

## 不在本次范围

- `LanguageBasic.getPhrase` 体系（ControlsSubState / NotesColorSubState / NoteOffsetState / RatingOffsetState / LanguageSubState 等 .lang 机制文本）。
- `WindowManagerState` 等独立状态的本地化（可选后续）。

## Agent Extensions

### SubAgent

- **code-explorer**
- Purpose: 在「编写准确描述」阶段，跨文件检索 PlayState / ClientPrefs / Note 等实现，确认每个设置项的真实游戏内行为（如 preciseHit、inputSystem、healthOverflow、lowLatency、holdTailFix、laneCover 等），用于产出与 PlayState 特性匹配的英文描述。
- Expected outcome: 产出每个待补键对应的「源码行为依据」，保证描述准确、不误述功能。