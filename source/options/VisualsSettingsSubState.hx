package options;

import objects.Note;
import objects.StrumNote;
import objects.NoteSplash;
import objects.Alphabet;

class VisualsSettingsSubState extends BaseOptionsMenu
{
	var noteOptionID:Int = -1;
	var notes:FlxTypedGroup<StrumNote>;
	var splashes:FlxTypedGroup<NoteSplash>;
	var noteY:Float = 90;

	// 可选样式面板（聚焦 noteSkins / noteSplashes 时从右侧飞入）
	var noteSkinList:Array<String> = [];
	var splashSkinList:Array<String> = [];
	var skinPanelBG:FlxSprite;
	var skinPanelLines:Array<FlxText> = [];
	var panelMode:String = null; // 'noteSkin' / 'splashSkin' / null
	var panelHiddenX:Float = 0;
	var panelLineH:Float = 28;
	var panelPadX:Float = 14;
	var panelPadY:Float = 12;
	var panelMargin:Float = 16;
	public function new()
	{
		title = LanguageBasic.getPhrase('visuals_menu', 'Visuals Settings');
		rpcTitle = 'Visuals Settings Menu'; //for Discord Rich Presence

		// for note skins and splash skins
		notes = new FlxTypedGroup<StrumNote>();
		splashes = new FlxTypedGroup<NoteSplash>();
		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);
			
