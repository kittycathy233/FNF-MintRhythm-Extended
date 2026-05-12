package backend;

// Language.hx
import openfl.utils.Assets;
import haxe.Json;

class Language {
    private static var currentLang:Map<String, String> = new Map();
    private static var fallbackLang:String = ClientPrefs.data.language;
    
    // 添加语言变更回调
    private static var onLanguageChangedCallbacks:Array<Void->Void> = [];
    
    public static function addCallback(callback:Void->Void) {
        if (!onLanguageChangedCallbacks.contains(callback))
            onLanguageChangedCallbacks.push(callback);
    }
    
    public static function removeCallback(callback:Void->Void) {
        onLanguageChangedCallbacks.remove(callback);
    }

    public static function load() {
        var lang = ClientPrefs.data.language;
        if(lang == null) lang = fallbackLang; // 额外保障
        
        currentLang.clear();
        if(!loadLanguage(lang) && lang != fallbackLang) {
            loadLanguage(fallbackLang);
        }
        
        // 通知所有监听者语言已更改
        for (callback in onLanguageChangedCallbacks) {
            callback();
        }
    }
    
    private static function loadLanguage(lang:String):Bool {
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
                value = StringTools.replace(value, '{$i}', params[i]);
            }
        }
        return value;
    }
    
    // 获取游戏字体文件
    public static function getGameFont():String {
        return currentLang.get("game_font");
    }
}