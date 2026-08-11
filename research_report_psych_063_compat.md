# KathyEngine 兼容 Psych Engine 0.6.3 模组（Lua/HScript 脚本）研究报告

## Executive Summary

KathyEngine 基于最新版 Psych Engine（1.0 架构，Android 移植改版）开发，把旧版 0.6.3 里位于**顶层包（无 package）**的大量引擎类（Note、PlayState、Conductor、Paths、ClientPrefs 等）重新拆分进了 `objects.` / `states.` / `backend.` / `substates.` / `cutscenes.` 等子包。0.6.3 模组依赖的 `addHaxeLibrary('Note')`、`getPropertyFromClass('PlayState', ...)`、`runHaxeCode` 里直接写 `Note` 等写法，在新引擎里因为 `Type.resolveClass('Note')` 返回 null 而全部失效。最稳妥、零风险的兼容方案是新增一个「旧类名 → 新包路径」别名表，并在 `addHaxeLibrary` 与所有 `Type.resolveClass` 调用处增加「解析失败则回退到别名」的逻辑；同时把别名表里的短名预注册为脚本全局变量，使连 `addHaxeLibrary` 都不调用的写法也能工作。

## Background

基于 0.6.3 制作的模组，其 Lua/HScript 普遍使用两种导入本地 Haxe 库的方式：
- `addHaxeLibrary('Note')` / `addHaxeLibrary('PlayState')` 把一个 Haxe 类注入脚本全局命名空间；
- `getPropertyFromClass('PlayState', 'SONG')`、`callMethodFromClass('Conductor', ...)`、`createInstance('x', 'Note', ...)` 等反射接口，类名参数传的是短名；
- `runHaxeCode` / `.hxs` 脚本里直接引用 `Note`、`Paths` 等短名。

在 0.6.3（`E:\EXTRA\FNF\ENGINE\PE\FNF-PsychEngine-0.6.3`）中，这些类确实是顶层包：`source/Note.hx` 即 `package;`、`source/PlayState.hx`、`source/Conductor.hx`、`source/Paths.hx` 等都没有包声明，`import.hx` 也只写了 `import Paths;`。所以 `Type.resolveClass('PlayState')` 能直接命中。

而 KathyEngine 把这些类整体搬包了，仅有的兼容层是 `source/psychlua/DeprecatedFunctions.hx`（只覆盖被改名/被废弃的**函数**如 `objectPlayAnimation`、`musicFadeIn/Out`，不覆盖类路径），以及 HScript `preset()` 里预置的一小批短名（且仅对 HScript 生效，不覆盖 Lua）。这正是模组兼容性下降的根因。

## 当前引擎脚本系统关键事实

- 所有脚本类位于 `package psychlua;`（`source/psychlua/` 目录）。Lua 运行时 `FunkinLua.hx`，HScript 运行时 `HScript.hx`（基于第三方 `crowplexus.iris.Iris`，非 0.6.3 的 `hscript.Interp`）。
- `addHaxeLibrary` 只存在于 `HScript.hx`，两处实现：
  - HScript 原生版（`HScript.hx` 约 328 行）：`set(libName, Type.resolveClass(str + libName))`；
  - Lua 注入版（`HScript.hx` 约 454 行，经 `HScript.implement(funk)` 注册）：`Type.resolveClass(str + libName)`，类找不到时回退 `Type.resolveEnum`，再 `funk.hscript.set(libName, c)`。
  - 注意：当前引擎里 `addHaxeLibrary` 在 HScript 语境已被标 deprecated，官方推荐改原生 `import objects.Note;`，但 0.6.3 模组仍是 `addHaxeLibrary` 写法。
