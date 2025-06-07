package backend;

import openfl.utils.Assets;
import lime.utils.Assets as LimeAssets;
import backend.ExtraKeysHandler.EKNoteColor;

#if cpp
@:cppFileCode('#include <thread>')
#end
class CoolUtil
{
	private static var cachedTips:String = null;
	
	public static function checkForUpdates(url:String = null):String {
		if (url == null || url.length == 0)
			url = "https://raw.gitmirror.com/kittycathy233/FNF-MintRhythm-Extended/main/gitVersion.txt";
		var version:String = states.MainMenuState.mrExtendVersion.trim();
		if(ClientPrefs.data.checkForUpdates) {
			trace('checking for updates...');
			var http = new haxe.Http(url);
			http.onData = function (data:String)
			{
				var newVersion:String = data.split('\n')[0].trim();
				trace('version online: $newVersion, your version: $version');
				if(newVersion != version) {
					trace('versions arent matching! please update');
					version = newVersion;
					http.onData = null;
					http.onError = null;
					http = null;
				}
			}
			http.onError = function (error) {
				trace('error: $error');
			}
			http.request();
		}
		return version;
	}

	public static function tipsShow(url:String = null, forceReload:Bool = false):String {
		if (!forceReload && cachedTips != null)
			return cachedTips;
			
		if (url == null || url.length == 0)
			url = "https://raw.gitmirror.com/kittycathy233/FNF-MintRhythm-Things/main/engine/menu/tips/zh_cn.txt";
		
		var tipContent:String = "";
		trace('searching for tips...');
		var http = new haxe.Http(url);
		http.onData = function (data:String)
		{
			tipContent = data.trim();
			cachedTips = tipContent; // 缓存结果
			http.onData = null;
			http.onError = null;
			http = null;
		}
		http.onError = function (error) {
			trace('error: $error');
		}
		http.request();
		
		return tipContent;
	}

	inline public static function quantize(f:Float, snap:Float){
		// changed so this actually works lol
		var m:Float = Math.fround(f * snap);
		//trace(snap);
		return (m / snap);
	}

	public static function coolLerp(base:Float, target:Float, ratio:Float):Float
		return base + cameraLerp(ratio) * (target - base);

	public static function cameraLerp(lerp:Float):Float
		return lerp * (FlxG.elapsed / (1 / 60));

	inline public static function capitalize(text:String)
		return text.charAt(0).toUpperCase() + text.substr(1).toLowerCase();

	inline public static function coolTextFile(path:String):Array<String>
	{
		var daList:String = null;
		#if (sys && MODS_ALLOWED)
		if(FileSystem.exists(path)) daList = File.getContent(path);
		#else
		if(Assets.exists(path)) daList = Assets.getText(path);
		#end
		return daList != null ? listFromString(daList) : [];
	}

	inline public static function colorFromString(color:String):FlxColor
	{
		var hideChars = ~/[\t\n\r]/;
		var color:String = hideChars.split(color).join('').trim();
		if(color.startsWith('0x')) color = color.substring(color.length - 6);

		var colorNum:Null<FlxColor> = FlxColor.fromString(color);
		if(colorNum == null) colorNum = FlxColor.fromString('#$color');
		return colorNum != null ? colorNum : FlxColor.WHITE;
	}

	inline public static function listFromString(string:String):Array<String>
	{
		var daList:Array<String> = [];
		daList = string.trim().split('\n');

		for (i in 0...daList.length)
			daList[i] = daList[i].trim();

		return daList;
	}

	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if(decimals < 1)
			return Math.floor(value);

