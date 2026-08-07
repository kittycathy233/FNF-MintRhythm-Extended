package backend;

import openfl.utils.Assets;
import haxe.Json;
import backend.ClientPrefs;
import backend.Language;

/**
 * 分数文字（scoreTxt）专用本地化系统。
 * 文本与字体映射存放在 assets/languages/scoretxt/{语言代码}.json，
 * 与 assets/languages/{语言}.json（UI 文本）相互独立。
 *
 * 实际使用的语言由 ClientPrefs.data.scoreLanguage 决定：
 *   'auto' 时跟随游戏语言（ClientPrefs.data.language）。
 */
class ScoreLanguage
{
	private static var scoreLang:Map<String, String> = new Map<String, String>();
	private static var loaded:Bool = false;

	// 将设置值解析为分数文本语言代码（对应 assets/languages/scoretxt/ 下的文件名）。
	// 'auto' 跟随游戏语言；其余选项值本身即语言代码，直接作为文件名返回。
	public static function resolveLang():String
	{
		var pref:String = ClientPrefs.data.scoreLanguage;
		if (pref == null || pref == '' || pref == 'auto')
			return ClientPrefs.data.language;
		return pref;
	}

	// 原始引擎（英文）默认值：当 scoretxt JSON 缺失某 key 时回退到此，
	// 从而尽可能保证原有兼容性（不会出现 score_label_xxx 这类裸 key）。
	private static var DEFAULTS:Map<String, String> = [
		'score_font'            => 'scoretxt/fusion-pixel-10px-monospaced-latin.ttf',
		'score_label_score'     => 'Score',
		'score_label_nps'       => 'NPS',
		'score_label_miss'      => 'Miss',
		'score_label_misses'    => 'Misses',
		'score_label_acc'       => 'Acc',
		'score_label_combobreaks'=> 'Combo Breaks',
		'score_label_average'   => 'Average',
		'score_label_accuracy'  => 'Accuracy',
		'score_label_rating'    => 'Rating'
	];

	// 载入对应语言的分数文本；可传入强制语言代码（测试用）
	public static function load(?forceLang:String):Void
	{
		var lang:String = (forceLang != null && forceLang.length > 0) ? forceLang : resolveLang();
		if (lang == null || lang.length == 0) lang = 'en_us';

		scoreLang = new Map<String, String>();
		loaded = false;

		if (tryLoad(lang))
			return;

		// 目标语言文件缺失时回退到 en_us
		if (lang != 'en_us')
			tryLoad('en_us');
	}

	private static function tryLoad(lang:String):Bool
	{
		var path:String = 'assets/languages/scoretxt/$lang.json';
		if (!Assets.exists(path))
			return false;

		try
		{
			var raw:String = Assets.getText(path);
			var parsed:Dynamic = Json.parse(raw);
			for (key in Reflect.fields(parsed))
				scoreLang.set(key, Reflect.field(parsed, key));
			loaded = scoreLang.keys().hasNext();
			return loaded;
		}
		catch (e:Dynamic)
		{
			trace('ScoreLanguage load error (' + lang + '): ' + e);
			return false;
		}
	}

	public static function get(key:String):String
	{
		// 优先级：scoretxt 专属文件 > 主语言 JSON（模组兼容）> 内嵌英文默认值
		if (scoreLang.exists(key))
			return scoreLang.get(key);
		var fromMain:String = Language.get(key);
		if (fromMain != null && fromMain != key)
			return fromMain;
		if (DEFAULTS.exists(key))
			return DEFAULTS.get(key);
		return key;
	}

	// 获取分数文字字体（位于 assets/fonts/scoretxt/ 下）
	public static function getScoreFont():String
	{
		var font:String = get('score_font');
		if (font == null || font.length == 0)
			font = 'scoretxt/fusion-pixel-10px-monospaced-latin.ttf';
		return font;
	}

	// 将 ratingFC 原始 token（如 "PFC" / "FC" / "?"）翻译为当前分数语言文本。
	// 缺失时回退到原始 token 本身（即英文/原逻辑），保证兼容性。
	public static function getRatingFC(token:String):String
	{
		if (token == null) return '';
		var key:String = 'ratingfc_' + token.toLowerCase();
		if (scoreLang.exists(key))
			return scoreLang.get(key);
		return token;
	}
}
