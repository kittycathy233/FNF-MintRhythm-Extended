package backend;

import flixel.math.FlxMath;
import openfl.utils.Assets;
import haxe.Json;

/**
 * 多键（multi-key）配置中心单例。
 *
 * 设计照搬 MintyEngine-Revived 的 ExtraKeysHandler：以 `mania`（= 键数 - 1）为索引，
 * 把所有“4 键专属”逻辑（箭头生成、判定、颜色、动画、键位、布局缩放）泛化为读
 * extrakeys.json。多出的键复用 ek 皮肤已有的 rombus（菱形）/ circle（圆形）样式，
 * 无需新增美术资源。
 *
 * 兼容性：mania = 3 即标准 4 键，与旧引擎行为完全一致；只有 mania != 3 时才会切换到
 * ek 皮肤、动态 action 名与扩展配色。
 */
class ExtraKeysHandler
{
	/** 延迟初始化的单例（避免静态初始化阶段 Paths 尚未就绪）。 */
	public static var _instance:ExtraKeysHandler;
	public static var instance(get, null):ExtraKeysHandler;
	private static function get_instance():ExtraKeysHandler
	{
		if (_instance == null) _instance = new ExtraKeysHandler();
		return _instance;
	}

	public var data:ExtraKeysData;

	/** 配置中声明的最小/最大键数（ mania = 键数-1 ）。data 为空时回落 4 键。 */
	public var minKeys(get, null):Int;
	public var maxKeys(get, null):Int;
	private function get_minKeys():Int { return (data != null) ? data.minKeys : 4; }
	private function get_maxKeys():Int { return (data != null) ? data.maxKeys : 4; }

	public function new()
	{
		load();
		if (data == null) data = defaultData();
	}

	public function load():Void
	{
		var raw:String = null;
		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('data/extrakeys.json');
		if (sys.FileSystem.exists(modPath))
			raw = sys.io.File.getContent(modPath);
		#end
		if (raw == null)
		{
			var path:String = Paths.json('extrakeys');
			if (Assets.exists(path, TEXT))
				raw = Assets.getText(path);
		}
		if (raw != null && raw.length > 0)
			data = Json.parse(raw);
	}

	/** 把所有 mania 限制到合法范围 [minKeys-1, maxKeys-1]，越界则 clamp。 */
	public function clampMania(m:Int):Int
	{
		if (data == null) return 3;
		return Std.int(FlxMath.bound(m, data.minKeys - 1, data.maxKeys - 1));
	}

	/** 把某轨 noteData 映射到样式索引（style），多出的键复用 rombus/circle 样式。 */
	public function styleOf(mania:Int, noteData:Int):Int
	{
		mania = clampMania(mania);
		if (data == null || mania < 0 || mania >= data.keys.length) return 0;
		var notes:Array<Int> = data.keys[mania].notes;
		if (notes == null || notes.length == 0) return 0;
		var idx:Int = noteData % notes.length;
		if (idx < 0) idx += notes.length;
		return notes[idx];
	}

	public function animOf(style:Int):EKAnimation
	{
		if (data == null || style < 0 || style >= data.animations.length) return null;
		return data.animations[style];
	}

	/** strum 动画前缀：'LEFT' / 'DOWN' / 'UP' / 'RIGHT' / 'ROMBUS' / 'CIRCLE'。 */
	public function strumOf(style:Int):String
	{
		var a:EKAnimation = animOf(style);
		return (a != null) ? a.strum : 'LEFT';
	}

	/** 音符/箭头颜色前缀：'purple' / 'blue' / 'green' / 'red' / 'rombus' / 'circle'。 */
	public function colorPrefixOf(style:Int):String
	{
		var a:EKAnimation = animOf(style);
		return (a != null) ? a.rgb : 'purple';
	}

	/** 角色 sing 方向：'LEFT' / 'DOWN' / 'UP' / 'RIGHT'。 */
	public function singOf(style:Int):String
	{
		var a:EKAnimation = animOf(style);
		return (a != null) ? a.sing : 'LEFT';
	}

