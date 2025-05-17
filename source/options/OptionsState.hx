package options;

import states.MainMenuState;
import backend.StageData;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals',
		'Gameplay',
		'Extra Options'
		//#if TRANSLATIONS_ALLOWED , 'Language' #end
		#if mobile ,'Mobile Options' #end
	];
	private var grpOptions:FlxTypedGroup<FlxText>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;

	var selectorLeft:FlxText;
	var selectorRight:FlxText;

	private var optionTargetYs:Array<Float> = [];
	private var optionCurYs:Array<Float> = [];
	private var itemSpacing:Int = 92;
	private var startY:Float = 0;

	private var selectorLeftTargetX:Float = 0;
	private var selectorLeftTargetY:Float = 0;
	private var selectorRightTargetX:Float = 0;
	private var selectorRightTargetY:Float = 0;

	function openSelectedSubstate(label:String) {
		if (label != "Adjust Delay and Combo"){
			removeTouchPad();
			persistentUpdate = false;
		}
		switch(label)
		{
			case 'Note Colors':
				openSubState(new options.NotesColorSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals':
				openSubState(new options.VisualsSettingsSubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Extra Options':
				openSubState(new options.ExtraGameplaySettingSubState());
			case 'Adjust Delay and Combo':
				MusicBeatState.switchState(new options.NoteOffsetState());
			case 'Mobile Options':
				openSubState(new mobile.options.MobileOptionsSubState());
			case 'Language':
				openSubState(new options.LanguageSubState());
		}
	}

	override function create()
	{
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();

		bg.screenCenter();
		add(bg);

		if (controls.mobileC)
		{
			var tipText:FlxText = new FlxText(150, FlxG.height - 24, 0, 'Press ' + (FlxG.onMobile ? 'C' : 'CTRL or C') + ' to Go Mobile Controls Menu', 16);
			tipText.setFormat("VCR OSD Mono", 17, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			tipText.borderSize = 1.25;
			tipText.scrollFactor.set();
			tipText.antialiasing = ClientPrefs.data.antialiasing;
			add(tipText);
		}

		grpOptions = new FlxTypedGroup<FlxText>();
		add(grpOptions);

		itemSpacing = 92;
		var totalHeight = itemSpacing * options.length;
		startY = (FlxG.height - totalHeight) / 2 + itemSpacing / 2;

		optionTargetYs = [];
		optionCurYs = [];

		var leftMargin = 120; // 左对齐的x坐标

		for (num => option in options)
		{
			var optionText:FlxText = new FlxText(leftMargin, 0, 0, LanguageBasic.getPhrase('options_$option', option), 48);
			optionText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 48, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			optionText.borderSize = 2;
			optionText.antialiasing = ClientPrefs.data.antialiasing;
			optionText.x = leftMargin;
			optionText.y = startY + num * itemSpacing;
			grpOptions.add(optionText);

			optionTargetYs.push(optionText.y);
			optionCurYs.push(optionText.y);
		}

		selectorLeft = new FlxText(0, 0, 0, ">", 48);
		selectorLeft.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 48, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		selectorLeft.borderSize = 2;
		selectorLeft.antialiasing = ClientPrefs.data.antialiasing;
		add(selectorLeft);

		selectorRight = new FlxText(0, 0, 0, "<", 48);
		selectorRight.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 48, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		selectorRight.borderSize = 2;
		selectorRight.antialiasing = ClientPrefs.data.antialiasing;
		add(selectorRight);

		// 初始化选择器目标位置
		changeSelection();

		// 直接设置选择器初始位置
		selectorLeft.x = selectorLeftTargetX;
		selectorLeft.y = selectorLeftTargetY;
		selectorRight.x = selectorRightTargetX;
		selectorRight.y = selectorRightTargetY;

		ClientPrefs.saveSettings();

		addTouchPad('UP_DOWN', 'A_B_C');

		super.create();
	}

	override function closeSubState()
	{
		super.closeSubState();
		ClientPrefs.saveSettings();
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end
		controls.isInSubstate = false;
		removeTouchPad();
		addTouchPad('UP_DOWN', 'A_B_C');
		persistentUpdate = true;
	}

	var exiting = false;
	override function update(elapsed:Float) {
		super.update(elapsed);

		// 平滑滚动动画
		for (i in 0...grpOptions.length)
		{
			var targetY = optionTargetYs[i];
			optionCurYs[i] = FlxMath.lerp(targetY, optionCurYs[i], Math.exp(-elapsed * 12));
			grpOptions.members[i].y = optionCurYs[i];
		}

		// 选中项动效
		for (i in 0...grpOptions.length)
		{
			var item = grpOptions.members[i];
			if (i == curSelected)
			{
				item.scale.x = FlxMath.lerp(1.08, item.scale.x, Math.exp(-elapsed * 16));
				item.scale.y = FlxMath.lerp(1.08, item.scale.y, Math.exp(-elapsed * 16));
			}
			else
			{
				item.scale.x = FlxMath.lerp(1.0, item.scale.x, Math.exp(-elapsed * 16));
				item.scale.y = FlxMath.lerp(1.0, item.scale.y, Math.exp(-elapsed * 16));
			}
		}

		// < 和 > 选择器平滑动画
		selectorLeft.x = FlxMath.lerp(selectorLeftTargetX, selectorLeft.x, Math.exp(-elapsed * 16));
		selectorLeft.y = FlxMath.lerp(selectorLeftTargetY, selectorLeft.y, Math.exp(-elapsed * 16));
		selectorRight.x = FlxMath.lerp(selectorRightTargetX, selectorRight.x, Math.exp(-elapsed * 16));
		selectorRight.y = FlxMath.lerp(selectorRightTargetY, selectorRight.y, Math.exp(-elapsed * 16));

		if(!exiting) {
			if (controls.UI_UP_P)
				changeSelection(-1);
			if (controls.UI_DOWN_P)
				changeSelection(1);
			
			if (touchPad.buttonC.justPressed || FlxG.keys.justPressed.CONTROL && controls.mobileC)
			{
				persistentUpdate = false;
				openSubState(new mobile.substates.MobileControlSelectSubState());
			}

			if (controls.BACK)
			{
				exiting = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				if(onPlayState)
				{
					StageData.loadDirectory(PlayState.SONG);
					LoadingState.loadAndSwitchState(new PlayState());
					FlxG.sound.music.volume = 0;
				}
				else MusicBeatState.switchState(new MainMenuState());
			}
			else if (controls.ACCEPT) openSelectedSubstate(options[curSelected]);
		}
	}
	
	function changeSelection(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, options.length - 1);

		for (num => item in grpOptions.members)
		{
			item.alpha = 0.6;
			optionTargetYs[num] = startY + (num - curSelected) * itemSpacing;
			if (num == curSelected)
			{
				item.alpha = 1;
				// 选择器目标位置
				selectorLeftTargetX = item.x - 63;
				selectorLeftTargetY = optionTargetYs[num];
				selectorRightTargetX = item.x + item.width + 15;
				selectorRightTargetY = optionTargetYs[num];
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	override function destroy()
	{
		ClientPrefs.loadPrefs();
		super.destroy();
	}
}
