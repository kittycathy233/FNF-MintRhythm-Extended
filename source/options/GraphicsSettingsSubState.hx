package options;

import objects.Character;
import flixel.util.FlxColor;
import flixel.text.FlxText;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var arisDance:Int;
	var aris:FlxGifSprite = null;
	var arisTween:FlxTween;
	var warningText:FlxText; // 警告文本变量

	public function new()
	{
		title = LanguageBasic.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu';

		// 初始化Aris动画
		aris = new FlxGifSprite(0, 0);
		aris.loadGif('assets/shared/images/aris.gif');
		aris.setGraphicSize(Std.int(aris.width * 2.5));
		aris.screenCenter();
		aris.x = 1500;
		aris.antialiasing = ClientPrefs.data.antialiasing;
		aris.visible = true;
		aris.alpha = 0.9;

		// 图形设置选项
		var option:Option = new Option('Low Quality',
			Language.get("low_quality_desc"),
			'lowQuality',
			BOOL);
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			Language.get("antialiasing_desc"),
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing;
		addOption(option);
		antialiasingOption = optionsArray.length - 1;

		var option:Option = new Option('Shaders',
			Language.get("shaders_desc"),
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option('GPU Caching',
			Language.get("gpu_caching_desc"),
			'cacheOnGPU',
			BOOL);
		addOption(option);

		#if !html5
		// 帧率设置（非HTML5平台）
		var option:Option = new Option('Framerate',
			Language.get("framerate_desc"),
			'framerate',
			INT);
		addOption(option);
		arisDance = optionsArray.length - 1;

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 20;
		option.maxValue = 1000;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = onChangeFramerate;
		#end

		var option:Option = new Option('FPS Rework',
			Language.get("fps_rework_desc"),
			'fpsRework',
			BOOL);
		addOption(option);

		super();
		insert(3, aris);

		// 初始化警告文本
		warningText = new FlxText(0, 50, FlxG.width - 40, "", 24);
		warningText.setFormat(Paths.font("ResourceHanRoundedCN-Bold.ttf"), 32, FlxColor.YELLOW, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		warningText.visible = false;
		warningText.alpha = 0.8; // 添加透明度
		add(warningText); // 确保在最上层
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		if(ClientPrefs.data.framerate > FlxG.drawFramerate)
		{
			ClientPrefs.data.fpsRework ? 
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate :
				{
					FlxG.updateFramerate = ClientPrefs.data.framerate;
					FlxG.drawFramerate = ClientPrefs.data.framerate;
				};
		}
		else
		{
			ClientPrefs.data.fpsRework ?
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate :
				{
					FlxG.drawFramerate = ClientPrefs.data.framerate;
					FlxG.updateFramerate = ClientPrefs.data.framerate;
				};
		}
	}

	override function destroy()
	{
		if (arisTween != null)
		{
			arisTween.cancel();
			arisTween.destroy();
			arisTween = null;
		}
		
		if (aris != null)
		{
			aris.destroy();
			aris = null;
		}
		
		super.destroy();
	}

	override function changeSelection(change:Int = 0)
	{
		// 安全清理之前的tween
		if (arisTween != null)
		{
			arisTween.cancel();
			arisTween.destroy();
			arisTween = null;
		}

		super.changeSelection(change);

		// 确保aris存在再创建tween
		if (aris != null && aris.exists)
		{
			arisTween = FlxTween.tween(aris, {
				x: ((arisDance == curSelected) || (antialiasingOption == curSelected)) ? 900 : 1500,
				angle: (arisDance == curSelected) ? aris.angle : (Math.round(aris.angle / 360) * 360)
			}, 0.4, {
				ease: FlxEase.quadOut,
				onComplete: function(twn:FlxTween) {
					if (arisTween == twn)
						arisTween = null;
				}
			});
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// 更新Aris动画
		if (aris != null && arisDance == curSelected)
			//aris.angle += elapsed * 100; // 使用时间增量保持旋转速度一致
			aris.angle += 1;

		#if !html5
		final showWarning:Bool = curSelected == arisDance && 
			(ClientPrefs.data.framerate < 60 || ClientPrefs.data.framerate > 240);

		final isCritical:Bool = curSelected == arisDance && ClientPrefs.data.framerate > 480;

		warningText.visible = showWarning || isCritical;
		if (isCritical) {
			warningText.text = Language.get("fps_warning_2");
			warningText.color = FlxColor.RED;
		} else if (showWarning) {
			warningText.text = Language.get("fps_warning_1");
			warningText.color = FlxColor.YELLOW;
		}
		#end
	}
}