package backend;

// Language.hx
import openfl.utils.Assets;
import haxe.Json;

class Language {
    static var currentLang:Map<String, String> = new Map();
    static var fallbackLang:String = ClientPrefs.data.language; // 默认回退语言

    public static function load() {
        var lang = ClientPrefs.data.language;
        if(lang == null) lang = fallbackLang; // 额外保障
        
        currentLang.clear();
        if(!loadLanguage(lang) && lang != fallbackLang) {
            loadLanguage(fallbackLang);
        }
    }
    
    static function loadLanguage(lang:String):Bool {
        try {
            var rawJson = Assets.getText('assets/languages/$lang.json');
            if(rawJson == null) return false;

            var parsedData:Dynamic = Json.parse(rawJson);
            for (key in Reflect.fields(parsedData)) {
                currentLang.set(key, Reflect.field(parsedData, key));
            }
            return true;
        } catch(e) {
            trace("Language load error: " + e.message);
            return false;
        }
    }

    public static function get(key:String, ?params:Array<String>):String {
        var value = currentLang.exists(key) ? currentLang.get(key) : key; // 如果键不存在，返回键本身
        if (params != null) {
            for (i in 0...params.length) {
                value = StringTools.replace(value, '$${i+1}', params[i]);
            }
        }
        return value;
    }
}