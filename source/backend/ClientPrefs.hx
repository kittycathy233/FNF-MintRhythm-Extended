package backend;

import flixel.util.FlxSave;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import states.TitleState;
import openfl.display.StageQuality;

// Add a variable here and it will get automatically saved
@:structInit class SaveVariables {
	// Mobile and Mobile Controls Releated
	public var extraButtons:String = "NONE"; // mobile extra button option
	public var hitboxPos:Bool = true; // hitbox extra button position option
	public var dynamicColors:Bool = true; // yes cause its cool -Karim
	public var controlsAlpha:Float = FlxG.onMobile ? 0.6 : 0;
	public var screensaver:Bool = false;
	public var wideScreen:Bool = false;
	public var hitboxType:String = "Gradient";
	public var hitboxAnimation:Bool = true; // whether hitbox button animations are enabled
	public var hitboxHideIdle:Bool = true; // hide the colored hitbox blocks while not being touched
	public var popUpRating:Bool = true;
	//public var vsync:Bool = false;
	public var gameOverVibration:Bool = false;
	public var mobileJudgmentCompensation:Bool = FlxG.onMobile; // 移动端判定补偿（触屏自动加偏移）
	public var mobileJudgmentOffset:Float = 10.0; // 移动端补偿量（ms）
	public var fpsRework:Bool = false;
	
	public var downScroll:Bool = false;
	public var middleScroll:Bool = false;
	public var opponentStrums:Bool = true;
	public var laneCoverAlphaP1:Float = 0.0; // 玩家轨道阴影覆盖层透明度（0=关闭，1=最暗）
	public var laneCoverAlphaP2:Float = 0.0; // 对手轨道阴影覆盖层透明度（0=关闭，1=最暗）
	public var laneCoverByStrumAlpha:Bool = false; // 覆盖层透明度是否基于箭头当前 alpha 叠加（乘算）
	public var showFPS:Bool = true;
	public var flashing:Bool = true;
	public var autoPause:Bool = false;
	public var gcOnResume:Bool = true;
	public var antialiasing:Bool = true;
	public var threeIcons:Bool = false; // 三态图标（正常 / 输 / 赢）：开启后图标图片按宽矩形横向均分为 3 个状态
	public var noteSkin:String = 'Default';
	public var splashSkin:String = 'Psych';
	public var holdCoverSkin:String = 'Default'; // Hold Cover 皮肤（后缀，如 -Psych），Default 表示使用默认 holdCover{Color} 素材
	public var splashAlpha:Float = 0.6;
	public var splashLimitEnabled:Bool = false; // 是否启用飞溅数量限制
	public var splashLimit:Int = 16; // 飞溅最大同时存在数量（默认16）
	public var lowQuality:Bool = false;
	public var shaders:Bool = true;
	public var cacheOnGPU:Bool = #if !switch false #else true #end; // GPU Caching made by Raltyro
	public var framerate:Int = 60;
	public var camZooms:Bool = true;
	public var stageQuality:String = 'MEDIUM'; // 矢量/文本渲染质量(StageQuality)：LOW/MEDIUM/HIGH/BEST，移动端建议 MEDIUM 及以下
	public var comboSpritePooling:Bool = true; // rating/combo/数字 精灵对象池：true=复用(省GC、减命中卡顿)，false=回退传统 new/destroy(最大兼容性)
	public var comboSpritePoolSize:Int = 32; // 对象池容量上限（0=无限增长模式，>0=循环复用模式），推荐值16-64
	public var loadingThreadCount:Int = 1; // 进入歌曲时资源加载的线程数（1=单线程，越大并行越高但更耗内存/可能触发OOM）
	public var hideHud:Bool = false;
	public var noteOffset:Int = 0;
	public var arrowRGB:Array<Array<FlxColor>> = [
		[0xFFC24B99, 0xFFFFFFFF, 0xFF3C1F56],
		[0xFF00FFFF, 0xFFFFFFFF, 0xFF1542B7],
		[0xFF12FA05, 0xFFFFFFFF, 0xFF0A4447],
		[0xFFF9393F, 0xFFFFFFFF, 0xFF651038]];
	public var arrowRGBPixel:Array<Array<FlxColor>> = [
		[0xFFE276FF, 0xFFFFF9FF, 0xFF60008D],
		[0xFF3DCAFF, 0xFFF4FFFF, 0xFF003060],
		[0xFF71E300, 0xFFF6FFE6, 0xFF003100],
		[0xFFFF884E, 0xFFFFFAF5, 0xFF6C0000]];

	// Arrow color rendering mode: 'RGB' (new palette) or 'HSV' (legacy Psych v0.6.3 hue/sat/brightness shift)
	public var arrowColorMode:String = 'RGB';
	// Legacy HSV arrow colors (one [hue, saturation, brightness] per direction, integers).
	// Range: hue -180..180, saturation/brightness -100..100. All 0 = no shift (texture renders as-is).
	public var arrowHSV:Array<Array<Int>> = [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]];

	public var ghostTapping:Bool = true;
	public var preciseHit:Bool = true; // 毫秒级精确判定：按键瞬间用音频时钟同步 songPosition，并实时计算判定窗口（替代上一帧缓存的 canBeHit）

	// ===== 低延迟 / 性能模式 =====
	// 自动重同步：弱机卡顿时，引擎会检测音频与逻辑不同步并跳回正确位置。关闭后不会“倒带”，改由玩家手动校准。
	public var autoResync:Bool = true;
	// 提前剔除已错过音符的渲染：已错过且离开屏幕（或到达极晚阈值）的音符不再参与绘制，降低 SPAM 谱渲染负担。
	public var hideMissedNotes:Bool = true;
	// 低延迟模式：关闭自动重同步 + 强制开启已错过音符剔除，追求最低输入延迟与最稳帧率。
	// 同时会强制开启「过期音符即时结算」与「关闭逐音符脚本」，构成一套完整的低负担组合。
	public var lowLatency:Bool = false;

	// ===== 高密度谱面（SPAM）性能优化 =====
	// 每帧生成预算：单帧内最多新建多少个音符精灵，0 = 不限制（保持原行为）。
	// 卡顿恢复后积压的大量音符不会在同一帧被一次性创建成几百个精灵（避免“死亡螺旋”），
	// 而是分摊到随后的若干帧生成；音符只是延后一两帧出现，绝不会丢失。
	public var maxNotesPerFrame:Int = 0;
	// 过期音符即时结算：生成时若某音符早已越过 noteKillOffset（正常也必定判 miss），
	// 直接结算而不加入渲染组、不参与逐帧绘制与物理。复用既有阈值，判定语义零偏差。
	public var instantResolveExpired:Bool = true;
	// 关闭逐音符脚本回调：跳过 onSpawnNote / goodNoteHit(Pre) / noteMiss / opponentNoteHit(Pre)
	// 的 Lua/HScript 调用。密集谱下这些逐音符调用开销巨大。⚠ 会使依赖这些回调的 modchart 失效，默认关闭。
	public var disableNoteLua:Bool = false;

	// ===== 综合音符性能优化总开关 =====
	// 控制不影响对象生命周期的优化（容器 push 替代 insert(0)、PreloadedChartNote 原生 class、
	// 皮肤缓存统一清理、cos/sin 缓存、notesHitArray 改用 Timer.stamp、Lua 热路径去 indexOf）。
	// 这些改动不改变 Note 实例生命周期，脚本安全。关闭则全量回退。默认开启。
	public var noteOptimization:Bool = true;

	// ===== 对象池开关 =====
	// 开启后按 (noteData) 分桶复用普通音符实例，消除每秒数十~数百次 new/destroy 的 GC 停顿。
	// ⚠ 风险：复用的 Note 实例对脚本而言不再是“每个都是全新对象”。若谱面/modchart 的
	// onSpawnNote / goodNoteHit / noteMiss 回调保存了 Note 对象引用并跨 spawn 访问其字段，
	// 可能读到被复用的脏数据。默认关闭；仅在你确认所用脚本不依赖音符对象持久引用时开启。
	public var notePooling:Bool = false;

	public var timeBarType:String = 'Time Left';
	public var scoreZoom:Bool = true;
	public var noReset:Bool = false;
	public var healthBarAlpha:Float = 1;
	public var hitsoundVolume:Float = 0;
	public var hitsound:String = 'none';
	public var pauseMusic:String = 'Tea Time';
	public var checkForUpdates:Bool = true;
	public var disableNetworking:Bool = false; // 全局联网开关：true 时拦截所有联网行为
	public var comboStacking:Bool = true;
	public var gameplaySettings:Map<String, Dynamic> = [
		'scrollspeed' => 1.0,
		'scrolltype' => 'multiplicative', 
		// anyone reading this, amod is multiplicative speed mod, cmod is constant speed mod, and xmod is bpm based speed mod.
		// an amod example would be chartSpeed * multiplier
		// cmod would just be constantSpeed = chartSpeed
		// and xmod basically works by basing the speed on the bpm.
		// iirc (beatsPerSecond * (conductorToNoteDifference / 1000)) * noteSize (110 or something like that depending on it, prolly just use note.height)
		// bps is calculated by bpm / 60
		// oh yeah and you'd have to actually convert the difference to seconds which I already do, because this is based on beats and stuff. but it should work
		// just fine. but I wont implement it because I don't know how you handle sustains and other stuff like that.
		// oh yeah when you calculate the bps divide it by the songSpeed or rate because it wont scroll correctly when speeds exist.
		// -kade
		'songspeed' => 1.0,
		'healthgain' => 1.0,
		'healthloss' => 1.0,
		'instakill' => false,
		'practice' => false,
		'botplay' => false,
		'playOpponent' => false
	];

	public var comboOffset:Array<Int> = [0, 0, 0, 0, 0, 0];
	public var ratingOffset:Int = 0;
	public var hitWindowPreset:String = 'Psych / Kade';
	public var perfectWindow:Float = 23.00;
	public var sickWindow:Float = 45.00;
	public var goodWindow:Float = 90.00;
	public var badWindow:Float = 135.00;
	public var shitWindow:Float = 180.00; // Shit判定窗口（作为safeZoneOffset上限）
	public var useShitWindowAsSafeZone:Bool = true; // 是否使用shitWindow替代safeFrames计算safeZoneOffset
	public var softJudgmentEdge:Bool = false; // 是否在判定窗口边缘启用软边缘插值（避免卡边界时判定跳变）
	public var safeFrames:Float = 10.0;
	public var guitarHeroSustains:Bool = true;
	public var sustainTailFix:String = 'off'; // 长按音符尾条判定优化: 'off'=原版, 'extend'=延伸末段到可见尾部(A), 'earlyHit'=放宽末段提前命中(B), 'both'=两者皆用
	public var holdReleaseInstantMiss:Bool = false; // 特性1: 启用guitarHeroSustains时，长条命中期间松手立刻判定miss
	public var holdTailJudge:Bool = false; // 特性2: 长条尾部算一个有效命中(加combo+显示评级,但不加分;超时未命中照样断连并miss)
	public var holdScoreBonus:Bool = false; // 特性3: 长条命中期间持续加分直到长条结束(参考原版Funkin)
	public var holdTailLeniency:Bool = false; // 特性2宽容: 尾条判定(释放时机)是否放宽判定窗口
	public var holdTailLeniencyMs:Float = 20.0; // 特性2宽容量(ms)，默认20，范围0-50
	public var inputSystem:String = 'default'; // 输入判定系统: 'default' (传统) 或 'rhythm' (Rhythm模式，只允许击中最近的音符)
	public var discordRPC:Bool = true;
	public var loadingScreen:Bool = true;
	public var basiclanguage:String = 'en-US';
	public var language:String = 'zh_cn';
	public var keyViewer:Bool = false; // 游戏内按键显示覆盖层（复刻 JKPS 效果）
	public var keyViewerProfile:Bool = false; // KeyViewer 左侧图标 + 底部自定义名字（关闭时按键垂直居中）
	public var keyViewerName:String = ''; // KeyViewer 底部显示的自定义名字（留空则读取 images/keyviewer/name.txt）

	//杂七杂八的特性
	public var fpsCounterSize:Int = 14;
	public var rainbowfpscounter:Bool = false;
	public var exgameversion:Bool = true;
	public var exratingDisplay:Bool = true;
	public var showHaxelibs:Bool = true;
	public var rmPerfect:String = 'off'; // 'off'=正常(Perfect独立判定), 'remove'=完全移除Perfect, 'sickPlus'=Perfect变为Sick+状态(算Sick但可选显示Perfect贴图,给Perfect分数)
	public var ratbounce:Bool = true;
	public var scoretxtstyle:String = 'Kathy';
	public var scoreLanguage:String = 'auto'; // 分数文字（scoreTxt）显示语言：'auto' 跟随游戏语言，或指定 English/简体中文/繁體中文/日本語/한국어
	public var rmmsTimeTxt:Bool = false;
	public var showModeLabelInMsTxt:Bool = true;
	public var scoretxtbounce:Bool = false;
	public var exratbounce:Bool = false;
	public var iconbopstyle:String = 'Kathy';
	public var iconbopNormalize:Bool = true; // 图标回弹是否按刷新率归一化（true=任意刷新率表现一致，高刷屏不再偏快/偏慢）
	public var healthbarstyle:String = 'Psych';
	public var ratingsAlpha:Float = 1;
	public var customFadeStyle:String = 'V-Slice';
	public var blueArchiveLanguage:String = 'EN';
	public var showRunningOS:Bool = true;
	//NFE的特性
	//public var CustomFadeSound:Bool = true;
	//public var CustomFadeText:Bool = true;

	//用于MRE加载图片更改，之后也许需要优化
	public var randomIndex :Int = 32;

	public var smoothHP:Bool = true;
	public var healthOverflow:Bool = false; // 超满血：需配合 smoothHP；开启后血量可超过 100%，并让小图标向血条外溢出移动
	public var healthOverflowDrain:Float = 20; // 超满血回落速度系数（lerp），越大回落越快
	public var smoothHPSpeed:Float = 10; // 丝滑血条平滑系数（lerp），越大血条追得越紧、延迟越小
	public var forceSingleSplashAnim:Bool = false;
	public var volumeTheme:String = "Psych";
	public var cpuStrums: Bool = true;
	public var extrahp: Bool = true;
	public var botplayStyle:String = "Psych(New)";
	public var showcaseStyle:String = "Psych";
	public var fpsFont:String = "Psych";
	public var timebarStyle:String = "Psych";
	public var legacynotepos:Bool = false;
	public var chartingVersion:String = '1.0.4-Kathy'; // 制谱器版本: '1.0.4-Kathy' | '1.0.4-Official' | '0.7.3' | '0.6.3'
	public var ratingsPos:String = "camHUD";

	public var fpsPosition:String = "TOP_LEFT"; // "TOP_LEFT", "TOP_RIGHT", "BOTTOM_LEFT", "BOTTOM_RIGHT"
	public var fpsSpacing:Int = 10;

	// 启动开屏模式: 'Kathy' = 自定义 Logo 开屏, 'Flixel' = Flixel 自带 splash, 'None' = 直接进游戏
	public var splashMode:String = 'Kathy';
	public var hudSize:Float = 1.0;
	public var enableModsImport:Bool = false; // Enable Mods Import in the main menu
	public var eventDebug:Bool = true;
	public var botplayScore:Bool = true;
	public var botplayPerfectTiming:Bool = false; // BotPlay 模式下强制显示 0ms 命中时间
	public var systemCursor:Bool = false;
	public var hudZoomStyle:String = "default";
	public var showNPS:Bool = true; // Show NPS in the HUD
	public var showResultScreen:Bool = true; // Show the result screen after finishing a song
	public var comboSprDisplay:Bool = false; //据说这是官方废稿，我不确定
	public var ratingFallStyle:String = "Legacy"; // 禁用Combo Stacking时的跳动风格：Legacy = 向下速度，Kathy = 向下移动一段距离，Camellia = 原地缩放回弹 + 固定节奏淡出（复刻自 VSCam）
	// Camellia 风格的缩放基准：Proportional = 基于引擎现有 0.7 基准等比回弹，Original = 照搬原版 0.45 → 0.4 绝对数值
	public var camelliaScaleMode:String = "Proportional";
	
	public var backgroundVolume:Bool = true; // 是否启用后台降音
	public var backgroundVolumeLevel:Float = 0.2; // 后台音量级别

	public var fixedTimestep:Bool = true; // 固定时间步长（？）

	public var ratCounter:Bool = true; // 评分计数器
	public var ratCounterAnimation:Bool = true; // 评分计数器动画效果
	public var waterMarkPlay:Bool = true; // 水印
	public var enableGameLog:Bool = false; // 启用游戏内日志显示（按F3切换）
	public var legacyMainMenu:Bool = false; // 是否使用旧版主菜单UI（Psych Engine v0.7.3原生样式）
	public var developer:Bool = false; // 开发者模式：启用后可进入编辑器菜单(MasterEditorMenu)，legacy主界面显示toolbox入口
	public var enableConsoleLog:Bool = true; // 是否在终端/控制台输出日志（debug/移动端默认启用，其余可自定义
	public var useOptimizedNoteLoading:String = 'AUTO'; // OFF / ON / AUTO — AUTO 根据谱面 NPS 自动选择
	public var requestAdminPrivilege:Bool = false; // 是否请求管理员权限（Windows专用）
	public var keepSingAnimation:Bool = true; // 保持sing动画不返回idle（用于Hyperactive成就）
	public var cacheResourcesOnReload:Bool = true; // 重载曲目时缓存资源以加速加载
	public var forceHoldAnimations:Bool = false; // 箭头命中时只播放一次动画，不依赖hold动画
	public var timeBarStripes:Bool = false; // 时间条是否显示条纹
	public var timeBarGradient:Bool = false; // 时间条是否使用渐变（对手色→玩家色，仅Psych样式）
	public var singleHoldNoteAnimation:Bool = true; // 按住长条音符时只播放一次confirm动画
	public var autoResetStrumAnim:Bool = true; // 是否自动恢复箭头默认动画（普通按键和hold note）
	public var ghostEffect:Bool = true; // 多押时角色的ghost残影效果

	public var playStateAdaptiveWidth:Bool = false; // PlayState宽屏自适应：高度锁定720，宽度960~1680自适应

	public var chartEditorFollowWindow:Bool = false; // 制谱器分辨率是否跟随窗口：true=跟随窗口(720p~1080p自适应)，false=使用游戏默认固定分辨率1280x720

	// 当模组没有perfect/marvelous贴图时，是否改用sick贴图显示
	public var fallbackPerfectToSick:Bool = true;
	public var fallbackEXPerfectToSick:Bool = true;

	public var soundTrayStyle:String = 'Flixel';
	public var holdNoteBehind:Bool = false; // 将 hold note 放在正常音符和 strum 箭头下面

	// FPS计数器自定义设置
	public var fpsColor:FlxColor = 0xFFE6CAFF; // FPS计数器颜色
	public var fpsOpacity:Float = 1.0; // FPS计数器不透明度
	public var fpsFontSize:Int = 14; // FPS计数器字体大小
	public var fpsShowFPS:Bool = true; // 显示FPS
	public var fpsShowDelay:Bool = true; // 显示延迟
	public var fpsShowRAM:Bool = true; // 显示内存使用
	public var fpsShowMemPeak:Bool = true; // 显示内存峰值
	public var fpsShowObjects:Bool = true; // 显示对象数量
	public var fpsBgEnabled:Bool = false; // 是否启用FPS计数器背景
	public var fpsBgColor:FlxColor = 0xFF000000; // FPS计数器背景颜色
	public var fpsBgOpacity:Float = 0.5; // FPS计数器背景不透明度
	public var fpsBgPadding:Int = 5; // FPS计数器背景内边距
	public var fpsForceMB:Bool = false; // 是否强制显示MB而非GB
	public var fpsShowPlatform:Bool = true; // 显示Platform信息
	public var fpsShowOSVersion:Bool = true; // 显示OS版本
	public var fpsShowResolution:Bool = true; // 显示分辨率
	public var fpsShowRefreshRate:Bool = true; // 显示刷新率

	// Fake OS 伪装功能
	public var fakeOSMode:Bool = false;
	public var fakeWindowTitle:String = "Kathy Engine";
	public var fakeWindowTitlePreset:String = "Kathy Engine";
	public var fakeOSVersion:String = "1.5.1";

	// 动态窗口标题（Dynamic Window Title）
	public var dynamicWindowTitle:Bool = false; // 启用动态窗口标题（显示当前界面/模组/曲目信息）
	public var windowTitleShowState:Bool = true; // 标题中显示当前界面/状态名称
	public var windowTitleShowMod:Bool = true; // 标题中显示当前模组名称
	public var windowTitleShowSong:Bool = true; // 标题中显示当前游玩曲目
	public var windowTitleShowDifficulty:Bool = false; // 标题中显示当前曲目难度

	// Leather 风格相关
	public var biggerInfoText:Bool = false; // 更大的信息文本
	public var loadLeatherIcons:Bool = false; // 启用后优先加载 Leather 格式的小图标（leather/<角色名>-icons.png），支持 Mods 覆盖
	public var opponentSplashes:Bool = false; // 启用后对手侧箭头击打也会显示 NoteSplash
	public var holdCovers:Bool = true; // 长条按住期间在箭头上显示 Hold Cover 光效（类似原版 FNF），末尾播放爆发动画
	public var opponentHoldCovers:Bool = false; // 对手侧也显示 Hold Cover（需 CPU Strums 可见）

	// Simple Info Display (Leather风格) 设置
	public var fpsLayer:String = "Stage"; // FPS计数器所在图层: "Stage" 或 "Game"
	public var fpsStyle:String = "Psych"; // FPS计数器样式: "Psych" 或 "Simple"
	public var simpleInfoColor:FlxColor = 0x000000; // SimpleInfoDisplay 颜色
	public var simpleInfoFontSize:Int = 12; // SimpleInfoDisplay 字体大小（_sans 用 12px，与 Leather 一致）
	public var simpleInfoShowFPS:Bool = true; // SimpleInfoDisplay 显示FPS
	public var simpleInfoShowMem:Bool = true; // SimpleInfoDisplay 显示内存
	public var simpleInfoShowVersion:Bool = false; // SimpleInfoDisplay 显示版本

	// KeyViewer 累计按键总数（keyViewerTotal）已移至 objects.KeyViewer 内部独立存档，
	// 不再存放在 ClientPrefs 主设置里，以免主设置文件损坏时把它一起清零。
	// KeyViewer 轨迹方向：'auto' 跟随 downscroll，'up' 强制上升，'down' 强制下落
	public var keyViewerTrail:String = 'auto';
	// KeyViewer 位置偏移（像素，相对默认位置）：在设置内拖动校准，跨重启持久化
	public var keyViewerPosX:Float = 0;
	public var keyViewerPosY:Float = 0;

}

