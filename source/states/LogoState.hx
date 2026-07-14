package states;

import states.TitleState;

/**
 * 开屏 Logo 画面（复刻自 Mint-Archive 的 LogoState）
 * 逻辑：显示居中 logo -> 淡入(1s) -> 停留(1.5s) -> 淡出(1s)，同时播放 bells-logo 音效，
 * 播放结束或用户按键后进入 TitleState。
 */
class LogoState extends MusicBeatState
{
	var bg:FlxSprite;
	var logo:FlxSprite;

	var finished:Bool = false;
	var skipped:Bool = false;

	override function create():Void
	{
		super.create();

		FlxG.mouse.visible = false;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		add(bg);

		logo = new FlxSprite();
		logo.loadGraphic(Paths.image('logo'));
		logo.antialiasing = ClientPrefs.data.antialiasing;
		logo.alpha = 0;
		logo.screenCenter();
		add(logo);

		// 播放 Logo 音效
		FlxG.sound.play(Paths.sound('bells-logo'), 1);

		// 淡入 -> 停留 -> 淡出 -> 进入标题
		FlxTween.tween(logo, {alpha: 1}, 1, {
			ease: FlxEase.quadIn,
			onComplete: function(_)
			{
				new FlxTimer().start(1.5, function(_)
				{
					FlxTween.tween(logo, {alpha: 0}, 0.6, {
						ease: FlxEase.quadOut,
						onComplete: function(_) finishLogo()
					});
				});
			}
		});

		// LogoState 是启动后第一个运行的 state，MobileData 可能尚未初始化，
		// 直接 addTouchPad 会因 actionModes 为空而崩溃，这里仅在移动端并确保初始化后再添加。
		#if mobile
		if (MobileData.actionModes == null || !MobileData.actionModes.exists('A'))
			MobileData.init();
		addTouchPad('NONE', 'A');
		#end
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		if (!skipped && (controls.ACCEPT || controls.BACK #if desktop || FlxG.keys.justPressed.ANY #end))
			skipLogo();
	}

	function skipLogo():Void
	{
		if (skipped)
			return;
		skipped = true;
		FlxTween.cancelTweensOf(logo);
		finishLogo();
	}

	function finishLogo():Void
	{
		if (finished)
			return;
		finished = true;
		MusicBeatState.switchState(new TitleState());
	}
}
