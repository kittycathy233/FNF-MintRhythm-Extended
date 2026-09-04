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

		// 图片资源加载失败时，就地显示「红色十字 + 失败路径」占位标记
		var option:Option = new Option(Language.get('asset_error_overlay'),
			Language.get("asset_error_overlay_desc"),
			'assetErrorOverlay',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('optimized_note_loading'),
			Language.get("optimized_note_loading_desc"),
			'useOptimizedNoteLoading',
			STRING,
			['OFF', 'ON', 'AUTO']);
		addOption(option);

		#if !html5
		// 帧率设置（非HTML5平台）
		var option:Option = new Option(Language.get('framerate'),
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

		// 制谱器深浅色主题
		var option:Option = new Option(Language.get('chart_editor_theme'),
			Language.get("chart_editor_theme_desc"),
			'chartEditorTheme',
			STRING,
			['Default', 'Light', 'Dark']);
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

		// 飞溅超限处理模式：现状（达到上限则忽略）或 覆盖（销毁最早生成的那个再生成）
		var option:Option = new Option(Language.get('splash_limit_mode'),
			Language.get("splash_limit_mode_desc"),
			'splashLimitMode',
			STRING,
			['skip', 'replace']);
		option.valueLocalizations = [
			'skip'    => Language.get('splash_limit_mode_skip'),
			'replace' => Language.get('splash_limit_mode_replace')
		];
		option.defaultValue = 'skip';
		addOption(option);

		// Hold Cover 数量限制设置（与飞溅数量限制类似）
		var option:Option = new Option(Language.get('hold_cover_limit'),
			Language.get("hold_cover_limit_desc"),
			'holdCoverLimitEnabled',
			BOOL);
		addOption(option);

		var option:Option = new Option(Language.get('max_hold_covers'),
			Language.get("max_hold_covers_desc"),
			'holdCoverLimit',
			INT);
		option.minValue = 1;
		option.maxValue = 128;
		option.defaultValue = 10;
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