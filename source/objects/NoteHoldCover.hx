package objects;

import haxe.Json;
import openfl.utils.AssetType;

/**
 * 原版 FNF (V-Slice) 风格的 Hold Cover：
 * 长条按住期间在对应 strum 箭头居中位置循环播放光效，
 * 长条完整按完时在末尾播放 end 爆发动画。
 *
 * 配置兼容 NoteSplash 的方式：
 *  - 默认素材：assets/shared/images/holdCover/holdCover{Color}.png/.xml
 *    （Color = Purple|Blue|Green|Red），动画前缀 holdCoverStart{Color} / holdCover{Color} / holdCoverEnd{Color}
 *  - 皮肤：ClientPrefs.data.holdCoverSkin（后缀，如 -Psych），经 Note.resolveSkinPath 解析（兼容 HSV/像素/mod）
 *  - 每色可带 JSON 配置：assets/shared/images/holdCover/holdCover{Color}{后缀}.json
 *    格式 { "start": "...", "hold": "...", "end": "...", "fps": 24, "offsets": [0,0], "scale": 1 }
 *  - 可用 states/editors/HoldCoverEditorState 编辑并保存 JSON
 */
typedef HoldCoverAnim = {
	@:optional var start:String;
	@:optional var hold:String;
	@:optional var end:String;
	@:optional var fps:Int;
	@:optional var offsets:Array<Float>;
	@:optional var scale:Float;
};

typedef HoldCoverConfig = {
	scale:Float,
	anims:Map<String, HoldCoverAnim>
};

class NoteHoldCover extends FlxSprite
{
	public static final COVER_COLORS:Array<String> = ['Purple', 'Blue', 'Green', 'Red'];
	public static final defaultHoldCover:String = 'holdCover/holdCover';

	/** 已加载配置缓存：key = color + postfix */
	public static var configs:Map<String, HoldCoverConfig> = new Map<String, HoldCoverConfig>();

	/** 跟随的目标 strum（每帧同步位置 / 透明度，兼容 modchart 移动） */
	public var targetStrum:StrumNote = null;
	/** 正在播放 end 动画 */
	public var isEnding:Bool = false;
	/** 距上次被长条命中刷新的时间；超过 timeout 自动隐藏（断连兜底） */
	public var holdTimer:Float = 0;
	/** 超时时间（秒），由 PlayState 在每次命中时按 stepCrochet 更新 */
	public var timeout:Float = 0.35;
	/** 编辑器预览时置 true，禁止自动隐藏 */
	public var freezeHold:Bool = false;

	public var coverColor:String;
	public var config:HoldCoverConfig;

	/** 附加偏移（来自 JSON 配置 / 编辑器），在 update 定位时叠加 */
	public var animOffset:Array<Float> = [0, 0];

	public function new(strum:StrumNote, data:Int, ?config:HoldCoverConfig)
	{
		super(strum.x, strum.y);
		targetStrum = strum;
		coverColor = getColorForData(data);
		if (config == null) config = getConfigForColor(coverColor);
		this.config = config;

		frames = Paths.getSparrowAtlas(getColorAtlasPath(coverColor));
		reloadAnims(getAnim(coverColor));

		antialiasing = ClientPrefs.data.antialiasing;
		refreshScale();
		centerOffsets(); // 让光效内容按当前帧居中到 300x400 原始盒内（覆盖 XML 的 frameX/frameY 偏移）
		visible = false;
	}

	// ---- 配置 / 皮肤解析（兼容 NoteSplash 方式）----

	public static function getColorForData(data:Int):String
	{
		var i:Int = data % COVER_COLORS.length;
		if (i < 0) i += COVER_COLORS.length;
		return COVER_COLORS[i];
	}

	public static function getHoldCoverPostfix():String
	{
		var skinName:String = ClientPrefs.data.holdCoverSkin.trim();
		if (skinName != ClientPrefs.defaultData.holdCoverSkin && skinName.length > 0)
			return '-' + skinName.toLowerCase().replace(' ', '-');
		return '';
	}

	public static function getColorAtlasPath(color:String):String
	{
		var base:String = defaultHoldCover + color + getHoldCoverPostfix();
		return Note.resolveSkinPath(base, true);
	}

	public static function getConfigForColor(color:String):HoldCoverConfig
	{
		var key:String = color + getHoldCoverPostfix();
		if (configs.exists(key)) return configs.get(key);

		var cfg:HoldCoverConfig = createDefaultConfig(color);
		var jsonPath:String = defaultHoldCover + color + getHoldCoverPostfix();
		if (Paths.fileExists('images/$jsonPath.json', AssetType.TEXT))
		{
			try
			{
				var raw:Dynamic = Json.parse(Paths.getTextFromFile('images/$jsonPath.json'));
				var anim:HoldCoverAnim = parseAnim(raw);
				cfg.anims.set(color, anim);
				if (raw.scale != null) cfg.scale = raw.scale;
			}
			catch (e:Dynamic) {}
		}
		configs.set(key, cfg);
		return cfg;
	}

	public static function createDefaultConfig(color:String):HoldCoverConfig
	{
		var cfg:HoldCoverConfig = {scale: 1, anims: new Map<String, HoldCoverAnim>()};
		cfg.anims.set(color, {
			start: 'holdCoverStart' + color,
			hold: 'holdCover' + color,
			end: 'holdCoverEnd' + color,
			fps: 24,
			offsets: [0, 0],
			scale: 1
		});
		return cfg;
	}