	public function rgbOf(style:Int):Array<Int>
	{
		if (data == null || style < 0 || style >= data.colors.length) return [255, 255, 255];
		return data.colors[style];
	}

	public function rgbPixelOf(style:Int):Array<Int>
	{
		if (data == null || style < 0 || style >= data.colorsPixel.length) return [255, 255, 255];
		return data.colorsPixel[style];
	}

	public function hsvOf(style:Int):Array<Int>
	{
		if (data == null || style < 0 || style >= data.hsv.length) return [0, 0, 0];
		return data.hsv[style];
	}

	/** 返回 [mania][keyIndex] = [FlxKey code, ...] 的物理键码数组（原始 Int）。 */
	public function keybindsFor(mania:Int):Array<Array<Int>>
	{
		mania = clampMania(mania);
		if (data == null || mania < 0 || mania >= data.keybinds.length) return [];
		return data.keybinds[mania];
	}

	/** 多键统一皮肤 atlas key；未配置或 data 为空时回落到 ek 皮肤，保证不崩溃。 */
	public function skinPath():String
	{
		if (data != null && data.skin != null && data.skin.length > 0) return data.skin;
		return 'noteSkins/ek/NOTE_assets';
	}

	public function scaleFor(mania:Int):Float
	{
		mania = clampMania(mania);
		if (data == null || mania < 0 || mania >= data.scales.length) return 1.0;
		return data.scales[mania];
	}

	/** 当前 mania 对应的键数（= mania + 1）。 */
	public function keyCount(mania:Int):Int
	{
		return clampMania(mania) + 1;
	}

	private function defaultData():ExtraKeysData
	{
		// 极端兜底：json 缺失时退化为标准 4 键，保证引擎仍可运行。
		return {
			minKeys: 4,
			maxKeys: 4,
			skin: 'noteSkins/ek/NOTE_assets',
			keys: [{notes: [0, 1, 2, 3]}],
			animations: [
				{strum: 'LEFT', rgb: 'purple', hsv: 'A', sing: 'LEFT', pixel: 0},
				{strum: 'DOWN', rgb: 'blue', hsv: 'B', sing: 'DOWN', pixel: 1},
				{strum: 'UP', rgb: 'green', hsv: 'C', sing: 'UP', pixel: 2},
				{strum: 'RIGHT', rgb: 'red', hsv: 'D', sing: 'RIGHT', pixel: 3}
			],
			colors: [[194, 116, 241], [23, 245, 248], [245, 248, 86], [245, 86, 191]],
			colorsPixel: [[195, 116, 241], [23, 245, 248], [245, 248, 86], [245, 86, 191]],
			hsv: [[0, 0, 0], [0, 0, 0], [0, 0, 0], [0, 0, 0]],
			keybinds: [[[37, 65], [40, 83], [38, 87], [39, 68]]],
			scales: [1.0],
			pixelScales: [1.0]
		};
	}
}

typedef EKManiaEntry =
{
	var notes:Array<Int>;
}

typedef EKAnimation =
{
	var strum:String;
	var rgb:String;
	var hsv:String;
	var sing:String;
	var pixel:Int;
}

typedef ExtraKeysData =
{
	var minKeys:Int;
	var maxKeys:Int;
	/** 多键（非基础键数）统一使用的音符皮肤 atlas key（如 noteSkins/ek/NOTE_assets）。基础键数仍沿用歌曲自身 arrowSkin。 */
	var ?skin:String;
	var keys:Array<EKManiaEntry>;
	var animations:Array<EKAnimation>;
	var colors:Array<Array<Int>>;
	var colorsPixel:Array<Array<Int>>;
	var hsv:Array<Array<Int>>;
	var keybinds:Array<Array<Array<Int>>>;
	var scales:Array<Float>;
	var pixelScales:Array<Float>;
}
