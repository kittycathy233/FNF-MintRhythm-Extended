package objects;

import backend.animation.PsychAnimationController;
import backend.NoteTypesConfig;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;
import shaders.ColorSwap;

import objects.StrumNote;

import flixel.math.FlxRect;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String,
	value3:String,
	value4:String
}

/**
 * 预加载音符数据 - 完整保存音符初始化所需的所有信息
 */
typedef PreloadedChartNote = {
	var strumTime:Float;
	var noteData:Int;
	var mustPress:Bool;
	var noteType:String;
	var animSuffix:String;
	var gfNote:Bool;
	var isSustainNote:Bool;
	var sustainLength:Float;
	var parentIndex:Int; // 父音符在预加载数组中的索引
	var previousNoteIndex:Int; // 前一个音符在预加载数组中的索引
	var posOffsetX:Float;
	var posOffsetY:Float;
	var correctionOffset:Float;
	var curStepCrochet:Float;
	var needsOldNoteScaleAdjust:Bool; // 是否需要调整前一个音符的 scale
	var isPixelStage:Bool;
	var hasDownScrollCorrection:Bool;
}

typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool, //breaks r/g/b but makes it copy default colors for your custom note
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

/**
 * The note object used as a data structure to spawn and manage notes during gameplay.
 * 
 * If you want to make a custom note type, you should search for: "function set_noteType"
**/
class Note extends FlxSprite
{
	//This is needed for the hardcoded note types to appear on the Chart Editor,
	//It's also used for backwards compatibility with 0.1 - 0.3.2 charts.
	public static final defaultNoteTypes:Array<String> = [
		'', //Always leave this one empty pls
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation'
	];

	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var strumTime:Float = 0;
	public var noteData:Int = 0;

	public var mustPress:Bool = false;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;

	public var wasGoodHit:Bool = false;
	public var missed:Bool = false;

	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	public var rgbShader:RGBShaderReference;
	public static var globalRgbShaders:Array<RGBPalette> = [];
	public var colorSwap:ColorSwap;
	public static var globalColorSwapShaders:Array<ColorSwap> = [];
	public var inEditor:Bool = false;

	public var animSuffix:String = '';
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 1;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;

	public static var SUSTAIN_SIZE:Int = 44;
	public static var swagWidth:Float = 160 * 0.7;
	public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var defaultNoteSkin(default, never):String = 'noteSkins/NOTE_assets';

	public var noteSplashData:NoteSplashData = {
		disabled: false,
		texture: null,
		antialiasing: !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader: (PlayState.SONG != null) ? !(PlayState.SONG.disableNoteRGB == true) : true,
		r: -1,
		g: -1,
		b: -1,
		a: ClientPrefs.data.splashAlpha
	};