	public static function parseAnim(raw:Dynamic):HoldCoverAnim
	{
		var a:HoldCoverAnim = {start: null, hold: null, end: null, fps: 24, offsets: [0, 0], scale: 1};
		if (raw.start != null) a.start = raw.start;
		if (raw.hold != null) a.hold = raw.hold;
		if (raw.end != null) a.end = raw.end;
		if (raw.fps != null) a.fps = raw.fps;
		if (raw.offsets != null && raw.offsets.length >= 2) a.offsets = [raw.offsets[0], raw.offsets[1]];
		if (raw.scale != null) a.scale = raw.scale;
		return a;
	}

	function getAnim(color:String):HoldCoverAnim
	{
		if (config != null && config.anims.exists(color)) return config.anims.get(color);
		return {start: 'holdCoverStart' + color, hold: 'holdCover' + color, end: 'holdCoverEnd' + color, fps: 24, offsets: [0, 0], scale: 1};
	}

	// ---- 动画（供编辑器热更新）----

	public function reloadAnims(?anim:HoldCoverAnim):Void
	{
		if (anim == null) anim = getAnim(coverColor);

		var fps:Int = (anim.fps != null) ? anim.fps : 24;
		animOffset = (anim.offsets != null && anim.offsets.length >= 2) ? [anim.offsets[0], anim.offsets[1]] : [0.0, 0.0];
		addSafe('start', (anim.start != null) ? anim.start : ('holdCoverStart' + coverColor), fps, false);
		addSafe('hold', (anim.hold != null) ? anim.hold : ('holdCover' + coverColor), fps, true);
		addSafe('end', (anim.end != null) ? anim.end : ('holdCoverEnd' + coverColor), fps, false);
		animation.finishCallback = onAnimFinished;
	}

	public function reloadAtlas(path:String):Void
	{
		try
		{
			frames = Paths.getSparrowAtlas(path);
		}
		catch (e:Dynamic) {}
		reloadAnims();
	}

	function addSafe(name:String, prefix:String, fps:Int, loop:Bool):Void
	{
		animation.remove(name); // 覆盖旧动画（clearAnimations 在本 flixel 版本为私有）
		animation.addByPrefix(name, prefix, fps, loop);
	}

	/** 当前图集中是否存在以指定前缀开头的帧 */
	public function prefixExists(prefix:String):Bool
	{
		if (frames == null) return false;
		for (f in frames.frames)
			if (f.name.startsWith(prefix))
				return true;
		return false;
	}

	/** 直接设置统一附加偏移（start/hold/end 共用），下一帧 update 生效 */
	public function setOffsets(off:Array<Float>):Void
	{
		if (off != null && off.length >= 2)
			animOffset = [off[0], off[1]];
	}

	// ---- 缩放 / 居中 / 回调 ----

	function refreshScale():Void
	{
		var s:Float = 0.7;
		var cfgScale:Float = (config != null) ? config.scale : 1;
		if (targetStrum != null && targetStrum.width > 0)
			s = targetStrum.width * 1.91 / 300 * cfgScale;
		if (Math.abs(s - scale.x) > 0.001)
		{
			scale.set(s, s);
			updateHitbox();
		}
	}

	function onAnimFinished(name:String):Void
	{
		switch (name)
		{
			case 'start':
				animation.play('hold', true);
			case 'end':
				visible = false;
				isEnding = false;
		}
	}

	/** 长条头命中：播放 start -> hold 循环 */
	public function startHold():Void
	{
		isEnding = false;
		holdTimer = 0;
		visible = true;
		animation.play('start', true);
	}

	/** 长条中段持续命中：刷新存活计时，必要时恢复显示 */
	public function keepHold():Void
	{
		holdTimer = 0;
		if (isEnding) return;
		if (!visible || animation.curAnim == null
			|| (animation.curAnim.name != 'hold' && animation.curAnim.name != 'start'))
			startHold();
	}

	/** 长条末尾命中：播放 end 爆发动画，播完自动隐藏 */
	public function playEnd():Void
	{
		holdTimer = 0;
		visible = true;
		isEnding = true;
		animation.play('end', true);
	}

	/** 隐藏（松手 / miss）。force=false 时不打断正在播放的 end 动画 */
	public function hideCover(force:Bool = true):Void
	{
		if (isEnding && !force) return;
		isEnding = false;
		holdTimer = 0;
		visible = false;
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (targetStrum != null)
		{
			refreshScale();
			if (frame != null) centerOffsets(); // 每帧按当前帧重算 offset，使光效内容居中于原始盒

			// 把 300x400 的原始盒中心对齐到 strum 中心：
			// centerOffsets 后内容中心恒在 (x + sourceSize*scale/2)，故令其等于 strum 中心即可精确居中。
			var fw:Float = (frame != null) ? frame.sourceSize.x : 300;
			var fh:Float = (frame != null) ? frame.sourceSize.y : 400;
			x = (targetStrum.x + targetStrum.width / 2) - fw * scale.x / 2 + animOffset[0];
			y = (targetStrum.y + targetStrum.height / 2) - fh * scale.y / 2 + animOffset[1];
			alpha = targetStrum.alpha;
		}

		// 断连兜底：一段时间没有被长条命中刷新就自动隐藏
		if (!freezeHold && visible && !isEnding)
		{
			holdTimer += elapsed;
			if (holdTimer > timeout)
			{
				holdTimer = 0;
				visible = false;
			}
		}
	}

	override function destroy()
	{
		targetStrum = null;
		super.destroy();
	}
}
