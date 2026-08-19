package backend;

import openfl.utils.Assets;
import haxe.Json;

/**
 * Week Editor 专属本地化包（含 WeekEditorState 与 WeekEditorFreeplayState）。
 * 文本存放于 assets/languages/editors/week_editor/{语言代码}.json。
 * 在 Language.load() 加载主语言文件后会调用 mergeInto() 将其合并进全局语言表。
 */
class WeekEditorLanguage
{
	public static function mergeInto(target:Map<String, String>, lang:String):Void
	{
		if (tryMerge(target, 'assets/languages/editors/week_editor/$lang.json'))
			return;
		if (lang != 'en_us')
			tryMerge(target, 'assets/languages/editors/week_editor/en_us.json');
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
			trace('WeekEditorLanguage merge error (' + path + '): ' + e);
			return false;
		}
	}
}