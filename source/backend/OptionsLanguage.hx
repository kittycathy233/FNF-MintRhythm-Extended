package backend;

import openfl.utils.Assets;
import haxe.Json;

/**
 * 设置界面（Options）专属本地化包。
 *
 * 文本与字体/配置映射存放于 assets/languages/options/{语言代码}.json。
 * 在 Language.load() 加载主语言文件后会调用 mergeInto() 将其合并进全局语言表，
 * 因此绝大多数选项文本仍可直接通过 Language.get(...) 读取；
 * 而对于带有默认值回退的需求说明 / 备注（requirement / note 类键），
 * 则使用本类的 get(key, default) 以获取与 LanguageBasic.getPhrase 一致的回退行为。
 *
 * 目标语言由 ClientPrefs.data.language 决定；对应文件缺失时回退到 en_us。
 */
class OptionsLanguage
{
	// 将设置界面语言包合并进传入的目标表（通常是 Language 的全局表）。
	public static function mergeInto(target:Map<String, String>, lang:String):Void
	{
		if (tryMerge(target, 'assets/languages/options/$lang.json'))
			return;
		if (lang != 'en_us')
			tryMerge(target, 'assets/languages/options/en_us.json');
	}

	// 读取设置界面文本，并支持默认值回退（与 LanguageBasic.getPhrase 行为一致）。
	public static function get(key:String, ?defaultValue:String):String
	{
		var val:String = Language.get(key);
		if (val != null && val != key)
			return val;
		if (defaultValue != null)
			return defaultValue;
		return key;
	}

	private static function tryMerge(target:Map<String, String>, path:String):Bool
	{
		if (!Assets.exists(path))
			return false;

		try
		{
			var parsed:Dynamic = Json.parse(Assets.getText(path));
			for (key in Reflect.fields(parsed))
				target.set(key, Reflect.field(parsed, key));
			return true;
		}
		catch (e:Dynamic)
		{
			trace('OptionsLanguage merge error (' + path + '): ' + e);
			return false;
		}
	}
}