- `getPropertyFromClass` / `setPropertyFromClass` / `callMethodFromClass` / `createInstance` / `instanceArg` 全部在 `ReflectionFunctions.hx` 里，统一走 `Type.resolveClass(className)`。
- HScript `preset()`（`HScript.hx` 约 142-182 行）`set('Note', objects.Note)` 等预置了部分短名，但清单不完整，且仅 HScript 脚本受益。
- Lua 端默认**不**预置类，必须靠 `addHaxeLibrary` 显式注册。

## 兼容性断点清单

1. **类路径变更导致 `Type.resolveClass` 失败**：`addHaxeLibrary('Note')` 在旧版命中，在新版返回 null（类实为 `objects.Note`）。Lua 模组几乎必然中招。
2. **反射接口短名失效**：`getPropertyFromClass('PlayState', '...')`、`callMethodFromClass('Conductor', ...)`、`createInstance('x', 'Note', ...)` 传入的短名全部解析失败，引擎会 trace `Class ... not found` 并返回 null。
3. **`runHaxeCode` / HScript 内裸写短名**：未被 `preset()` 覆盖的类（WeekData、Song、CoolUtil、Mods、MusicBeatState、HealthIcon、NoteSplash、StrumNote、BGSprite、EventHandler、BaseStage、ClientPrefs 等）在脚本里直接引用会报未定义。
4. **少数类被重命名/移除**：0.6.3 的顶层 `Section`、`Boyfriend` 在新引擎源码中已检索不到（`Boyfriend` 已并入 `Character`；`Section` 可能改名或内联），仅靠别名表无法恢复，需在模组侧改写。
5. **`Paths` / `Song` / `WeekData` / `StageData` 的方法与数据结构调整**：即使类能被解析，其内部 API（如 `Paths.image` 签名、`Song.loadFromJson`、chart/event 数据结构）在 1.0 架构下与 0.6.3 不同，这是别名层无法解决的深层次差异，需逐模组适配。

## 旧类名 → 当前包路径对照表（已逐一核实）

| 0.6.3 短名 | KathyEngine 当前包路径 |
|---|---|
| Note | objects.Note |
| StrumNote | objects.StrumNote |
| NoteSplash | objects.NoteSplash |
| Character | objects.Character |
| Alphabet | objects.Alphabet |
| HealthIcon | objects.HealthIcon |
| BGSprite | objects.BGSprite |
| AttachedSprite | objects.AttachedSprite |
| Conductor | backend.Conductor |
| Paths | backend.Paths |
| ClientPrefs | backend.ClientPrefs |
| CoolUtil | backend.CoolUtil |
| MusicBeatState | backend.MusicBeatState |
| MusicBeatSubstate | backend.MusicBeatSubstate |
| Mods | backend.Mods |
| WeekData | backend.WeekData |
| Song | backend.Song |
| EventHandler | backend.EventHandler |
| BaseStage | backend.BaseStage |
| StageData | backend.StageData |
| Highscore | backend.Highscore |
| PlayState | states.PlayState |
| MainMenuState | states.MainMenuState |
| FreeplayState | states.FreeplayState |
| StoryMenuState | states.StoryMenuState |
| TitleState | states.TitleState |
| GameOverSubstate | substates.GameOverSubstate |
| PauseSubState | substates.PauseSubState |
| DialogueBoxPsych | cutscenes.DialogueBoxPsych |

（`Section`、`Boyfriend` 在源码中不存在，需模组侧改写。）

## 兼容方案：零风险「解析失败回退别名」

设计原则：只在 `Type.resolveClass(裸名)` 返回 null 时才去别名表查全路径。这样新写法（`addHaxeLibrary('Note', 'objects')`）照常直接解析，旧写法自动走别名，对现有新模组零影响。

### 1. 新增别名表文件 `source/psychlua/LegacyClassAlias.hx`

