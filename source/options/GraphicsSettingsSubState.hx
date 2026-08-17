package options;

import objects.Character;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import backend.FramerateManager;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var drawFramerateOption:Int;
	var updateFramerateOption:Int;
	var aris:FlxGifSprite = null;
	var arisTween:FlxTween;
	var warningText:FlxText; // 警告文本变量

	public function new()
	{
		title = LanguageBasic.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu';

		// 初始化Aris动画
		aris = new FlxGifSprite(0, 0);
		aris.loadGif('assets/shared/images/gifs/aris.gif');
		aris.setGraphicSize(Std.int(aris.width * 2.5));
		aris.screenCenter();
		aris.x = 1500;
		aris.antialiasing = ClientPrefs.data.antialiasing;
		aris.visible = true;
		aris.alpha = 0.9;

		// 图形设置选项
		var option:Option = new Option(Language.get('low_quality'),
			Language.get("low_quality_desc"),
			'lowQuality',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('anti_aliasing'),
			Language.get("antialiasing_desc"),
			'antialiasing',
			BOOL);
		option.onChange = onChangeAntiAliasing;
		addOption(option);
		antialiasingOption = optionsArray.length - 1;

		var option:Option = new Option(Language.get('shaders'),
			Language.get("shaders_desc"),
			'shaders',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('gpu_caching'),
			Language.get("gpu_caching_desc"),
			'cacheOnGPU',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('playstate_pixel_perfect'),
			Language.get("playstate_pixel_perfect_desc"),
			'playStatePixelPerfect',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('resource_caching_on_reload'),
			Language.get("resource_caching_desc"),
			'cacheResourcesOnReload',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('optimized_note_loading'),
			Language.get("optimized_note_loading_desc"),
			'useOptimizedNoteLoading',
			STRING,
			['OFF', 'ON', 'AUTO']);
		addOption(option);

		#if !html5
		// 渲染帧率（draw framerate）
		var option:Option = new Option(Language.get('draw_framerate'),
			Language.get("draw_framerate_desc"),
			'drawFramerate',
			INT);
		option.minValue = 20;
		option.maxValue = 1000;
		option.defaultValue = ClientPrefs.data.drawFramerate;
		option.displayFormat = '%v FPS';
		option.onChange = onChangeDrawFramerate;
		addOption(option);
		drawFramerateOption = optionsArray.length - 1;

		// 逻辑更新帧率（update framerate / TPS）
		var option:Option = new Option(Language.get('update_framerate'),
			Language.get("update_framerate_desc"),
			'updateFramerate',
			INT);
		option.minValue = 1;
		option.maxValue = 1000;
		option.defaultValue = ClientPrefs.data.updateFramerate;
		option.displayFormat = '%v FPS';
		option.onChange = onChangeUpdateFramerate;
		addOption(option);
		updateFramerateOption = optionsArray.length - 1;
		#end

		var option:Option = new Option(Language.get('fps_rework'),
			Language.get("fps_rework_desc"),
			'fpsRework',
			BOOL);
		addOption(option);

		// PlayState宽屏自适应
		var option:Option = new Option(Language.get('playstate_adaptive_width'),
			Language.get("playstate_adaptive_width_desc"),
			'playStateAdaptiveWidth',
			BOOL);
		addOption(option);

		// 制谱器分辨率跟随窗口
		var option:Option = new Option(Language.get('chart_editor_follow_window'),
			Language.get("chart_editor_follow_window_desc"),
			'chartEditorFollowWindow',
			BOOL);
		addOption(option);

		// 飞溅数量限制设置
		var option:Option = new Option(Language.get('splash_limit'),
			Language.get("splash_limit_desc"),
			'splashLimitEnabled',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('max_splashes'),
			Language.get("max_splashes_desc"),
			'splashLimit',
			INT);
		option.minValue = 1;
		option.maxValue = 128;
		option.defaultValue = 16;
		option.displayFormat = '%v';
		addOption(option);

		// 资源加载线程数（默认 1 = 单线程；数值越大加载越并行，但更耗内存、低端机可能 OOM）
		var option:Option = new Option(Language.get('loading_threads'),
			Language.get("loading_threads_desc"),
			'loadingThreadCount',
			INT);
		option.minValue = 1;
		option.maxValue = 16;
		option.defaultValue = 1;
		option.displayFormat = '%v';
		addOption(option);

		// 是否显示进入歌曲时的加载界面
		var option:Option = new Option(Language.get('show_loading_screen'),
			Language.get("show_loading_screen_desc"),
			'loadingScreen',
			BOOL);
		addOption(option);

		super();
		insert(3, aris);

		// 初始化警告文本
		warningText = new FlxText(0, 50, FlxG.width - 40, "", 24);
		warningText.setFormat(Paths.font(Language.get('game_font')), 32, FlxColor.YELLOW, RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
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

	function onChangeDrawFramerate()
	{
		FramerateManager.applyDrawFramerate(ClientPrefs.data.drawFramerate);
	}

	function onChangeUpdateFramerate()
	{
		FramerateManager.applyUpdateFramerate(ClientPrefs.data.updateFramerate);
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

	override function changeSelection(change:Int = 0, skipRefresh:Bool = false, skipDesc:Bool = false)
	{
		// 安全清理之前的tween
		if (arisTween != null)
		{
			arisTween.cancel();
			arisTween.destroy();
			arisTween = null;
		}

		super.changeSelection(change, skipRefresh, skipDesc);

		// 确保aris存在再创建tween
		if (aris != null && aris.exists)
		{
			arisTween = FlxTween.tween(aris, {
				x: ((drawFramerateOption == curSelected) || (antialiasingOption == curSelected)) ? 900 : 1500,
				angle: (drawFramerateOption == curSelected) ? aris.angle : (Math.round(aris.angle / 360) * 360)
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
		if (aris != null && drawFramerateOption == curSelected)
			//aris.angle += elapsed * 100; // 使用时间增量保持旋转速度一致
			aris.angle += 1;

		#if !html5
		final showWarning:Bool = curSelected == drawFramerateOption &&
			(ClientPrefs.data.drawFramerate < 60 || ClientPrefs.data.drawFramerate > 240);

		final isCritical:Bool = curSelected == drawFramerateOption && ClientPrefs.data.drawFramerate > 480;

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