class ClientPrefs {
	public static var data:SaveVariables = {};
	public static var defaultData:SaveVariables = {}

	/**
	 * 把 stageQuality 字符串映射成 openfl.display.StageQuality。
	 * 供 Main 启动与设置界面实时切换使用。
	 */
	public static function getStageQuality():StageQuality
	{
		return switch (data.stageQuality)
		{
			case 'LOW': StageQuality.LOW;
			case 'HIGH': StageQuality.HIGH;
			case 'BEST': StageQuality.BEST;
			default: StageQuality.MEDIUM;
		}
	}

	//Every key has two binds, add your key bind down here and then add your control on options/ControlsSubState.hx and Controls.hx
	public static var keyBinds:Map<String, Array<FlxKey>> = [
		//Key Bind, Name for ControlsSubState
		'note_left'		=> [D, LEFT],
		'note_down'		=> [F, DOWN],
		'note_up'		=> [J, UP],
		'note_right'	=> [K, RIGHT],
		
		'ui_left'		=> [A, LEFT],
		'ui_down'		=> [S, DOWN],
		'ui_up'			=> [W, UP],
		'ui_right'		=> [D, RIGHT],
		
		'accept'		=> [SPACE, ENTER],
		'back'			=> [BACKSPACE, ESCAPE],
		'pause'			=> [ENTER, ESCAPE],
		'reset'			=> [R],
		
		'volume_mute'	=> [ZERO],
		'volume_up'		=> [NUMPADPLUS, PLUS],
		'volume_down'	=> [NUMPADMINUS, MINUS],
		
		'debug_1'		=> [SEVEN],
		'debug_2'		=> [EIGHT],
		'debug_3'		=> [F7],
		'debug_4'		=> [F6],
		
		'fullscreen'	=> [F11]
	];
	public static var gamepadBinds:Map<String, Array<FlxGamepadInputID>> = [
		'note_up'		=> [DPAD_UP, Y],
		'note_left'		=> [DPAD_LEFT, X],
		'note_down'		=> [DPAD_DOWN, A],
		'note_right'	=> [DPAD_RIGHT, B],
		
		'ui_up'			=> [DPAD_UP, LEFT_STICK_DIGITAL_UP],
		'ui_left'		=> [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
		'ui_down'		=> [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
		'ui_right'		=> [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
		
		'accept'		=> [A, START],
		'back'			=> [B],
		'pause'			=> [START],
		'reset'			=> [BACK]
	];
	public static var mobileBinds:Map<String, Array<MobileInputID>> = [
		'note_up'		=> [NOTE_UP],
		'note_left'		=> [NOTE_LEFT],
		'note_down'		=> [NOTE_DOWN],
		'note_right'	=> [NOTE_RIGHT],

		'ui_up'			=> [UP],
		'ui_left'		=> [LEFT],
		'ui_down'		=> [DOWN],
		'ui_right'		=> [RIGHT],

		'accept'		=> [A],
		'back'			=> [B],
		'pause'			=> [#if android NONE #else P #end],
		'reset'			=> [NONE]
	];
	public static var defaultKeys:Map<String, Array<FlxKey>> = null;
	public static var defaultButtons:Map<String, Array<FlxGamepadInputID>> = null;
	public static var defaultMobileBinds:Map<String, Array<MobileInputID>> = null;

	public static function resetKeys(controller:Null<Bool> = null) //Null = both, False = Keyboard, True = Controller
	{
		if(controller != true)
			for (key in keyBinds.keys())
				if(defaultKeys.exists(key))
					keyBinds.set(key, defaultKeys.get(key).copy());

		if(controller != false)
			for (button in gamepadBinds.keys())
				if(defaultButtons.exists(button))
					gamepadBinds.set(button, defaultButtons.get(button).copy());
	}

	public static function clearInvalidKeys(key:String)
	{
		var keyBind:Array<FlxKey> = keyBinds.get(key);
		var gamepadBind:Array<FlxGamepadInputID> = gamepadBinds.get(key);
		var mobileBind:Array<MobileInputID> = mobileBinds.get(key);
		while(keyBind != null && keyBind.contains(NONE)) keyBind.remove(NONE);
		while(gamepadBind != null && gamepadBind.contains(NONE)) gamepadBind.remove(NONE);
		while(mobileBind != null && mobileBind.contains(NONE)) mobileBind.remove(NONE);
	}

	public static function loadDefaultKeys()
	{
		defaultKeys = keyBinds.copy();
		defaultButtons = gamepadBinds.copy();
		defaultMobileBinds = mobileBinds.copy();
	}

	public static function saveSettings() {
		for (key in Reflect.fields(data))
			Reflect.setField(FlxG.save.data, key, Reflect.field(data, key));

		#if ACHIEVEMENTS_ALLOWED Achievements.save(); #end

		// flush the main save and check the return value; on failure only log, never throw
		var ok = FlxG.save.flush();
		if (ok != true)
			FlxG.log.error('ClientPrefs: Failed to save main save (funkin.sol), flush returned ' + ok);
		else
			writeBackupSave(); // only write the backup after a successful main save, so the backup is always intact

		//Placing this in a separate save so that it can be manually deleted without removing your Score and stuff
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		save.data.keyboard = keyBinds;
		save.data.gamepad = gamepadBinds;
		save.data.mobile = mobileBinds;
		save.flush();
		FlxG.log.add("Settings saved!");
	}

	/**
	 * Bind and return the backup SharedObject (funkin_backup) for the main save.
	 * Returns null if binding fails or throws; caller must check.
	 */
	private static function getBackupSave():FlxSave {
		try {
			var backup:FlxSave = new FlxSave();
			if (backup.bind('funkin_backup', CoolUtil.getSavePath()))
				return backup;
		} catch (e:Dynamic) {
			FlxG.log.error('ClientPrefs: Failed to bind backup save: ' + e);
		}
		return null;
	}

	/**
	 * Write all fields of the current ClientPrefs.data into the standalone backup save.
	 * On failure only log; never interrupt the main flow.
	 */
	private static function writeBackupSave():Void {
		var backup:FlxSave = getBackupSave();
		if (backup == null) return;
		try {
			for (key in Reflect.fields(data))
				Reflect.setField(backup.data, key, Reflect.field(data, key));
			if (backup.flush() != true)
				FlxG.log.error('ClientPrefs: Failed to save backup (funkin_backup)');
		} catch (e:Dynamic) {
			FlxG.log.error('ClientPrefs: Exception while writing backup save: ' + e);
		}
	}



	public static function loadPrefs() {
		#if ACHIEVEMENTS_ALLOWED Achievements.load(); #end

		// Corruption detection & auto-restore: if the main save is truncated/corrupted (zero fields),
		// but the backup still holds data, restore the main save from it and self-heal via flush.
		// On first run both are empty, so we fall through to defaults; no false trigger.
		try {
			if (FlxG.save.data != null && Reflect.fields(FlxG.save.data).length == 0) {
				var backup:FlxSave = getBackupSave();
				if (backup != null && Reflect.fields(backup.data).length > 0) {
					for (key in Reflect.fields(backup.data))
						Reflect.setField(FlxG.save.data, key, Reflect.field(backup.data, key));
					if (FlxG.save.flush() != true)
						FlxG.log.error('ClientPrefs: Failed to flush main save after restoring from backup');
					else
						FlxG.log.add('ClientPrefs: Main save was corrupted, auto-restored from backup (funkin_backup)');
				}
			}
		} catch (e:Dynamic) {
			// The restore process must never throw on the startup path; on failure silently fall back to defaults
			FlxG.log.error('ClientPrefs: Exception during backup restore, skipped: ' + e);
		}

		for (key in Reflect.fields(data))
			if (key != 'gameplaySettings' && Reflect.hasField(FlxG.save.data, key))
				Reflect.setField(data, key, Reflect.field(FlxG.save.data, key));
		
		// 确保 soundTrayStyle 被正确初始化
		if (data.soundTrayStyle == null) {
			data.soundTrayStyle = 'Flixel';
		}

		// 为 1.5.x 新增的移动端判定补偿字段填充默认值（兼容老存档升级）
		// FlxG.save.data 里没有对应键时，Reflect.hasField 返回 false，此时保持类声明中的默认值。
		if (!Reflect.hasField(FlxG.save.data, 'mobileJudgmentCompensation'))
			data.mobileJudgmentCompensation = FlxG.onMobile;
		if (!Reflect.hasField(FlxG.save.data, 'mobileJudgmentOffset') || data.mobileJudgmentOffset < 0)
			data.mobileJudgmentOffset = 10.0;

		// 为 1.5.x 新增的 Shit 窗口与 SafeZone 模式填充默认值（兼容老存档升级）
		if (!Reflect.hasField(FlxG.save.data, 'shitWindow') || data.shitWindow <= 0)
			data.shitWindow = 180.0;
		if (!Reflect.hasField(FlxG.save.data, 'useShitWindowAsSafeZone'))
			data.useShitWindowAsSafeZone = true;
		if (!Reflect.hasField(FlxG.save.data, 'softJudgmentEdge'))
			data.softJudgmentEdge = false;

		// 向后兼容：将旧版 Bool 类型的 rmPerfect 转换为新版 String 三选一
		// 旧 false → 'off'(正常), 旧 true → 'remove'(完全移除), 新存档直接为 String
		if (Reflect.hasField(FlxG.save.data, 'rmPerfect'))
		{
			var savedRmPerfect:Dynamic = Reflect.field(FlxG.save.data, 'rmPerfect');
			if (savedRmPerfect == true)
				data.rmPerfect = 'remove';
			else if (savedRmPerfect == false)
				data.rmPerfect = 'off';
			// 若已是 String ('off'/'remove'/'sickPlus') 则保持不变
		}

		// 确保 Fake OS 标题从预设中正确初始化
		if (data.fakeWindowTitlePreset != null) {
			data.fakeWindowTitle = data.fakeWindowTitlePreset;
		}

		// 确保 FlxG 完全初始化后再应用设置
		if (FlxG.game != null) {
			// 应用固定时间步长设置
			FlxG.fixedTimestep = data.fixedTimestep;

			// 根据当前设置更新 FPS 计数器（updateFPSLayer 内部已调用 updateFPSCounterVisibility
			Main.updateFPSLayer();

			if(Main.gameLogVar != null)
				Main.gameLogVar.setEnabled(data.enableGameLog);

			// 应用 Fake OS 窗口标题
			#if (!mobile && !html5)
			if (data.fakeOSMode && FlxG.stage != null && FlxG.stage.window != null) {
				FlxG.stage.window.title = data.fakeWindowTitle;
			}
			#end

			#if (!html5 && !switch)
			FlxG.autoPause = ClientPrefs.data.autoPause;

			if(FlxG.save.data.framerate == null) {
				final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
				data.framerate = Std.int(FlxMath.bound(refreshRate, 60, 240));
			}
			#end

			if (data.fpsRework)
				FlxG.stage.window.frameRate = data.framerate;
			else
			{
				if (data.framerate > FlxG.drawFramerate)
				{
					FlxG.updateFramerate = data.framerate;
					FlxG.drawFramerate = data.framerate;
				}
				else
				{
					FlxG.drawFramerate = data.framerate;
					FlxG.updateFramerate = data.framerate;
				}
			}
		}

		if(FlxG.save.data.gameplaySettings != null)
		{
			var savedMap:Map<String, Dynamic> = FlxG.save.data.gameplaySettings;
			for (name => value in savedMap)
				data.gameplaySettings.set(name, value);
		}
		
		// flixel automatically saves your volume!
		if (FlxG.game != null) {
			if(FlxG.save.data.volume != null)
				FlxG.sound.volume = FlxG.save.data.volume;
			if (FlxG.save.data.mute != null)
				FlxG.sound.muted = FlxG.save.data.mute;
		}

		#if DISCORD_ALLOWED DiscordClient.check(); #end

		// controls on a separate save file
		var save:FlxSave = new FlxSave();
		save.bind('controls_v3', CoolUtil.getSavePath());
		if(save != null)
		{
			if(save.data.keyboard != null)
			{
				var loadedControls:Map<String, Array<FlxKey>> = save.data.keyboard;
				for (control => keys in loadedControls)
					if(keyBinds.exists(control)) keyBinds.set(control, keys);
			}
			if(save.data.gamepad != null)
			{
				var loadedControls:Map<String, Array<FlxGamepadInputID>> = save.data.gamepad;
				for (control => keys in loadedControls)
					if(gamepadBinds.exists(control)) gamepadBinds.set(control, keys);
			}
			if(save.data.mobile != null) {
				var loadedControls:Map<String, Array<MobileInputID>> = save.data.mobile;
				for (control => keys in loadedControls)
					if(mobileBinds.exists(control)) mobileBinds.set(control, keys);
			}
			reloadVolumeKeys();
		}
	}

	inline public static function getGameplaySetting(name:String, defaultValue:Dynamic = null, ?customDefaultValue:Bool = false):Dynamic
	{
		if(!customDefaultValue) defaultValue = defaultData.gameplaySettings.get(name);
		return /*PlayState.isStoryMode ? defaultValue : */ (data.gameplaySettings.exists(name) ? data.gameplaySettings.get(name) : defaultValue);
	}

	public static function reloadVolumeKeys()
	{
		TitleState.muteKeys = keyBinds.get('volume_mute').copy();
		TitleState.volumeDownKeys = keyBinds.get('volume_down').copy();
		TitleState.volumeUpKeys = keyBinds.get('volume_up').copy();
		toggleVolumeKeys(true);
	}
	public static function toggleVolumeKeys(?turnOn:Bool = true)
	{
		final emptyArray = [];
		FlxG.sound.muteKeys = (!Controls.instance.mobileC && turnOn) ? TitleState.muteKeys : emptyArray;
		FlxG.sound.volumeDownKeys = (!Controls.instance.mobileC && turnOn) ? TitleState.volumeDownKeys : emptyArray;
		FlxG.sound.volumeUpKeys = (!Controls.instance.mobileC && turnOn) ? TitleState.volumeUpKeys : emptyArray;
	}
}