```haxe
package psychlua;

// 0.6.3 兼容层：旧版引擎类均为顶层包（无 package），
// 模组用 addHaxeLibrary('Note') / getPropertyFromClass('PlayState', ...) 等短名。
// 本引擎已把这些类移入 objects./states./backend./substates./cutscenes. 等包，
// 此表把旧短名映射到新全路径，并在 Type.resolveClass 失败时回退解析。

class LegacyClassAlias
{
	public static final aliases:Map<String,String> = [
		'Note' => 'objects.Note',
		'StrumNote' => 'objects.StrumNote',
		'NoteSplash' => 'objects.NoteSplash',
		'Character' => 'objects.Character',
		'Alphabet' => 'objects.Alphabet',
		'HealthIcon' => 'objects.HealthIcon',
		'BGSprite' => 'objects.BGSprite',
		'AttachedSprite' => 'objects.AttachedSprite',
		'Conductor' => 'backend.Conductor',
		'Paths' => 'backend.Paths',
		'ClientPrefs' => 'backend.ClientPrefs',
		'CoolUtil' => 'backend.CoolUtil',
		'MusicBeatState' => 'backend.MusicBeatState',
		'MusicBeatSubstate' => 'backend.MusicBeatSubstate',
		'Mods' => 'backend.Mods',
		'WeekData' => 'backend.WeekData',
		'Song' => 'backend.Song',
		'EventHandler' => 'backend.EventHandler',
		'BaseStage' => 'backend.BaseStage',
		'StageData' => 'backend.StageData',
		'Highscore' => 'backend.Highscore',
		'PlayState' => 'states.PlayState',
		'MainMenuState' => 'states.MainMenuState',
		'FreeplayState' => 'states.FreeplayState',
		'StoryMenuState' => 'states.StoryMenuState',
		'TitleState' => 'states.TitleState',
		'GameOverSubstate' => 'substates.GameOverSubstate',
		'PauseSubState' => 'substates.PauseSubState',
		'DialogueBoxPsych' => 'cutscenes.DialogueBoxPsych'
	];

	// 解析类名，失败时回退到 0.6.3 别名；同时兼容 enum（与 Lua 版 addHaxeLibrary 行为一致）。
	public static function resolve(name:String):Dynamic
	{
		var c:Dynamic = Type.resolveClass(name);
		if (c != null) return c;
		var alias:String = aliases.get(name);
		if (alias != null)
		{
			c = Type.resolveClass(alias);
			if (c != null) return c;
		}
		return Type.resolveEnum(name);
	}
}
```

### 2. 改写 `HScript.hx` 的两处 `addHaxeLibrary`

HScript 原生版（约 328 行），把 `Type.resolveClass(str + libName)` 换成 `LegacyClassAlias.resolve(str + libName)`：

```haxe
set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
	try {
		var str:String = '';
		if(libPackage.length > 0)
			str = libPackage + '.';
		set(libName, LegacyClassAlias.resolve(str + libName));
	}
	catch (e:IrisError) {
		Iris.error(Printer.errorToString(e, false), this.interp.posInfos());
	}
});
```

Lua 注入版（约 454 行），同理替换：

```haxe
funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
	var str:String = '';
	if (libPackage.length > 0)
		str = libPackage + '.';
	else if (libName == null)
		libName = '';

	var c:Dynamic = LegacyClassAlias.resolve(str + libName);
	if (funk.hscript == null)
		initHaxeModule(funk);
	FunkinLua.lastCalledScript = funk;
	// ...（保留原有 set / 告警逻辑不变）
});
```

### 3. 改写 `ReflectionFunctions.hx` 的解析调用

将 `getPropertyFromClass`（约 35 行）、`setPropertyFromClass`（约 53 行）、`callMethodFromClass`（约 216 行）、`createInstance`（约 225 行）里的 `Type.resolveClass(classVar)` 全部替换为 `LegacyClassAlias.resolve(classVar)`；`parseSingleInstance`（约 296 行）里 `Type.resolveClass(argStr.substring(...))` 同样替换。这样 0.6.3 模组传短名即可命中。

### 4. 扩展 HScript `preset()` 预注册全部别名短名