	// Legacy HSV splash colors (mirror old Psych 0.6.3). Carried to NoteSplash in HSV mode.
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.02;
	public var missHealth:Float = 0.1;
	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; //plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;
	public var hitsoundChartEditor:Bool = true;
	/**
	 * Forces the hitsound to be played even if the user's hitsound volume is set to 0
	**/
	public var hitsoundForce:Bool = false;
	public var hitsoundVolume(get, default):Float = 1.0;
	function get_hitsoundVolume():Float {
		if(ClientPrefs.data.hitsoundVolume > 0)
			return ClientPrefs.data.hitsoundVolume;
		return hitsoundForce ? hitsoundVolume : 0.0;
	}
	public var hitsound:String = 'hitsound';

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		//trace('fuck cock');
		return value;
	}

	public function resizeByRatio(ratio:Float) //haha funny twitter shit
	{
		if(isSustainNote && animation.curAnim != null && !animation.curAnim.name.endsWith('end'))
		{
			scale.y *= ratio;
			updateHitbox();
		}
	}

	private function set_texture(value:String):String {
		if(texture != value) reloadNote(value);

		texture = value;
		return value;
	}

	public function defaultRGB()
	{
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData];
		if(PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[noteData];

		if (arr != null && noteData > -1 && noteData <= arr.length)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
		else
		{
			rgbShader.r = 0xFFFF0000;
			rgbShader.g = 0xFF00FF00;
			rgbShader.b = 0xFF0000FF;
		}
	}

	/**
	 * Legacy HSV path: applies the arrow's hue/saturation/brightness shift from
	 * ClientPrefs.data.arrowHSV, and mirrors the values onto noteSplashHue/Sat/Brt
	 * so NoteSplash can pick them up in HSV mode. (Mirror of old Psych 0.6.3.)
	**/
	public function defaultHSV()
	{
		if (colorSwap == null) return;
		if (noteData > -1 && noteData < ClientPrefs.data.arrowHSV.length)
		{
			var arr:Array<Int> = ClientPrefs.data.arrowHSV[noteData];
			colorSwap.hue = arr[0] / 360;
			colorSwap.saturation = arr[1] / 100;
			colorSwap.brightness = arr[2] / 100;
		}
		else
		{
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		}
		noteSplashHue = colorSwap.hue;
		noteSplashSat = colorSwap.saturation;
		noteSplashBrt = colorSwap.brightness;
	}

	private function set_noteType(value:String):String {
		noteSplashData.texture = PlayState.SONG != null ? PlayState.SONG.splashSkin : 'noteSplashes/noteSplashes';
		if(ClientPrefs.data.arrowColorMode == 'HSV') defaultHSV();
		else defaultRGB();

		if(noteData > -1 && noteType != value) {
			switch(value) {
			case 'Hurt Note':
				ignoreNote = mustPress;

				if(ClientPrefs.data.arrowColorMode == 'HSV') {
					// Legacy HSV: override this note with a LOCAL ColorSwap (hue/sat/brt = 0)
					// so it renders UNSHIFTED (the danger texture's own warning colors),
					// without polluting the shared global shader.
					colorSwap = new ColorSwap();
					colorSwap.hue = 0;
					colorSwap.saturation = 0;
					colorSwap.brightness = 0;
					shader = colorSwap.shader;
					noteSplashHue = 0;
					noteSplashSat = 0;
					noteSplashBrt = 0;

					// 恢复专属危险箭头外观（仅非像素舞台，像素舞台没有对应的 pixelUI 危险贴图）：
					// 重新加载 noteSkins/hsv/HURTNOTE_assets（模组覆盖优先于原版，resolveSkinPath 已处理）。
					// 着色器仍是上面的本地 ColorSwap，去色后原样显示该危险贴图自带的警示配色。
					// 若某模组经 custom_notetypes 给 Hurt Note 指定了其它 texture，下方 applyNoteTypeData 会再次覆盖。
					if (!PlayState.isPixelStage)
						reloadNote('noteSkins/HURTNOTE_assets');
				} else {
						// note colors
						rgbShader.r = 0xFF101010;
						rgbShader.g = 0xFFFF0000;
						rgbShader.b = 0xFF990022;

						// splash data and colors
						noteSplashData.r = 0xFFFF0000;
						noteSplashData.g = 0xFF101010;
					}
					noteSplashData.texture = 'noteSplashes/noteSplashes-electric';

					// gameplay data
					lowPriority = true;
					missHealth = isSustainNote ? 0.25 : 0.1;
					hitCausesMiss = true;
					hitsound = 'cancelMenu';
					hitsoundChartEditor = false;
				case 'Alt Animation':
					animSuffix = '-alt';
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
			}
			if (value != null && value.length > 1) NoteTypesConfig.applyNoteTypeData(this, value);
			if (hitsound != 'hitsound' && hitsoundVolume > 0) Paths.sound(hitsound); //precache new sound for being idiot-proof
			noteType = value;
		}
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?createdFrom:Dynamic = null)
	{
		super();

		animation = new PsychAnimationController(this);

		antialiasing = ClientPrefs.data.antialiasing;
		if(createdFrom == null) createdFrom = PlayState.instance;

		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.moves = false;

		x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.data.noteOffset;

		this.noteData = noteData;

		if(noteData > -1)
		{
			// RGB shader is always initialized (shared globals are referenced by NoteSplash /
			// VisualsSettings previews even in HSV mode). Only the sprite's active shader differs.
			rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData));
			var rgbDisabled:Bool = (PlayState.SONG != null && PlayState.SONG.disableNoteRGB);
			if(rgbDisabled) rgbShader.enabled = false;
			texture = '';

			// Legacy HSV path: override the sprite's shader with the shared ColorSwap shader.
			if(ClientPrefs.data.arrowColorMode == 'HSV') {
				colorSwap = Note.initializeGlobalColorSwapShader(noteData);
				shader = rgbDisabled ? null : colorSwap.shader;
			}

			x += swagWidth * (noteData);
			if(!isSustainNote && noteData < colArray.length) { //Doing this 'if' check to fix the warnings on Senpai songs
				var animToPlay:String = '';
				animToPlay = colArray[noteData % colArray.length];
				animation.play(animToPlay + 'Scroll');
			}
		}

		// trace(prevNote);

		if(prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			if(ClientPrefs.data.downScroll) flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			animation.play(colArray[noteData % colArray.length] + 'holdend');

			updateHitbox();

			offsetX -= width / 2;

			if (PlayState.isPixelStage)
				offsetX += 30;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.noteData % colArray.length] + 'hold');

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if(createdFrom != null && createdFrom.songSpeed != null) prevNote.scale.y *= createdFrom.songSpeed;

				if(PlayState.isPixelStage) {
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height); //Auto adjust note size
				}
				prevNote.updateHitbox();
				// prevNote.setGraphicSize();
			}

			if(PlayState.isPixelStage)
			{
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
			earlyHitMult = 0;
		}
		else if(!isSustainNote)
		{
			centerOffsets();
			centerOrigin();
		}
		x += offsetX;
	}

	public static function initializeGlobalRGBShader(noteData:Int)
	{
		if(globalRgbShaders[noteData] == null)
		{
			var newRGB:RGBPalette = new RGBPalette();
			var arr:Array<FlxColor> = (!PlayState.isPixelStage) ? ClientPrefs.data.arrowRGB[noteData] : ClientPrefs.data.arrowRGBPixel[noteData];
			
			if (arr != null && noteData > -1 && noteData <= arr.length)
			{
				newRGB.r = arr[0];
				newRGB.g = arr[1];
				newRGB.b = arr[2];
			}
			else
			{
				newRGB.r = 0xFFFF0000;
				newRGB.g = 0xFF00FF00;
				newRGB.b = 0xFF0000FF;
			}
			
			globalRgbShaders[noteData] = newRGB;
		}
		return globalRgbShaders[noteData];
	}

	/**
	 * Legacy HSV path: creates/caches a shared ColorSwap shader per note direction,
	 * seeded from ClientPrefs.data.arrowHSV. Mirrors initializeGlobalRGBShader so
	 * the legacy NotesColorSubState can edit these globals and see live updates.
	**/
	public static function initializeGlobalColorSwapShader(noteData:Int):ColorSwap
	{
		if(noteData < 0 || noteData >= colArray.length) return new ColorSwap();
		if(globalColorSwapShaders[noteData] == null)
		{
			var cs:ColorSwap = new ColorSwap();
			if (noteData > -1 && noteData < ClientPrefs.data.arrowHSV.length)
			{
				var arr:Array<Int> = ClientPrefs.data.arrowHSV[noteData];
				cs.hue = arr[0] / 360;
				cs.saturation = arr[1] / 100;
				cs.brightness = arr[2] / 100;
			}
			globalColorSwapShaders[noteData] = cs;
		}
		return globalColorSwapShaders[noteData];
	}

	var _lastNoteOffX:Float = 0;
	static var _lastValidChecked:String; //optimization
	static var _skinPathCache:Map<String, String> = new Map();
	public var originalHeight:Float = 6;
	public var correctionOffset:Float = 0; //dont mess with this
	public function reloadNote(texture:String = '', postfix:String = '') {
		if(texture == null) texture = '';
		if(postfix == null) postfix = '';

		var skin:String = texture + postfix;
		if(texture.length < 1)
		{
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if(skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}
		else rgbShader.enabled = false;

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var skinPixel:String = skin;
		var lastScaleY:Float = scale.y;
		var skinPostfix:String = getNoteSkinPostfix();
		var customSkin:String = skin + skinPostfix;
		var path:String = PlayState.isPixelStage ? 'pixelUI/' : '';

		var customExists:Bool = false;
		if(PlayState.isPixelStage)
		{
			customExists = customSkin == _lastValidChecked || Paths.fileExists('images/' + path + customSkin + '.png', IMAGE);
		}
		else
		{
			if(customSkin == _lastValidChecked)
				customExists = true;
			else if(ClientPrefs.data.arrowColorMode == 'HSV')
			{
				var parts:Array<String> = customSkin.split('/');
				var filename:String = parts.pop();
				var folder:String = parts.join('/');
				customExists = Paths.fileExists('images/$folder/hsv/$filename.png', IMAGE) || Paths.fileExists('images/$customSkin.png', IMAGE);
			}
			else
			{
				customExists = Paths.fileExists('images/$customSkin.png', IMAGE);
			}
		}

		if(customExists)
		{
			skin = customSkin;
			_lastValidChecked = customSkin;
		}
		else skinPostfix = '';

		if(PlayState.isPixelStage) {
			// HSV 模式：优先加载 pixelUI/<folder>/hsv/<file> 的白色像素箭头（供 ColorSwap
			// 着色），保持 <base>ENDS<postfix> 的像素文件名格式；不存在则回退彩色像素贴图。
			var pixelSkin:String = skinPixel;
			if(ClientPrefs.data.arrowColorMode == 'HSV') {
				var parts:Array<String> = skinPixel.split('/');
				var filename:String = parts.pop();
				var folder:String = parts.join('/');
				var hsvSkin:String = (folder.length > 0 ? folder + '/' : '') + 'hsv/' + filename;
				var testPath:String = 'images/pixelUI/' + hsvSkin + (isSustainNote ? 'ENDS' : '') + skinPostfix + '.png';
				if(Paths.fileExists(testPath, IMAGE)) pixelSkin = hsvSkin;
			}
			if(isSustainNote) {
				var graphic = Paths.image('pixelUI/' + pixelSkin + 'ENDS' + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 2));
				originalHeight = graphic.height / 2;
			} else {
				var graphic = Paths.image('pixelUI/' + pixelSkin + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 5));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			loadPixelNoteAnims();
			antialiasing = false;

			if(isSustainNote) {
				offsetX += _lastNoteOffX;
				_lastNoteOffX = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX -= _lastNoteOffX;
			}
		} else {
			frames = Paths.getSparrowAtlas(getNoteSkinPath(skin));
			loadNoteAnims();
			if(!isSustainNote)
			{
				centerOffsets();
				centerOrigin();
			}
		}

		if(isSustainNote) {
			scale.y = lastScaleY;
		}
		updateHitbox();

		if(animName != null)
			animation.play(animName, true);
	}

	public static function getNoteSkinPostfix()
	{
		var skin:String = '';
		var skinName:String = ClientPrefs.data.noteSkin.trim();
		if(skinName != ClientPrefs.defaultData.noteSkin)
			skin = '-' + skinName.toLowerCase().replace(' ', '_');
		return skin;
	}

	/**
	 * 统一解析皮肤路径，沿用「模组优先于原版、HSV 目录优先于默认目录」的优先级：
	 *   1) 模组 hsv 目录  mods/(currentMod)/images/<folder>/hsv/<file>
	 *   2) 模组默认目录  mods/(currentMod)/images/<folder>/<file>
	 *   3) 原版 hsv 目录  images/<folder>/hsv/<file>
	 *   4) 原版默认目录  images/<folder>/<file>
	 * 非 HSV 模式直接返回 basePath，真正加载时 Paths.getSparrowAtlas 自身已优先模组再回退原版。
	 * 这样可保证 StrumNote / 流动音符 / 飞溅在游玩（含模组）时使用完全一致的一套资源，
	 * 且不会在模组只提供白底默认箭头时错误回退到原版的 hsv 箭头。
	**/
	public static function resolveSkinPath(basePath:String, ?isSplash:Bool = false):String
	{
		if (basePath == null || basePath.length < 1) basePath = defaultNoteSkin;

		// 飞溅贴图是共享资源（不分像素/非像素，像素感由 PixelSplashShader 运行时做出），
		// 其 hsv 白色变体始终位于 images/<folder>/hsv/，绝不在 pixelUI/ 下，故飞溅
		// 在像素舞台也不应套用 pixelUI/ 前缀。
		var pixelPrefixEnabled:Bool = !isSplash && PlayState.isPixelStage;

		// cache key 必须包含 arrowColorMode 与是否像素舞台：否则 RGB/HSV 或
		// 像素/非像素缓存的基底路径会相互命中，导致永远解析不到正确的 hsv/ 纹理。
		var cacheKey:String = (Mods.currentModDirectory != null ? Mods.currentModDirectory : '')
			+ ':' + ClientPrefs.data.arrowColorMode + ':'
			+ (pixelPrefixEnabled ? 'pixel:' : '') + basePath;
		if (_skinPathCache.exists(cacheKey)) return _skinPathCache.get(cacheKey);

		var result:String = basePath;
		if (ClientPrefs.data.arrowColorMode == 'HSV')
		{
			var parts:Array<String> = basePath.split('/');
			var filename:String = parts.pop();
			var folder:String = parts.join('/');
			// 像素舞台的箭头资源位于 pixelUI/ 目录下，故 hsv 白色变体也要在那里查找；
			// 非像素舞台（或飞溅）则维持原 images/<folder>/hsv/<file> 逻辑。返回的
			// path 不含 pixelUI/ 前缀，由 StrumNote/Note 的像素分支自行拼接 pixelUI/。
			var pixelPrefix:String = pixelPrefixEnabled ? 'pixelUI/' : '';
			var hsvRel:String = 'images/$pixelPrefix$folder/hsv/$filename.png';
			var baseRel:String = 'images/$pixelPrefix$basePath.png';

			if (skinFileExists(hsvRel, true))       result = '$folder/hsv/$filename'; // 1) 模组 hsv
			else if (skinFileExists(baseRel, true)) result = basePath;                // 2) 模组默认
			else if (skinFileExists(hsvRel, false)) result = '$folder/hsv/$filename'; // 3) 原版 hsv
		}
		_skinPathCache.set(cacheKey, result);
		return result;
	}

	// modsOnly=true：仅检测当前模组 + 全局模组；false：还会回退检测原版（忽略模组）
	static function skinFileExists(relPath:String, modsOnly:Bool):Bool
	{
		#if MODS_ALLOWED
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0
			&& FileSystem.exists(Paths.mods(Mods.currentModDirectory + '/' + relPath))) return true;
		for (mod in Mods.getGlobalMods())
			if (FileSystem.exists(Paths.mods(mod + '/' + relPath))) return true;
		#end
		if (modsOnly) return false;
		return Paths.fileExists(relPath, IMAGE, true); // ignoreMods=true → 仅原版
	}

	public static function getNoteSkinPath(basePath:String):String
	{
		return resolveSkinPath(basePath);
	}

	function loadNoteAnims() {
		if (colArray[noteData] == null)
			return;

		if (isSustainNote)
		{
			attemptToAddAnimationByPrefix('purpleholdend', 'pruple end hold', 24, true); // this fixes some retarded typo from the original note .FLA
			animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end', 24, true);
			animation.addByPrefix(colArray[noteData] + 'hold', colArray[noteData] + ' hold piece', 24, true);
		}
		else animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0');

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if (colArray[noteData] == null)
			return;

		if(isSustainNote)
		{
			animation.add(colArray[noteData] + 'holdend', [noteData + 4], 24, true);
			animation.add(colArray[noteData] + 'hold', [noteData], 24, true);
		} else animation.add(colArray[noteData] + 'Scroll', [noteData + 4], 24, true);
	}

	function attemptToAddAnimationByPrefix(name:String, prefix:String, framerate:Float = 24, doLoop:Bool = true)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, prefix); // adds valid frames to animFrames
		if(animFrames.length < 1) return;

		animation.addByPrefix(name, prefix, framerate, doLoop);
	}

	override function update(elapsed:Float) 
	{
		super.update(elapsed);

		var earlyWindow:Float = Conductor.safeZoneOffset * earlyHitMult;
		var lateWindow:Float = Conductor.safeZoneOffset * lateHitMult;
		var timeUntilHit:Float = (strumTime - Conductor.songPosition);

		if (mustPress)
		{
			canBeHit = (timeUntilHit > -lateWindow && timeUntilHit < earlyWindow);

			if (strumTime < Conductor.songPosition - lateWindow && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = (timeUntilHit > -lateWindow && timeUntilHit < earlyWindow);

			if (!wasGoodHit && strumTime <= Conductor.songPosition)
			{
				if(!isSustainNote || (prevNote.wasGoodHit && !ignoreNote))
					wasGoodHit = true;
			}

			if (strumTime < Conductor.songPosition - lateWindow && !wasGoodHit)
				tooLate = true;
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	override public function destroy()
	{
		super.destroy();
		_lastValidChecked = '';
	}

	public function followStrumNote(myStrum:StrumNote, fakeCrochet:Float, songSpeed:Float = 1)
	{
		var strumX:Float = myStrum.x;
		var strumY:Float = myStrum.y;
		var strumAngle:Float = myStrum.angle;
		var strumAlpha:Float = myStrum.alpha;
		var strumDirection:Float = myStrum.direction;

		distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
		if (!myStrum.downScroll) distance *= -1;

		var angleDir = strumDirection * Math.PI / 180;
		if (copyAngle)
			angle = strumDirection - 90 + strumAngle + offsetAngle;

		if(copyAlpha)
			alpha = strumAlpha * multAlpha;

		if(copyX)
			x = strumX + offsetX + Math.cos(angleDir) * distance;

		if(copyY)
		{
			y = strumY + offsetY + correctionOffset + Math.sin(angleDir) * distance;
			if(myStrum.downScroll && isSustainNote)
			{
				if(PlayState.isPixelStage)
				{
					y -= PlayState.daPixelZoom * 9.5;
				}
				y -= (frameHeight * scale.y) - (Note.swagWidth / 2);
			}
		}
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		var center:Float = myStrum.y + offsetY + Note.swagWidth / 2;
		if((mustPress || !ignoreNote) && (wasGoodHit || (prevNote.wasGoodHit && !canBeHit)))
		{
			var swagRect:FlxRect = clipRect;
			if(swagRect == null) swagRect = new FlxRect(0, 0, frameWidth, frameHeight);

			if (myStrum.downScroll)
			{
				if(y - offset.y * scale.y + height >= center)
				{
					swagRect.width = frameWidth;
					swagRect.height = (center - y) / scale.y;
					swagRect.y = frameHeight - swagRect.height;
				}
			}
			else if (y + offset.y * scale.y <= center)
			{
				swagRect.y = (center - y) / scale.y;
				swagRect.width = width / scale.x;
				swagRect.height = (height / scale.y) - swagRect.y;
			}
			clipRect = swagRect;
		}
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect {
		clipRect = rect;

		if (frames != null)
			frame = frames.frames[animation.frameIndex];

		return rect;
	}
}
