package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import flixel.ui.FlxButton;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import openfl.desktop.ClipboardFormats;
import openfl.filesystem.File;
import haxe.zip.Reader;
import haxe.io.BytesInput;
import sys.io.File as SysFile;
import sys.FileSystem;
import states.ModsImport;

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = '1.0.4';
	public static var kathyEngineVersion:String = '1.1.0 dev';
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED 'mods', #end
		'credits'
	];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var rightOption:String = 'options';

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static var showOutdatedWarning:Bool = true;
	var dropFileHandler:Dynamic = null;
	private var tipText:FlxText;
	var selectedSomethin:Bool = false;
	var timeNotMoving:Float = 0;

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		// Calculate yScroll based on the ACTUAL number of menu items.
		// In legacy mode, createLegacyMenu() replaces optionShit with a longer
		// list (story_mode, freeplay, mods, achievements, credits, options),
		// so we must count those items here — otherwise yScroll is too high
		// and the background scrolls too much, exposing black edges.
		var yScroll:Float;
		if (ClientPrefs.data.legacyMainMenu)
		{
			var legacyCount:Int = 4 // story_mode, freeplay, credits, options
				#if MODS_ALLOWED + 1 #end
				#if ACHIEVEMENTS_ALLOWED + 1 #end;
			yScroll = Math.max(0.25 - (0.05 * (legacyCount - 4)), 0.1);
		}
		else
			yScroll = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		if (ClientPrefs.data.legacyMainMenu)
			createLegacyMenu();
		else
			createModernMenu();


		var mrVer:FlxText = new FlxText(12, FlxG.height - 66, 0, 'Kathy Engine v' + kathyEngineVersion, 12);
		mrVer.scrollFactor.set();
		mrVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(mrVer);
		var psychVer:FlxText = new FlxText(12, FlxG.height - 46, 0, "Psych Engine v" + psychEngineVersion, 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 26, 0, 'Friday Night Funkin\' v0.2.8', 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		
		var tipsContent = CoolUtil.tipsShow();
		if(tipsContent != null && tipsContent.length > 0) {
			var tipsArray = tipsContent.split('\n');
			var randomTip = StringTools.replace(
				tipsArray[FlxG.random.int(0, tipsArray.length - 1)].trim(),
				"\\n",
				"\n"
			);
			
			tipText = new FlxText(30, 30, FlxG.width - 60, randomTip);
			tipText.scrollFactor.set();
			tipText.setFormat(
				Paths.font(Language.get('game_font')), 
				22, 
				FlxColor.WHITE, 
				RIGHT, 
				FlxTextBorderStyle.OUTLINE, 
				FlxColor.BLACK
			);
			tipText.height = tipText.textField.textHeight + 8;
			add(tipText);
		}

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != kathyEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);

		addTouchPad(ClientPrefs.data.legacyMainMenu ? 'UP_DOWN' : 'NONE', ClientPrefs.data.legacyMainMenu ? 'A_B_E' : 'E');

		#if desktop
		if (ClientPrefs.data.enableModsImport) {
			dropFileHandler = function(path:String) {
				if (path.toLowerCase().endsWith('.zip')) {
					var fileName = path.substring(path.lastIndexOf('/') + 1);
					handleZipImport(path, fileName);
				}
			};
			Application.current.window.onDropFile.add(dropFileHandler);
		}
		#end
	}

	function createModernMenu()
	{
		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, (num * 140) + 90);
			item.y += (4 - optionShit.length) * 70;
			item.screenCenter(X);
		}

		if (leftOption != null)
			leftItem = createMenuItem(leftOption, 60, 490);
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
			rightItem.x -= rightItem.width;
		}
	}

	function createLegacyMenu()
	{
		var fullOptions:Array<String> = [
			'story_mode',
			'freeplay',
			#if MODS_ALLOWED 'mods', #end
			#if ACHIEVEMENTS_ALLOWED 'achievements', #end
			'credits',
			'options'
		];

		for (i in 0...fullOptions.length)
		{
			var option:String = fullOptions[i];
			var offset:Float = 108 - (Math.max(fullOptions.length, 4) - 4) * 80;
			var menuItem:FlxSprite = new FlxSprite(0, (i * 140) + offset);
			menuItem.antialiasing = ClientPrefs.data.antialiasing;

			// Resolve which atlas to load and its animation prefix.
			// See resolveLegacyAtlas() for the full priority order.
			var info:{atlas:String, prefix:String} = resolveLegacyAtlas(option);
			menuItem.frames = Paths.getSparrowAtlas(info.atlas);

			// Old Psych 0.7.3 textures use "basic"/"white", new textures use
			// "idle"/"selected". Try old-style first, fall back to new-style.
			addMenuAnim(menuItem, 'idle', info.prefix, 'basic', 'idle');
			addMenuAnim(menuItem, 'selected', info.prefix, 'white', 'selected');

			menuItem.animation.play('idle');
			menuItems.add(menuItem);
			var scr:Float = (fullOptions.length - 4) * 0.135;
			if (fullOptions.length < 6)
				scr = 0;
			menuItem.scrollFactor.set(0, scr);
			menuItem.updateHitbox();
			menuItem.screenCenter(X);
		}

		optionShit = fullOptions;
	}

	/**
	 * Resolves which atlas to load for legacy mode and the animation prefix
	 * (the part of the frame name before the suffix, e.g. "awards" in "awards basic0000").
	 *
	 * Priority:
	 *   1. Mod-provided `mainmenu/menu_$legacyName` (e.g. mod's menu_awards with basic/white)
	 *   2. Mod-provided `mainmenu/menu_$option`    (e.g. mod's menu_achievements with idle/selected)
	 *   3. Bundled `mainmenu/legacy/menu_$legacyName` (old Psych 0.7.3 textures)
	 *   4. Bundled `mainmenu/menu_$option`            (modern textures, last resort)
	 *
	 * This ensures most mods — which place textures directly in `mainmenu/` — work
	 * in legacy mode, while still defaulting to the bundled old-style textures when
	 * no mod override is present.
	 */
	function resolveLegacyAtlas(option:String):{atlas:String, prefix:String}
	{
		// Map modern option names to legacy texture names
		var legacyName:String = switch (option)
		{
			case 'achievements': 'awards';
			default: option;
		};

		#if MODS_ALLOWED
		// 1-2. Mod override: if a mod provides textures in mainmenu/, use them.
		//      Most mods place textures here, not in mainmenu/legacy/.
		if (modProvidesImage('mainmenu/menu_' + legacyName))
			return {atlas: 'mainmenu/menu_' + legacyName, prefix: legacyName};
		if (option != legacyName && modProvidesImage('mainmenu/menu_' + option))
			return {atlas: 'mainmenu/menu_' + option, prefix: option};
		#end

		// 3. Bundled legacy textures (or mod-provided mainmenu/legacy/ override)
		if (Paths.fileExists('images/mainmenu/legacy/menu_' + legacyName + '.png', IMAGE))
			return {atlas: 'mainmenu/legacy/menu_' + legacyName, prefix: legacyName};

		// 4. Fall back to modern texture name (new-style idle/selected)
		return {atlas: 'mainmenu/menu_' + option, prefix: option};
	}

	#if MODS_ALLOWED
	/**
	 * Checks whether a mod (global mods, current mod, or global mods folder)
	 * provides the given image — WITHOUT checking bundled assets.
	 * Used to give mod-provided `mainmenu/menu_*` textures priority over the
	 * bundled `mainmenu/legacy/` textures in legacy mode.
	 */
	function modProvidesImage(key:String):Bool
	{
		var modKey:String = 'images/' + key + '.png';
		for (mod in Mods.getGlobalMods())
			if (FileSystem.exists(Paths.mods('$mod/$modKey')))
				return true;
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			if (FileSystem.exists(Paths.mods(Mods.currentModDirectory + '/' + modKey)))
				return true;
		return FileSystem.exists(Paths.mods(modKey));
	}
	#end

	/**
	 * Adds an animation trying `firstSuffix` first, then `fallbackSuffix` if no
	 * frames matched the prefix. In flixel 5.9.0, addByPrefix does not create
	 * the animation when zero frames match the prefix, so getByName returns
	 * null — that's our signal to try the alternative.
	 *
	 * Usage:
	 *   - Legacy mode: addMenuAnim(spr, 'idle', prefix, 'basic', 'idle')
	 *   - Modern mode: addMenuAnim(spr, 'idle', name, 'idle', 'basic')
	 */
	function addMenuAnim(sprite:FlxSprite, animName:String, prefix:String, firstSuffix:String, fallbackSuffix:String):Void
	{
		sprite.animation.addByPrefix(animName, prefix + ' ' + firstSuffix, 24);
		if (sprite.animation.getByName(animName) == null)
			sprite.animation.addByPrefix(animName, prefix + ' ' + fallbackSuffix, 24);
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		// New-style first (idle/selected), fall back to old-style (basic/white)
		// so mods with old Psych 0.7.3 textures also work in the modern layout.
		addMenuAnim(menuItem, 'idle', name, 'idle', 'basic');
		addMenuAnim(menuItem, 'selected', name, 'selected', 'white');
		menuItem.animation.play('idle');
		menuItem.updateHitbox();
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			#if desktop
			if (ClientPrefs.data.legacyMainMenu)
				updateLegacyInput(elapsed);
			#end

			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			if (!ClientPrefs.data.legacyMainMenu)
				updateModernInput(elapsed);

			if (controls.BACK #if desktop || (FlxG.mouse.justPressedRight) #end)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			var acceptTriggered:Bool = controls.ACCEPT;
			#if desktop
			if (!ClientPrefs.data.legacyMainMenu)
				acceptTriggered = acceptTriggered || (FlxG.mouse.overlaps(menuItems, FlxG.camera) && FlxG.mouse.justPressed);
			else
				acceptTriggered = acceptTriggered || FlxG.mouse.justPressed;
			#end

			if (acceptTriggered)
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;
				FlxG.mouse.visible = false;

				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:String;

				if (!ClientPrefs.data.legacyMainMenu)
				{
					switch(curColumn)
					{
						case CENTER:
							option = optionShit[curSelected];
							item = menuItems.members[curSelected];
						case LEFT:
							option = leftOption;
							item = leftItem;
						case RIGHT:
							option = rightOption;
							item = rightItem;
					}
				}
				else
				{
					option = optionShit[curSelected];
					item = menuItems.members[curSelected];
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (option)
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(new FreeplayState());

						#if MODS_ALLOWED
						case 'mods':
							MusicBeatState.switchState(new ModsMenuState());
						#end

						#if ACHIEVEMENTS_ALLOWED
						case 'achievements':
							MusicBeatState.switchState(new AchievementsMenuState());
						#end

						case 'credits':
							MusicBeatState.switchState(new CreditsState());
						case 'options':
							MusicBeatState.switchState(new OptionsState());
							OptionsState.onPlayState = false;
							if (PlayState.SONG != null)
							{
								PlayState.SONG.arrowSkin = null;
								PlayState.SONG.splashSkin = null;
								PlayState.stageUI = 'normal';
							}
						case 'donate':
							CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
							selectedSomethin = false;
							item.visible = true;
						default:
							trace('Menu Item ${option} doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
					}
				});

				for (i in 0...menuItems.members.length)
				{
					if (!ClientPrefs.data.legacyMainMenu && menuItems.members[i] == item)
						continue;
					if (ClientPrefs.data.legacyMainMenu && i == curSelected)
						continue;
					FlxTween.tween(menuItems.members[i], {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			else if (controls.justPressed('debug_1') || touchPad.buttonE.justPressed)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
		}

		super.update(elapsed);
	}

	#if desktop
	/**
	 * Legacy menu mouse input (desktop only):
	 *   - Mouse wheel up/down: change selection
	 *   - Left click anywhere: confirm currently selected item
	 *   - Right click anywhere: go back (title screen)
	 */
	function updateLegacyInput(elapsed:Float):Void
	{
		// Show mouse cursor on any mouse movement / click
		if (FlxG.mouse.deltaScreenX != 0 || FlxG.mouse.deltaScreenY != 0
			|| FlxG.mouse.justPressed || FlxG.mouse.justPressedRight
			|| FlxG.mouse.wheel != 0)
		{
			FlxG.mouse.visible = true;
			timeNotMoving = 0;
		}
		else
		{
			timeNotMoving += elapsed;
			if (timeNotMoving > 2)
				FlxG.mouse.visible = false;
		}

		// Mouse wheel: scroll selection up/down
		if (FlxG.mouse.wheel > 0)
			changeItem(-1);
		else if (FlxG.mouse.wheel < 0)
			changeItem(1);
	}
	#end

	function updateModernInput(elapsed:Float)
	{
		var allowMouse:Bool = allowMouse;
		if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed))
		{
			allowMouse = false;
			FlxG.mouse.visible = true;
			timeNotMoving = 0;

			var selectedItem:FlxSprite;
			switch(curColumn)
			{
				case CENTER:
					selectedItem = menuItems.members[curSelected];
				case LEFT:
					selectedItem = leftItem;
				case RIGHT:
					selectedItem = rightItem;
			}

			if(leftItem != null && FlxG.mouse.overlaps(leftItem))
			{
				allowMouse = true;
				if(selectedItem != leftItem)
				{
					curColumn = LEFT;
					changeItem();
				}
			}
			else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
			{
				allowMouse = true;
				if(selectedItem != rightItem)
				{
					curColumn = RIGHT;
					changeItem();
				}
			}
			else
			{
				var dist:Float = -1;
				var distItem:Int = -1;
				for (i in 0...optionShit.length)
				{
					var memb:FlxSprite = menuItems.members[i];
					if(FlxG.mouse.overlaps(memb))
					{
						var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
						if (dist < 0 || distance < dist)
						{
							dist = distance;
							distItem = i;
							allowMouse = true;
						}
					}
				}

				if(distItem != -1 && selectedItem != menuItems.members[distItem])
				{
					curColumn = CENTER;
					curSelected = distItem;
					changeItem();
				}
			}
		}
		else
		{
			timeNotMoving += elapsed;
			if(timeNotMoving > 2) FlxG.mouse.visible = false;
		}

		switch(curColumn)
		{
			case CENTER:
				if(controls.UI_LEFT_P && leftOption != null)
				{
					curColumn = LEFT;
					changeItem();
				}
				else if(controls.UI_RIGHT_P && rightOption != null)
				{
					curColumn = RIGHT;
					changeItem();
				}

			case LEFT:
				if(controls.UI_RIGHT_P)
				{
					curColumn = CENTER;
					changeItem();
				}

			case RIGHT:
				if(controls.UI_LEFT_P)
				{
					curColumn = CENTER;
					changeItem();
				}
		}
	}

	function changeItem(huh:Int = 0)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));

		if (ClientPrefs.data.legacyMainMenu)
			changeLegacyItem(huh);
		else
			changeModernItem(huh);
	}

	function changeModernItem(huh:Int = 0)
	{
		if(huh != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + huh, 0, optionShit.length - 1);

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}

	function changeLegacyItem(huh:Int = 0)
	{
		menuItems.members[curSelected].animation.play('idle');
		menuItems.members[curSelected].updateHitbox();
		menuItems.members[curSelected].screenCenter(X);

		curSelected += huh;

		if (curSelected >= menuItems.length)
			curSelected = 0;
		if (curSelected < 0)
			curSelected = menuItems.length - 1;

		menuItems.members[curSelected].animation.play('selected');
		menuItems.members[curSelected].centerOffsets();
		menuItems.members[curSelected].screenCenter(X);

		camFollow.setPosition(menuItems.members[curSelected].getGraphicMidpoint().x,
			menuItems.members[curSelected].getGraphicMidpoint().y - (menuItems.length > 4 ? menuItems.length * 8 : 0));
	}

	function handleZipImport(zipPath:String, zipName:String):Void {
		var fileName = zipName.substring(zipName.lastIndexOf('/') + 1);
		MusicBeatState.switchState(new ModsImport(zipPath, fileName));
	}

	override function destroy()
	{
		#if desktop
		if (dropFileHandler != null) {
			Application.current.window.onDropFile.remove(dropFileHandler);
			dropFileHandler = null;
		}
		#end
		super.destroy();
	}
}