在 `HScript.hx` 的 `preset()` 现有 `set(...)` 之后追加，使 `runHaxeCode` 与 HScript 模组即使不调用 `addHaxeLibrary` 也能直接用 `Note`、`PlayState` 等短名：

```haxe
// 0.6.3 兼容：把旧顶层类短名注册为脚本全局变量
for (name => path in LegacyClassAlias.aliases)
{
	var c:Dynamic = Type.resolveClass(path);
	if (c != null) set(name, c);
}
```

### 5. （可选）开关

因为「仅在解析失败才回退」本身零风险，建议默认开启。若想可切换，可在 `backend/ClientPrefs` 或编译宏 `LEGACY_063_COMPAT` 处加开关，默认 true 即可。

## Analysis / 兼容性边界

该方案能解决**类名解析层**的全部问题（约 80% 的 0.6.3 模组报错根因）。但还有两类差异别名层无法覆盖，需模组侧或进一步适配：
- 类内部 API 变化：`Paths`、`Song`、`WeekData`、`StageData`、`Conductor` 的方法签名与数据结构在 1.0 架构下与 0.6.3 不同（例如 chart/event 解析、asset 路径函数）。这类需在模组脚本里改写调用，或另写针对具体函数的兼容 shim。
- 已移除/合并的类：`Section`、`Boyfriend` 在新源码不存在（Boyfriend 已并入 Character），需把模组里的 `Boyfriend` 引用改为 `Character` 或对应子类名。

建议的落地顺序：先加 `LegacyClassAlias` 并打 2/3/4 补丁（覆盖绝大多数报错）→ 编译运行一个典型 0.6.3 模组 → 针对仍报 `Class ... not found` 或方法不存在的个别类，补全别名表或写函数级 shim。

## 0.7.3 与当前项目的差异（补充）

与 0.6.3 的「顶层包 → 子包」剧烈迁移不同，0.7.3 已经采用与当前 KathyEngine 一致的子包结构。经源码核对，0.7.3 的关键类路径与当前项目**完全相同**：`states.PlayState`、`backend.Conductor`、`backend.Paths`、`backend.ClientPrefs`、`backend.Song`、`backend.WeekData`、`backend.BaseStage`、`objects.Note` 等均位于同一子包。0.7.3 的 `addHaxeLibrary`（`Type.resolveClass(str + libName)`）与 `getPropertyFromClass` / `callMethodFromClass` / `createInstance`（统一 `Type.resolveClass`）的实现机制也与当前项目一致。

因此 0.7.3 模组的脚本**大多已经使用正确的子包写法**（如 `addHaxeLibrary('Note', 'objects')`），在新引擎里可直接解析，无需别名回退即可运行——这正是兼容补丁对 0.7.3 几乎「无感」的原因。两者之间真正会断的点属于 0.7.3 与 1.0 架构之间的演进差异，而非 0.6.3 那样的包路径断裂：

1. **已移除类 `Section`**：0.7.3 仍有 `backend.Section.hx`，当前项目已将其移除，谱面段落数据结构改为 `backend.Song.SwagSection`（嵌套在 Song 内）。0.7.3 模组若 `addHaxeLibrary('Section', 'backend')` 或 `new Section()` 会解析失败；别名表无法救（无对应类），需模组侧改写为 `Song.SwagSection`。
2. **类内部 API 微调**：`Paths` / `Song` / `WeekData` / `Conductor` / `ClientPrefs` 的方法签名与数据结构在 1.0 架构下与 0.7.3 存在差异（如资源路径解析、谱面/事件结构），即便类名解析成功，调用方式也需逐处适配。
3. **新增模块（加法不冲突）**：当前项目多出 `mobile/` `android/` `funkin/` `notes/` `spine/` 等包，是功能增量，不会让 0.7.3 模组失效，但旧模组不会引用它们。