			var splash:NoteSplash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
		}

		// options
		var option:Option = new Option("Arrow Color Mode:",
			Language.get('arrow_colormode_desc'),
			'arrowColorMode',
			STRING,
			['RGB', 'HSV']);
		addOption(option);
		option.onChange = onChangeArrowColorMode;

		var noteSkins:Array<String> = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		if(noteSkins.length > 0)
		{
			if(!noteSkins.contains(ClientPrefs.data.noteSkin))
				ClientPrefs.data.noteSkin = ClientPrefs.defaultData.noteSkin;

			noteSkins.insert(0, ClientPrefs.defaultData.noteSkin);
			noteSkinList = noteSkins;
			var option:Option = new Option("Note Skins:",
				Language.get("noteskin_desc"),
				'noteSkin',
				STRING,
				noteSkins);
			addOption(option);
			option.onChange = onChangeNoteSkin;
			noteOptionID = optionsArray.length - 1;
		}
		
		var noteSplashes:Array<String> = Mods.mergeAllTextsNamed('images/noteSplashes/list.txt');
		if(noteSplashes.length > 0)
		{
			if(!noteSplashes.contains(ClientPrefs.data.splashSkin))
				ClientPrefs.data.splashSkin = ClientPrefs.defaultData.splashSkin;

			noteSplashes.insert(0, ClientPrefs.defaultData.splashSkin);
			splashSkinList = noteSplashes;
			var option:Option = new Option("Note Splashes:",
				Language.get("notesplash_desc"),
				'splashSkin',
				STRING,
				noteSplashes);
			addOption(option);
			option.onChange = onChangeSplashSkin;
		}

		var option:Option = new Option("Note Splash Opacity",
			Language.get("notesplashopacity_desc"),
			'splashAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		option.onChange = playNoteSplashes;

		var option:Option = new Option("Hide HUD",
			Language.get("hidehud_desc"),
			'hideHud',
			BOOL);
		addOption(option);
		
		var option:Option = new Option("Time Bar:",
			Language.get("timebar_desc"),
			'timeBarType',
			STRING,
			['Time Left', 'Time Elapsed', 'Song Name', 'Disabled']);
		addOption(option);

		var option:Option = new Option("Flashing Lights",
			Language.get("flashinglights_desc"),
			'flashing',
			BOOL);
		addOption(option);

		var option:Option = new Option("Camera Zooms",
			Language.get("camerazooms_desc"),
			'camZooms',
			BOOL);
		addOption(option);

		var option:Option = new Option("Score Text Grow on Hit",
			Language.get("scoretextgrow_desc"),
			'scoreZoom',
			BOOL);
		addOption(option);

		var option:Option = new Option("Health Bar Opacity",
			Language.get("healthbaropacity_desc"),
			'healthBarAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);
		
		var option:Option = new Option("FPS Counter",
			Language.get("showfps_desc"),
			'showFPS',
			BOOL);
		addOption(option);
		option.onChange = onChangeFPSCounter;

		var option:Option = new Option("FPS Counter Style:",
			"Choose between Psych (detailed) or Simple (Leather) style",
			'fpsStyle',
			STRING,
			['Psych', 'Simple']);
		addOption(option);
		option.onChange = onChangeFPSStyle;

		var option:Option = new Option("FPS Counter Layer:",
			"Stage (screen-space) or Game (1280x720)",
			'fpsLayer',
			STRING,
			['Stage', 'Game']);
		addOption(option);
		option.onChange = onChangeFPSLayer;
		
		var option:Option = new Option("Psych FPS Settings...",
			'Customize Psych style FPS counter appearance and content',
			'_fpsSettings',
			BUTTON);
		addOption(option);
		option.onChange = function() {
			MusicBeatState.switchState(new FPSCounterSettingsState());
		};
		
		var option:Option = new Option("Simple FPS Settings...",
			'Customize Simple (Leather) style FPS counter appearance and content',
			'_simpleInfoSettings',
			BUTTON);
		addOption(option);
		option.onChange = function() {
			MusicBeatState.switchState(new SimpleInfoDisplaySettingsState());
		};

		//新版lime跟git库的不同，故临时禁用此项，之后也许会改
		/*#if native
		var option:Option = new Option("VSync",
			Language.get("vsync_desc"),
			'vsync',
			BOOL);
		option.onChange = onChangeVSync;
		addOption(option);
		#end*/
		
		var option:Option = new Option("Pause Music:",
			Language.get("pausemusic_desc"),
			'pauseMusic',
			STRING,
			['None', 'Tea Time', 'Breakfast', 'Breakfast (Pico)', "Romantic Smile"]);
		addOption(option);
		option.onChange = onChangePauseMusic;
		
		#if CHECK_FOR_UPDATES
		var option:Option = new Option("Check for Updates",
			Language.get("checkforupdates_desc"),
			'checkForUpdates',
			BOOL);
		addOption(option);
		#end

	#if DISCORD_ALLOWED
	var option:Option = new Option("Discord Rich Presence",
		Language.get("discordrpc_desc"),
		'discordRPC',
		BOOL);
	addOption(option);
	#end

	var option:Option = new Option("Disable Networking",
		"Blocks all internet usage at once: update checks, tip fetches, external links and Discord RPC.",
		'disableNetworking',
		BOOL);
	addOption(option);


		var option:Option = new Option("Combo Stacking",
		Language.get("combostacking_desc"),
		'comboStacking',
		BOOL);
	addOption(option);

	var option:Option = new Option("Single Hold Animation",
		"Only play confirm animation once when holding long notes",
		'singleHoldNoteAnimation',
		BOOL);
	addOption(option);

	var option:Option = new Option("Auto Reset Strum Animation",
		"Automatically reset strum notes to default animation",
		'autoResetStrumAnim',
		BOOL);
	addOption(option);

	var option:Option = new Option("Fallback Perfect to Sick",
		"If mod doesn't have perfect/marvelous rating images, use sick instead",
		'fallbackPerfectToSick',
		BOOL);
	addOption(option);

	var option:Option = new Option("Fallback EX Perfect to Sick",
		"If mod doesn't have perfect/marvelous EX rating images, use sick instead",
		'fallbackEXPerfectToSick',
		BOOL);
	addOption(option);

	var soundTrayOptions:Array<String> = ['Flixel', 'Funkin', 'Kathy', 'Dave'];
	var option:Option = new Option("Sound Tray Style:",
		"Choose the style of the sound tray",
		'soundTrayStyle',
		STRING,
		soundTrayOptions);
	addOption(option);
	
	var option:Option = new Option("Hold Note Behind:",
		"Place hold notes behind normal notes and strum arrows",
		'holdNoteBehind',
		BOOL);
	addOption(option);

	var option:Option = new Option("Legacy Main Menu UI",
		"Use the old Psych Engine v0.7.3 main menu style",
		'legacyMainMenu',
		BOOL);
	addOption(option);

	// Fake OS 伪装设置
	var option:Option = new Option("Fake OS Mode",
		"",
		'fakeOSMode',
		BOOL);
	addOption(option);
	option.onChange = onChangeFakeOSMode;

	var option:Option = new Option("Fake Window Title",
		"",
		'fakeWindowTitlePreset',
		STRING,
		["Kathy Engine", "Friday Night Funkin': MintRhythm Engine", "Friday Night Funkin': OS Engine", "Friday Night Funkin': Psych Engine", "Friday Night Funkin'", "FNF", "WTF in FNF", "Rhythm Game", "Not FNF", "Just a Game"]);
	addOption(option);
	option.onChange = onChangeFakeWindowTitle;

	var option:Option = new Option("Fake OS Version",
		"",
		'fakeOSVersion',
		STRING,
		["1.0.0", "1.0.1", "1.1.0", "1.2.0", "1.3.0", "1.3.1", "1.4.0", "1.4.1", "1.5.0", "1.5.1"]);
	addOption(option);
	option.onChange = onChangeFakeOSMode;

		super();
		add(notes);
		add(splashes);

		// 样式选择面板（半透明黑底 + 右侧飞入）
		skinPanelBG = new FlxSprite();
		skinPanelBG.makeGraphic(1, 1, FlxColor.BLACK);
		skinPanelBG.alpha = 0.5;
		skinPanelBG.scrollFactor.set();
		panelHiddenX = FlxG.width + 80;
		skinPanelBG.x = panelHiddenX;
		skinPanelBG.y = (FlxG.height - skinPanelBG.height) / 2;
		add(skinPanelBG); // 加在文本之下
	}

	var notesShown:Bool = false;
	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		
		var isSkinMode:Bool = (curOption.variable == 'noteSkin' || curOption.variable == 'splashSkin');

		switch(curOption.variable)
		{
			case 'noteSkin', 'splashSkin', 'splashAlpha':
				if(!notesShown)
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: noteY}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = true;
				if(curOption.variable.startsWith('splash') && Math.abs(notes.members[0].y - noteY) < 25) playNoteSplashes();

			default:
				if(notesShown) 
				{
					for (note in notes.members)
					{
						FlxTween.cancelTweensOf(note);
						FlxTween.tween(note, {y: -200}, Math.abs(note.y / (200 + noteY)) / 3, {ease: FlxEase.quadInOut});
					}
				}
				notesShown = false;
		}

		// 样式选择面板：仅在聚焦 noteSkin / splashSkin 时显示
		if (isSkinMode)
		{
			var mode:String = curOption.variable;
			if (panelMode != mode)
			{
				var wasShown:Bool = (panelMode != null);
				panelMode = mode;
				rebuildSkinPanel(mode, !wasShown);
			}
			showSkinPanel();
		}
		else if (panelMode != null)
		{
			hideSkinPanel();
			panelMode = null;
		}
	}

	// ---------- 可选样式面板（HSV 标记 + 右侧飞入）----------

	function getNoteSkinFile(skin:String):String
	{
		var base:String = 'noteSkins/NOTE_assets';
		if (skin != ClientPrefs.defaultData.noteSkin)
			base += '-' + skin.toLowerCase().replace(' ', '_');
		return base;
	}

	function getSplashSkinFile(skin:String):String
	{
		var base:String = 'noteSplashes/noteSplashes';
		if (skin != ClientPrefs.defaultData.splashSkin)
			base += '-' + skin.toLowerCase().replace(' ', '-');
		return base;
	}

	// 检测 hsv 目录是否存在与 rgb 样式同名的文件
	function hasHSVVersion(path:String):Bool
	{
		var parts:Array<String> = path.split('/');
		var filename:String = parts.pop();
		var folder:String = parts.join('/');
		return Paths.fileExists('images/$folder/hsv/$filename.png', IMAGE);
	}

	function getStyleLabel(skin:String, file:String):String
	{
		// 当前为 HSV 渲染且存在 hsv 同名文件时，左侧加入 (HSV) 前缀
		if (ClientPrefs.data.arrowColorMode == 'HSV' && hasHSVVersion(file))
			return '(HSV) ' + skin;
		return skin;
	}

	// 根据当前模式重建面板内容。flyIn=true 时内容先放到屏幕外以便飞入
	function rebuildSkinPanel(mode:String, flyIn:Bool)
	{
		for (line in skinPanelLines)
		{
			remove(line);
			line.destroy();
		}
		skinPanelLines = [];

		var list:Array<String> = (mode == 'noteSkin') ? noteSkinList : splashSkinList;
		var current:String = (mode == 'noteSkin') ? ClientPrefs.data.noteSkin : ClientPrefs.data.splashSkin;

		var maxW:Float = 0;
		for (skin in list)
		{
			var file:String = (mode == 'noteSkin') ? getNoteSkinFile(skin) : getSplashSkinFile(skin);
			var label:String = getStyleLabel(skin, file);
			var txt:FlxText = new FlxText(0, 0, 0, label, 22);
			txt.setFormat(Paths.font("vcr.ttf"), 22, (skin == current) ? FlxColor.YELLOW : FlxColor.WHITE,
				RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 1.5;
			txt.scrollFactor.set();
			skinPanelLines.push(txt);
			add(txt); // 加在背景之上
			if (txt.width > maxW) maxW = txt.width;
		}

		var bgW:Float = maxW + panelPadX * 2;
		var bgH:Float = list.length * panelLineH + panelPadY * 2;
		skinPanelBG.makeGraphic(Math.ceil(bgW), Math.ceil(bgH), FlxColor.BLACK);
		skinPanelBG.alpha = 0.5;

		var targetBGX:Float = FlxG.width - panelMargin - bgW;
		var targetBGY:Float = (FlxG.height - bgH) / 2;
		var startX:Float = flyIn ? panelHiddenX : targetBGX;

		skinPanelBG.x = startX;
		skinPanelBG.y = targetBGY;

		for (i => line in skinPanelLines)
		{
			line.x = startX + panelPadX;
			line.y = targetBGY + panelPadY + i * panelLineH + (panelLineH - line.height) / 2;
			line.fieldWidth = maxW;
		}
	}

	function tweenSkinPanelTo(targetBGX:Float)
	{
		FlxTween.cancelTweensOf(skinPanelBG);
		FlxTween.tween(skinPanelBG, {x: targetBGX}, 0.3, {ease: FlxEase.quartOut});
		for (line in skinPanelLines)
		{
			FlxTween.cancelTweensOf(line);
			FlxTween.tween(line, {x: targetBGX + panelPadX}, 0.3, {ease: FlxEase.quartOut});
		}
	}

	function showSkinPanel()
	{
		if (skinPanelLines.length == 0) return;
		var targetBGX:Float = FlxG.width - panelMargin - skinPanelBG.width;
		tweenSkinPanelTo(targetBGX);
	}

	function hideSkinPanel()
	{
		tweenSkinPanelTo(panelHiddenX);
	}

	function refreshSkinPanelHighlight()
	{
		if (panelMode == null) return;
		var current:String = (panelMode == 'noteSkin') ? ClientPrefs.data.noteSkin : ClientPrefs.data.splashSkin;
		var list:Array<String> = (panelMode == 'noteSkin') ? noteSkinList : splashSkinList;
		for (i => line in skinPanelLines)
		{
			if (i < list.length)
				line.color = (list[i] == current) ? FlxColor.YELLOW : FlxColor.WHITE;
		}
	}

	var changedMusic:Bool = false;
	function onChangePauseMusic()
	{
		if(ClientPrefs.data.pauseMusic == 'None')
			FlxG.sound.music.volume = 0;
		else
			FlxG.sound.playMusic(Paths.music(Paths.formatToSongPath(ClientPrefs.data.pauseMusic)));

		changedMusic = true;
	}

	function onChangeArrowColorMode()
	{
		Note.globalRgbShaders = [];
		Note.globalColorSwapShaders = [];

		notes.forEachAlive(function(n) n.destroy());
		notes.clear();
		splashes.forEachAlive(function(s) s.destroy());
		splashes.clear();

		for (i in 0...Note.colArray.length)
		{
			var note:StrumNote = new StrumNote(370 + (560 / Note.colArray.length) * i, -200, i, 0);
			changeNoteSkin(note);
			notes.add(note);

			var splash:NoteSplash = new NoteSplash(0, 0, NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix());
			splash.inEditor = true;
			splash.babyArrow = note;
			splash.ID = i;
			splash.kill();
			splashes.add(splash);
		}
	}

	function onChangeNoteSkin()
	{
		notes.forEachAlive(function(note:StrumNote) {
			changeNoteSkin(note);
			note.centerOffsets();
			note.centerOrigin();
		});
		refreshSkinPanelHighlight();
	}

	function changeNoteSkin(note:StrumNote)
	{
		var baseSkin:String = Note.defaultNoteSkin;
		var postfix:String = Note.getNoteSkinPostfix();
		var customBase:String = baseSkin + postfix;

		var customExists:Bool = false;
		if(ClientPrefs.data.arrowColorMode == 'HSV')
		{
			var parts:Array<String> = customBase.split('/');
			var filename:String = parts.pop();
			var folder:String = parts.join('/');
			customExists = Paths.fileExists('images/$folder/hsv/$filename.png', IMAGE) || Paths.fileExists('images/$customBase.png', IMAGE);
		}
		else
		{
			customExists = Paths.fileExists('images/$customBase.png', IMAGE);
		}

		var skin:String = customExists ? Note.getNoteSkinPath(customBase) : Note.getNoteSkinPath(baseSkin);

		note.texture = skin;
		note.reloadNote();
		note.playAnim('static');
	}

	function onChangeSplashSkin()
	{
		var skin:String = NoteSplash.defaultNoteSplash + NoteSplash.getSplashSkinPostfix();
		for (splash in splashes)
			splash.loadSplash(skin);

		playNoteSplashes();
		refreshSkinPanelHighlight();
	}

	function playNoteSplashes()
	{
		var rand:Int = 0;
		if (splashes.members[0] != null && splashes.members[0].maxAnims > 1)
			rand = FlxG.random.int(0, splashes.members[0].maxAnims - 1); // For playing the same random animation on all 4 splashes

		for (splash in splashes)
		{
			splash.revive();

			splash.spawnSplashNote(0, 0, splash.ID, null, false);
			if (splash.maxAnims > 1)
				splash.noteData = splash.noteData % Note.colArray.length + (rand * Note.colArray.length);

			var anim:String = splash.playDefaultAnim();
			var conf = splash.config.animations.get(anim);
			var offsets:Array<Float> = [0, 0];

			var minFps:Int = 22;
			var maxFps:Int = 26;
			if (conf != null)
			{
				offsets = conf.offsets;

				minFps = conf.fps[0];
				if (minFps < 0) minFps = 0;

				maxFps = conf.fps[1];
				if (maxFps < 0) maxFps = 0;
			}

			splash.offset.set(10, 10);
			if (offsets != null)
			{
				splash.offset.x += offsets[0];
				splash.offset.y += offsets[1];
			}

			if (splash.animation.curAnim != null)
				splash.animation.curAnim.frameRate = FlxG.random.int(minFps, maxFps);
		}
	}

	override function destroy()
	{
		if(changedMusic && !OptionsState.onPlayState) FlxG.sound.playMusic(Paths.music('freakyMenu'), 1, true);
		Note.globalRgbShaders = [];
		Note.globalColorSwapShaders = [];
		super.destroy();
	}

	function onChangeFPSCounter()
	{
		Main.updateFPSCounterVisibility();
	}

	function onChangeFPSStyle()
	{
		Main.updateFPSLayer();
	}

	function onChangeFPSLayer()
	{
		Main.updateFPSLayer();
	}

	// Fake OS 相关函数
	function onChangeFakeOSMode()
	{
		#if (!mobile && !html5)
		Main.updateWindowTitle();
		#end
	}

	function onChangeFakeWindowTitle()
	{
		ClientPrefs.data.fakeWindowTitle = ClientPrefs.data.fakeWindowTitlePreset;
		#if (!mobile && !html5)
		Main.updateWindowTitle();
		#end
	}

	/*#if native
	function onChangeVSync()
		lime.app.Application.current.window.vsync = ClientPrefs.data.vsync;
	#end*/
}