		return Math.floor(value * Math.pow(10, decimals)) / Math.pow(10, decimals);
	}

	#if linux
	public static function sortAlphabetically(list:Array<String>):Array<String> {
		if (list == null) return [];

		list.sort((a, b) -> {
			var upperA = a.toUpperCase();
			var upperB = b.toUpperCase();
			
			return upperA < upperB ? -1 : upperA > upperB ? 1 : 0;
		});
		return list;
	}
	#end

	inline public static function dominantColor(sprite:flixel.FlxSprite):Int
	{
		var countByColor:Map<Int, Int> = [];
		for(col in 0...sprite.frameWidth)
		{
			for(row in 0...sprite.frameHeight)
			{
				var colorOfThisPixel:FlxColor = sprite.pixels.getPixel32(col, row);
				if(colorOfThisPixel.alphaFloat > 0.05)
				{
					colorOfThisPixel = FlxColor.fromRGB(colorOfThisPixel.red, colorOfThisPixel.green, colorOfThisPixel.blue, 255);
					var count:Int = countByColor.exists(colorOfThisPixel) ? countByColor[colorOfThisPixel] : 0;
					countByColor[colorOfThisPixel] = count + 1;
				}
			}
		}

		var maxCount = 0;
		var maxKey:Int = 0; //after the loop this will store the max color
		countByColor[FlxColor.BLACK] = 0;
		for(key => count in countByColor)
		{
			if(count >= maxCount)
			{
				maxCount = count;
				maxKey = key;
			}
		}
		countByColor = [];
		return maxKey;
	}

	inline public static function numberArray(max:Int, ?min = 0):Array<Int>
	{
		var dumbArray:Array<Int> = [];
		for (i in min...max) dumbArray.push(i);

		return dumbArray;
	}

	inline public static function browserLoad(site:String) {
		#if linux
		Sys.command('/usr/bin/xdg-open', [site]);
		#else
		FlxG.openURL(site);
		#end
	}

	inline public static function openFolder(folder:String, absolute:Bool = false) {
		#if sys
			if(!absolute) folder =  Sys.getCwd() + '$folder';

			folder = folder.replace('/', '\\');
			if(folder.endsWith('/')) folder.substr(0, folder.length - 1);

			#if linux
			var command:String = '/usr/bin/xdg-open';
			#else
			var command:String = 'explorer.exe';
			#end
			Sys.command(command, [folder]);
			trace('$command $folder');
		#else
			FlxG.error("Platform is not supported for CoolUtil.openFolder");
		#end
	}

	/**
		Helper Function to Fix Save Files for Flixel 5

		-- EDIT: [November 29, 2023] --

		this function is used to get the save path, period.
		since newer flixel versions are being enforced anyways.
		@crowplexus
	**/
	@:access(flixel.util.FlxSave.validate)
	inline public static function getSavePath():String {
		final company:String = FlxG.stage.application.meta.get('company');
		// #if (flixel < "5.0.0") return company; #else
		return '${company}/${flixel.util.FlxSave.validate(FlxG.stage.application.meta.get('file'))}';
		// #end
	}

	public static function setTextBorderFromString(text:FlxText, border:String)
	{
		switch(border.toLowerCase().trim())
		{
			case 'shadow':
				text.borderStyle = SHADOW;
			case 'outline':
				text.borderStyle = OUTLINE;
			case 'outline_fast', 'outlinefast':
				text.borderStyle = OUTLINE_FAST;
			default:
				text.borderStyle = NONE;
		}
	}
public static function getArrowRGB(path:String = 'arrowRGB.json', defaultArrowRGB:Array<EKNoteColor>):ArrowRGBSavedData {
		var result:ArrowRGBSavedData;
		var content:String = '';
		#if sys
		if(FileSystem.exists(path)) content = File.getContent(path);
		else {
			// create a default ArrowRGBSavedData
			var colorsToUse = [];
			for (color in defaultArrowRGB) {
				colorsToUse.push(color);
			}

			var defaultSaveARGB:ArrowRGBSavedData = new ArrowRGBSavedData(colorsToUse);

			// write it
			var writer = new json2object.JsonWriter<ArrowRGBSavedData>();
			content = writer.write(defaultSaveARGB, '    ');
			File.saveContent(path, content);

			trace(path + ' (Color save) didn\'t exist. Written.');
		}
		#else
		if(Assets.exists(path)) content = Assets.getText(path);
		#end

		var parser = new json2object.JsonParser<ArrowRGBSavedData>();
		parser.fromJson(content);
		result = parser.value;

		// automatically (?) sets colors of notes that have no colors
		for (i in 0...ExtraKeysHandler.instance.data.maxKeys+1) {
			// colors dont exist
			
			// cannot take the previous approach since 
			// this is indexed and not per mania
			if (result.colors[i] == null) {
				result.colors[i] = defaultArrowRGB[i];
			}
		}

		return result;
	}

	public static function getKeybinds(path:String = 'ekkeybinds.json', defaultKeybinds:Array<Array<Array<Int>>>):EKKeybindSavedData {
		var result:EKKeybindSavedData;
		var content:String = '';
		#if sys
		if(FileSystem.exists(path)) {
			content = File.getContent(path);
			//trace('Keybind file $path $content');
		} 
		else {
			var defaultKeybindSave:EKKeybindSavedData = new EKKeybindSavedData(defaultKeybinds);
			// write it
			var writer = new json2object.JsonWriter<EKKeybindSavedData>();
			content = writer.write(defaultKeybindSave, '  ');
			File.saveContent(path, content);
			trace(path + ' (Keybind save) didn\'t exist. Written.');
		}
		#else
		if(Assets.exists(path)) content = Assets.getText(path);
		#end

		var parser = new json2object.JsonParser<EKKeybindSavedData>();
		parser.fromJson(content);
		result = parser.value;

		// automatically (?) sets keybinds of #keys that have no keybinds
		for (i in 0...ExtraKeysHandler.instance.data.maxKeys+1) {
			// keybinds dont exist, keybinds are not enough
			if (result.keybinds[i] == null || result.keybinds[i].length != (i + 1)) {
				result.keybinds[i] = defaultKeybinds[i];
			}
		}

		return result;
	}

	public static function showPopUp(message:String, title:String):Void
	{
		/*#if android
		AndroidTools.showAlertDialog(title, message, {name: "OK", func: null}, null);
		#else*/
		FlxG.stage.window.alert(message, title);
		//#end
	}

	#if cpp
    @:functionCode('
        return std::thread::hardware_concurrency();
    ')
	#end
    public static function getCPUThreadsCount():Int
    {
        return 1;
    }
}

class ArrowRGBSavedData {
	public var colors:Array<EKNoteColor>;

	public function new(colors){
		this.colors = colors;
	}
}

class EKKeybindSavedData {
	public var keybinds:Array<Array<Array<Int>>>;

	public function new(keybinds){
		this.keybinds = keybinds;
	}
}