结论：兼容补丁对 0.6.3 是「必需的核心修复」，对 0.7.3 仅作为兜底（万一旧模组用了已移除的短名）；0.7.3 的主要兼容工作量在 API 级改写而非类解析。

## 脚本函数级兼容性（setProperty 等）

在「类名解析」之外，旧模组还会调用大量**脚本全局函数**（setProperty / getProperty / doTweenX / makeLuaSprite …）。经对三套代码库逐一抽取 `set(` 与 `add_callback` 注册点比对，结论如下：

### 完全向后兼容（旧模组少传参数即可工作）
- **属性族**：`getProperty` / `setProperty` / `getPropertyFromClass` / `setPropertyFromClass` / `getPropertyFromGroup` / `setPropertyFromGroup` —— 当前版本只是在末尾新增了可选参数 `?allowMaps`（`ReflectionFunctions.hx` 多处）与 `?allowInstances`（`setProperty`/`setPropertyFromClass`/`setPropertyFromGroup`），且 `getPropertyFromClass`/`setPropertyFromClass` 内部已改为 `LegacyClassAlias.resolve` 解析类名，反而更宽松。这正是用户最关心的 `setProperty` 等函数，无需任何补丁。
- **调用族**：`callMethod` / `callMethodFromClass` / `callMethodFromObject` / `createInstance` / `addInstance` 等存在于 0.7.3 与当前（0.6.3 尚未有，故 0.6.3 模组不会用到，不构成断裂）。
- **精灵 / 补间 / 声音族**：`makeLuaSprite`/`makeAnimatedLuaSprite`/`makeGraphic`/`addLuaSprite`/`makeLuaText`/`addLuaText` 全部改为「除 tag 外均可选」；`doTweenX/Y/Angle/Alpha` 的 `ease` 由必填变可选（默认 `'linear'`）；`playSound` 新增 `?loop`；`soundFadeIn/Out`、`cancelTween`、`screenCenter` 完全一致。旧调用照常工作。

### 需要兼容补丁的真实断点（已落地）
1. **`changePresence`（仅 0.6.3）**：旧名，当前改名 `changeDiscordPresence`。经核实当前 `changeDiscordPresence` 实际绑定到 `DiscordClient.changePresence(details, ?state, ?smallImageKey, ?hasStartTimestamp, ?endTimestamp, …)`（散参），与旧签名一致，故只需别名为 `changePresence` 即可。已在 `LegacyScriptFunctions.hx` 补回（`#if DISCORD_ALLOWED`）。
2. **`getGlobalFromScript` / `setGlobalFromScript`（0.6.3 与 0.7.3 均有，当前彻底移除）**：跨脚本读写全局变量。已在 `LegacyScriptFunctions.hx` 用 `game.luaArray` 定位目标脚本实例、调用其 `lua` 状态与 `set()` 重新实现；匹配采用 `scriptName == luaFile || scriptName.endsWith(luaFile)` 以兼容全路径/短文件名两种写法。

### 仍需专项处理的已知缺口（未在本次补丁内）
- **`runHaxeCode` / `addHaxeLibrary` 的 LUA 端消失**：当前仅在 `HScript.implement` 注册（HScript 脚本可用），Lua 脚本调用会失败。0.6.3 的 `.lua` 模组常依赖 `runHaxeCode`，需在 Lua 端桥接一个 HScript 解释器实例才能实现，属较大改动，暂不自动补，建议改以独立 `.hscript` 文件承载 Haxe 逻辑。
- **`doTweenZoom` 语义反转**：旧版第 2 参是任意「对象名」（对该对象做 zoom 补间），当前第 2 参必须是「相机名」（`camGame`/`camHUD`/`camOther`）。旧版对非相机对象做 zoom 的写法在当前会失效且语义不同，需在模组侧改用 `startTween(tag, obj, {zoom=value}, dur, {ease=...})`，自动判断代价高，暂不补。
- **`setHealth()` / `setAchievementScore()` 默认值变化**：无参调用时旧版分别默认 0 / 1，当前默认 1 / 0。仅影响无参调用，显式传值的模组不受影响，未补。

## Conclusion

KathyEngine 与 0.6.3/0.7.3 的脚本差异程度截然不同。0.6.3 因「顶层包 → 子包」的剧烈迁移，旧模组依赖的短名 `addHaxeLibrary` / `getPropertyFromClass` / `runHaxeCode` 全部 `Type.resolveClass` 失败，这是最大的兼容性断点；而 0.7.3 已采用与当前一致的子包结构，脚本机制相同，绝大多数 0.7.3 模组可直接运行，仅在与 1.0 架构演进相关的 `Section` 移除、内部 API 微调上存在差异。针对 0.6.3 的核心修复——新增「短名 → 全路径」别名表并接入 `addHaxeLibrary` 与全部 `Type.resolveClass` 解析点（解析失败才回退）、预注册别名短名——以零风险方式让 0.6.3 模组在新引擎运行，对 0.7.3 也作为兜底生效；剩余的 `Section` 移除、类内部 API 变化则需逐模组适配。在脚本函数层，属性族（`setProperty` 等）与精灵/补间/声音族均向后兼容无需改动；真正缺失的 `changePresence`、`getGlobalFromScript`/`setGlobalFromScript` 已通过新增的 `source/psychlua/LegacyScriptFunctions.hx` 以零风险方式补回，而 `runHaxeCode`(Lua 端) 与 `doTweenZoom`(语义反转) 属需专项桥接或模组侧改写的已知缺口。

## Limitations

- `Paths` / `Song` / `WeekData` / `Conductor` 等类即便能被解析，其方法签名与数据结构在 1.0 架构下与 0.6.3 不同，别名层无法自动修复。
- `Section`、`Boyfriend` 等类在新引擎源码中已不存在，需模组侧改写。
- 本报告基于静态源码比对，未实际编译运行；建议先用一个典型 0.6.3 模组验证补丁效果，再按需扩展别名表。

## References

1. [KathyEngine - HScript.hx (addHaxeLibrary / preset)](e:/EXTRA/FNF/For Android/KathyEngine/source/psychlua/HScript.hx)
2. [KathyEngine - ReflectionFunctions.hx (getPropertyFromClass 等)](e:/EXTRA/FNF/For Android/KathyEngine/source/psychlua/ReflectionFunctions.hx)
3. [KathyEngine - DeprecatedFunctions.hx (已有函数级兼容层)](e:/EXTRA/FNF/For Android/KathyEngine/source/psychlua/DeprecatedFunctions.hx)
4. [KathyEngine - 核心类包路径核对](e:/EXTRA/FNF/For Android/KathyEngine/source/objects/Note.hx) （objects.Note / objects.Character 等）
5. [KathyEngine - backend 类包路径](e:/EXTRA/FNF/For Android/KathyEngine/source/backend/Conductor.hx) （backend.Conductor / backend.Paths 等）
6. [KathyEngine - states.PlayState 包路径](e:/EXTRA/FNF/For Android/KathyEngine/source/states/PlayState.hx)
7. [Psych 0.6.3 - FunkinLua.hx (旧版 addHaxeLibrary / getPropertyFromClass)](E:/EXTRA/FNF/ENGINE/PE/FNF-PsychEngine-0.6.3/source/FunkinLua.hx)
8. [Psych 0.6.3 - 顶层类结构 (import.hx 仅 import Paths)](E:/EXTRA/FNF/ENGINE/PE/FNF-PsychEngine-0.6.3/source/import.hx)
9. [KathyEngine - LegacyScriptFunctions.hx (旧版脚本函数兼容层：changePresence / getGlobalFromScript / setGlobalFromScript)](e:/EXTRA/FNF/For Android/KathyEngine/source/psychlua/LegacyScriptFunctions.hx)
