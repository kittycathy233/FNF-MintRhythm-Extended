package options;

import flixel.text.FlxText;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxTimer;
import backend.CustomFadeTransition;

class ExtraGameplaySettingSubState extends BaseOptionsMenu
{
	var errorText:FlxText = null;
	var errorBg:FlxSprite = null;
	var errorTimer:FlxTimer = null;
	
	var blueArchiveLanguageOption:Option = null;
	var blueArchiveLanguageOptionIndex:Int = -1;
	
	var ratingBounceOption:Option = null;
	var ratingBounceOptionIndex:Int = -1;
	var extraRatingBounceOption:Option = null;
	var extraRatingBounceOptionIndex:Int = -1;
	var ratingFallStyleOption:Option = null;
	var ratingFallStyleOptionIndex:Int = -1;
	var camelliaScaleOption:Option = null;
	var camelliaScaleOptionIndex:Int = -1;

	var healthOverflowOption:Option = null;
	var healthOverflowOptionIndex:Int = -1;

	var healthOverflowDrainOption:Option = null;
	var healthOverflowDrainOptionIndex:Int = -1;

	var smoothHPSpeedOption:Option = null;
	var smoothHPSpeedOptionIndex:Int = -1;

	var biggerInfoTextOption:Option = null;
	var biggerInfoTextOptionIndex:Int = -1;
	var timebarStyleOption:Option = null;
	var timebarStyleOptionIndex:Int = -1;

	var enableGameLogOption:Option = null;
	var enableConsoleLogOption:Option = null;

	public function new()
	{
		title = 'Extra Options\n\nNot Done';
		rpcTitle = 'Extra Gameplay Settings Menu'; //for Discord Rich Presence

		// BOOL 类型设置

		// 开发者模式（放在最顶部）：启用后可进入编辑器菜单，legacy 主界面显示 toolbox 入口
		var option:Option = new Option('Developer Mode',
			Language.get("developer_mode_desc"),
			'developer',
			BOOL);
		addOption(option);

		option = new Option('Show Extra-Rating',
			Language.get("show_exrating_desc"),
			'exratingDisplay',
			BOOL);
		addOption(option);

		option = new Option('Rating Bounce',
			Language.get("rating_bounce_desc"),
			'ratbounce',
			BOOL);
		ratingBounceOption = addOption(option);
		ratingBounceOptionIndex = optionsArray.length - 1;

		option = new Option('Extra-Rating Bounce',
			Language.get("exrating_bounce_desc"),
			'exratbounce',
			BOOL);
		extraRatingBounceOption = addOption(option);
		extraRatingBounceOptionIndex = optionsArray.length - 1;

		option = new Option('Perfect Judgement Mode',
			Language.get("rm_perfect_judge_desc"),
			'rmPerfect',
			STRING,
			['off', 'remove', 'sickPlus']);
		addOption(option);

		option = new Option('Remove the "ms" offset',
			Language.get("rm_ms_offset_desc"),
			'rmmsTimeTxt',
			BOOL);
		addOption(option);

		option = new Option('Show mode label in ms text',
			Language.get("show_mode_label_ms_desc"),
			'showModeLabelInMsTxt',
			BOOL);
		addOption(option);

		option = new Option('Show NPS',
			Language.get("nps_desc"),
			'showNPS',
			BOOL);
		addOption(option);

		option = new Option('Keep Sing Animation',
			Language.get("keep_sing_animation_desc"),
			'keepSingAnimation',
			BOOL);
		addOption(option);

		option = new Option('Ghost Effect (Multi-Press)',
			Language.get("ghost_effect_desc"),
			'ghostEffect',
			BOOL);
		addOption(option);

		option = new Option('ScoreTxt bounce',
			Language.get("scoretxt_bounce_desc"),
			'scoretxtbounce',
			BOOL);
		addOption(option);

		option = new Option('Single Note Splash Anim',
			Language.get("single_splashanim_desc"),
			'forceSingleSplashAnim',
			BOOL);
		addOption(option);

		var smoothHPOption:Option = new Option('smooth HP Bar',
			Language.get("smooth_hpbar_desc"),
			'smoothHP',
			BOOL);
		smoothHPOption.onChange = refreshHealthOverflowState;
		addOption(smoothHPOption);

		option = new Option('Health Overflow Icons',
			Language.get("health_overflow_desc"),
			'healthOverflow',
			BOOL);
		healthOverflowOption = addOption(option);
		healthOverflowOptionIndex = optionsArray.length - 1;
		healthOverflowOption.onChange = refreshHealthOverflowState;

		option = new Option('Overflow Return Speed',
			Language.get("health_overflow_drain_desc"),
			'healthOverflowDrain',
			FLOAT);
		option.displayFormat = '%v';
		option.scrollSpeed = 2;
		option.minValue = 2;
		option.maxValue = 50;
		option.changeValue = 0.5;
		option.decimals = 1;
		healthOverflowDrainOption = addOption(option);
		healthOverflowDrainOptionIndex = optionsArray.length - 1;

		option = new Option('Smooth HP Speed',
			Language.get("smooth_hp_speed_desc"),
			'smoothHPSpeed',
			FLOAT);
		option.displayFormat = '%v';
		option.scrollSpeed = 2;
		option.minValue = 1;
		option.maxValue = 30;
		option.changeValue = 1;
		option.decimals = 1;
		smoothHPSpeedOption = addOption(option);
		smoothHPSpeedOptionIndex = optionsArray.length - 1;

		option = new Option('CPU Strums',
			Language.get("cpu_strums_desc"),
			'cpuStrums',
			BOOL);
		addOption(option);

		option = new Option('Legacy Note Position',
			Language.get("legacy_notepos_desc"),
			'legacynotepos',
			BOOL);
		addOption(option);

		option = new Option('Score Incrase When BotPlay',
			Language.get("bot_addscore_desc"),
			'botplayScore',
			BOOL);
		addOption(option);

		option = new Option('BotPlay Perfect Timing',
			Language.get("botplay_perfect_timing_desc"),
			'botplayPerfectTiming',
			BOOL);
		addOption(option);

		option = new Option('Show "Combo" Sprite',
			Language.get("gameplay_combospr_desc"),
			'comboSprDisplay',
			BOOL);
		addOption(option);

		option = new Option('Rating Fall Style',
			Language.get("rating_fall_style_desc"),
			'ratingFallStyle',
			STRING,
			['Leather', 'Legacy', 'Kathy', 'Kathy(Legacy)', 'Camellia']);
		option.onChange = function() {
			updateBounceOptionsVisibility();
			updateCamelliaScaleVisibility();
		};
		ratingFallStyleOption = addOption(option);
		ratingFallStyleOptionIndex = optionsArray.length - 1;

		option = new Option('Camellia Scale Mode',
			Language.get("camellia_scale_mode_desc"),
			'camelliaScaleMode',
			STRING,
			['Proportional', 'Original']);
		camelliaScaleOption = addOption(option);
		camelliaScaleOptionIndex = optionsArray.length - 1;

		option = new Option('Show Event Information',
			Language.get("events_debug_desc"),
			'eventDebug',
			BOOL);
		addOption(option);

		option = new Option('Background Volume',
			Language.get("bgvol_desc"),
			'backgroundVolume',
			BOOL);
		addOption(option);

		option = new Option('Fixed Timestep',
			Language.get("fixed_timestep_desc"),
			'fixedTimestep',
			BOOL);
		addOption(option);
		option.onChange = function() {
			FlxG.fixedTimestep = ClientPrefs.data.fixedTimestep;
			trace("Fixed timestep changed to: " + FlxG.fixedTimestep);
		};

		// ===== 渲染质量（StageQuality） =====
		option = new Option('Stage Quality',
			Language.get("stage_quality_desc"),
			'stageQuality',
			STRING,
			['LOW', 'MEDIUM', 'HIGH', 'BEST']);
		option.onChange = function() {
			FlxG.stage.quality = ClientPrefs.getStageQuality();
		};
		addOption(option);

		// ===== rating/combo 精灵对象池 =====
		option = new Option('Combo Sprite Pooling',
			Language.get("combo_sprite_pooling_desc"),
			'comboSpritePooling',
			BOOL);
		addOption(option);

		option = new Option('Combo Sprite Pool Size',
			Language.get("combo_sprite_pool_size_desc"),
			'comboSpritePoolSize',
			INT);
		option.minValue = 0;
		option.maxValue = 128;
		option.changeValue = 8;
		addOption(option);

		// ===== 低延迟 / 性能模式 =====
		option = new Option('Auto Song Resync',
			Language.get("auto_song_resync_desc"),
			'autoResync',
			BOOL);
		addOption(option);

		option = new Option('Hide Missed Notes (Cull)',
			Language.get("hide_missed_notes_desc"),
			'hideMissedNotes',
			BOOL);
		addOption(option);

		option = new Option('Low-Latency Mode',
			Language.get("low_latency_desc"),
			'lowLatency',
			BOOL);
		addOption(option);

		// ===== 高密度谱面（SPAM）性能优化 =====
		option = new Option('Instant-Resolve Expired Notes',
			Language.get("instant_resolve_expired_desc"),
			'instantResolveExpired',
			BOOL);
		addOption(option);

		option = new Option('Disable Per-Note Scripts',
			Language.get("disable_note_lua_desc"),
			'disableNoteLua',
			BOOL);
		addOption(option);

		option = new Option('Note Performance Optimization',
			Language.get("note_optimization_desc"),
			'noteOptimization',
			BOOL);
		addOption(option);

		option = new Option('Note Object Pooling',
			Language.get("note_pooling_desc"),
			'notePooling',
			BOOL);
		addOption(option);

		option = new Option('Max Notes Spawned / Frame',
			Language.get("max_notes_per_frame_desc"),
			'maxNotesPerFrame',
			INT);
		option.scrollSpeed = 60;
		option.minValue = 0;
		option.maxValue = 300;
		option.changeValue = 5;
		option.decimals = 0;
		addOption(option);

		option = new Option('Background Volume Level',
			Language.get("bgvol_level_desc"),
			'backgroundVolumeLevel',
			PERCENT);
		option.scrollSpeed = 2;
		option.minValue = 0;
		option.maxValue = 1;
		option.changeValue = 0.02;
		option.decimals = 2;
		addOption(option);

		option = new Option('Rating Counter',
			Language.get("ratcounter_desc"),
			'ratCounter',
			BOOL);
		addOption(option);

		option = new Option('Rating Counter Animation',
			Language.get("ratcounter_anim_desc"),
			'ratCounterAnimation',
			BOOL);
		addOption(option);

		option = new Option('Show Watermark',
			Language.get("watermark_desc"),
			'waterMarkPlay',
			BOOL);
		addOption(option);

		option = new Option('Enable Game Log Display',
			Language.get("enable_game_log_desc"),
			'enableGameLog',
			BOOL);
		option.onChange = function() {
			if(Main.gameLogVar != null) {
				Main.gameLogVar.setEnabled(ClientPrefs.data.enableGameLog);
			}
		};
		enableGameLogOption = addOption(option);

		#if !mobile
		option = new Option('Enable Console Log Output',
			Language.get("enable_console_log_desc"),
			'enableConsoleLog',
			BOOL);
		option.onChange = function() {
			refreshGameLogDisabledState();
		};
		enableConsoleLogOption = addOption(option);
		#end

	// PERCENT 类型设置
		option = new Option('Ratings Opacity',
			Language.get("rating_opac_desc"),
			'ratingsAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		// STRING 类型设置
		option = new Option('HealthBar Style',
			Language.get("healthbar_style_desc"),
			'healthbarstyle',
			STRING,
			['Psych', 'OS', 'Kade', 'Leather']);
		addOption(option);
		
		option = new Option('Time Bar Stripes',
			Language.get("time_bar_stripes_desc"),
			'timeBarStripes',
			BOOL);
		addOption(option);

		option = new Option('Time Bar Gradient',
			Language.get("time_bar_gradient_desc"),
			'timeBarGradient',
			BOOL);
		addOption(option);

		option = new Option('IconBop Style',
			Language.get("iconbop_style_desc"),
			'iconbopstyle',
			STRING,
			['Psych', 'OS', 'Kathy', 'Leather', 'SB', 'Vanilla', 'VSlice(New)', 'VSlice(Old)', 'Codename', 'Dave', 'Squash', 'NovaFlare', 'NONE']);
		addOption(option);

		option = new Option('IconBop Normalize',
			Language.get("iconbop_normalize_desc"),
			'iconbopNormalize',
			BOOL);
		addOption(option);

		option = new Option('ScoreTxt Style',
			Language.get("scoretxt_style_desc"),
			'scoretxtstyle',
			STRING,
			['Psych', 'OS', 'Kathy', 'Kade', 'V-Slice', 'Leather']);
		addOption(option);

		option = new Option('Loading Style',
			Language.get("loading_style_desc"),
			'customFadeStyle',
			STRING,
			['None', 'V-Slice', 'NovaFlare Move', 'NovaFlare Alpha', 'Blue Archive', 'BA_Schale_Glow']);
		var loadingStyleOption = addOption(option);
		
		option = new Option('Blue Archive Language',
			Language.get("ba_language_desc"),
			'blueArchiveLanguage',
			STRING,
			['CN', 'JP', 'KR', 'EN']);
		option.onChange = function() {
			// 当语言改变时，清空图片列表，下次加载时会重新从新语言的文件夹读取
			CustomFadeTransition.resetBlueArchiveImages();
		};
		blueArchiveLanguageOption = addOption(option);
		blueArchiveLanguageOptionIndex = optionsArray.length - 1;

		option = new Option('TimeBar Style',
			Language.get("timebar_style_desc"),
			'timebarStyle',
			STRING,
			['Psych', 'Kade (Legacy)', 'Leather', 'Leather (Legacy)']);
		option.onChange = function() {
			updateBiggerInfoTextVisibility();
		};
		timebarStyleOption = addOption(option);
		timebarStyleOptionIndex = optionsArray.length - 1;

		option = new Option('Bigger Info Text', Language.get("bigger_info_text_desc"), 'biggerInfoText', BOOL);
		biggerInfoTextOption = addOption(option);
		biggerInfoTextOptionIndex = optionsArray.length - 1;

		option = new Option('BotPlayTxt Style',
			Language.get("botplaytxt_style_desc"),
			'botplayStyle',
			STRING,
			['Kade', 'Psych']);
		addOption(option);

		option = new Option('ShowCase Style',
			Language.get("showcase_style_desc"),
			'showcaseStyle',
			STRING,
			['Kade', 'Psych']);
		addOption(option);

		/*
		// 修复 FPS 字体选项
		option = new Option('FPS-Counter Font',
			Language.get("fpstxt_style_desc"),
			'fpsFont',
			STRING,
			['default', 'Kade']);
		option.onChange = function() {
			if (Main.fpsVar != null) {
				Main.fpsVar.updateFont(); // 调用字体更新方法
				Main.fpsVar.positionFPS(10, 3); // 重新定位确保布局正确
			}
		};
		addOption(option);*/

		option = new Option('Ratings Position',
			Language.get("ratings_pos_desc"),
			'ratingsPos',
			STRING,
			['camHUD', 'camGame']);
		addOption(option);

		option = new Option('HUD Zoom Speed',
			Language.get("hud_zoomstyle_desc"),
			'hudZoomStyle',
			STRING,
			['default', 'Fast', 'Slow', 'Kade']);
		addOption(option);

		option = new Option('HUD Zoom',
			Language.get("camhud_zoom_desc"),
			'hudSize',
			FLOAT);
		option.displayFormat = '%v X';
		option.scrollSpeed = 1;
		option.minValue = 0.5;
		option.maxValue = 1.2;
		option.changeValue = 0.005;
		option.decimals = 3; //小数点后三位
		addOption(option);

		// 语言设置放在最后
		option = new Option("Engine Language",
			Language.get("change_language_desc"),
			'language',
			STRING,
			["en_us", "zh_cn", "zh_tw"]);
		option.onChange = function() {
			ClientPrefs.saveSettings();
			Language.load();
			refreshAllTexts();
			
			// 由于父状态在运行,直接获取并刷新
			var parentState = cast(FlxG.state, OptionsState);
			if(parentState != null) {
				parentState.options = [
					Language.get("note_colors"),
					Language.get("controls"),
					Language.get("adjust_delay_combo"),
					Language.get("adjust_rating_offset"),
					Language.get("graphics"),
					Language.get("visuals"), 
					Language.get("gameplay"),
					Language.get("extra_options")
					#if mobile , Language.get("mobile_options") #end
				];
				
				parentState.optionDescriptions = [
					Language.get("note_colors_desc"),
					Language.get("controls_desc"),
					Language.get("adjust_delay_combo_desc"),
					Language.get("adjust_rating_offset_desc"),
					Language.get("graphics_desc"),
					Language.get("visuals_desc"),
					Language.get("gameplay_desc"),
					Language.get("extra_options_desc")
					#if mobile , Language.get("mobile_options_desc") #end
				];
				
				parentState.refreshTexts();
			}
		};
		addOption(option);

		#if !mobile
		option = new Option('Mods Import',
			Language.get("mods_import_desc"),
			'enableModsImport',
			BOOL);
		addOption(option);
		#end

		option = new Option('Use System Cursor',
			Language.get("use_system_cursor_desc"),
			'systemCursor',
			BOOL);
		option.onChange = function() {
			FlxG.mouse.useSystemCursor = ClientPrefs.data.systemCursor;
			ClientPrefs.saveSettings();
		};
		addOption(option);

		option = new Option('Startup Splash',
			Language.get("startup_splash_desc"),
			'splashMode',
			STRING,
			['Kathy', 'Flixel', 'Flixel+', 'None']);
		addOption(option);

		refreshGameLogDisabledState();
		refreshHealthOverflowState();

		super();
	}

	function showError(msg:String)
	{
		if (errorText == null) {
			errorText = new FlxText(0, 0, 400, "", 24);
			errorText.setFormat(Language.get("game_font"), 24, 0xFFFFFFFF, "center");
			errorText.scrollFactor.set();
			errorText.borderStyle = FlxTextBorderStyle.OUTLINE;
			errorText.borderColor = 0xFF000000;
			errorText.alpha = 1;
			errorText.cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];
			errorBg = new FlxSprite().makeGraphic(420, 40, 0xFFFF4444);
			errorBg.alpha = 0.85;
			errorBg.scrollFactor.set();
			errorBg.cameras = errorText.cameras;
			add(errorBg);
			add(errorText);
		}
		errorText.text = Language.get("error_title") + ": " + msg;
		errorText.x = FlxG.width - errorText.width - 30;
		errorText.y = 30;
		errorBg.x = errorText.x - 10;
		errorBg.y = errorText.y - 5;
		errorBg.visible = errorText.visible = true;
		if (errorTimer != null) errorTimer.cancel();
		errorTimer = new FlxTimer().start(1.5, function(_) {
			if (errorText != null) errorText.visible = false;
			if (errorBg != null) errorBg.visible = false;
		});
	}

	function refreshGameLogDisabledState()
	{
		if (enableGameLogOption != null)
		{
			#if mobile
			enableGameLogOption.disabled = false;
			#else
			var shouldDisable:Bool = !ClientPrefs.data.enableConsoleLog;
			enableGameLogOption.disabled = shouldDisable;
			if (shouldDisable && ClientPrefs.data.enableGameLog)
			{
				ClientPrefs.data.enableGameLog = false;
				if (Main.gameLogVar != null)
					Main.gameLogVar.setEnabled(false);
			}
			#end
		}
	}

	function refreshHealthOverflowState()
	{
	var smoothHPActive:Bool = ClientPrefs.data.smoothHP;
	var overflowActive:Bool = smoothHPActive && ClientPrefs.data.healthOverflow;
	if (healthOverflowOption != null)
	{
		healthOverflowOption.disabled = !smoothHPActive;
		if (!smoothHPActive && ClientPrefs.data.healthOverflow)
			{
				// 丝滑血条关闭时强制关闭超满血，回到原生血量上限
				ClientPrefs.data.healthOverflow = false;
			}
		}
		if (healthOverflowDrainOption != null)
			healthOverflowDrainOption.disabled = !overflowActive;
		if (smoothHPSpeedOption != null)
			smoothHPSpeedOption.disabled = !ClientPrefs.data.smoothHP;
	}

	override function changeSelection(change:Int = 0)
	{
		var newSelection = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);
		var isKathyStyle:Bool = ClientPrefs.data.ratingFallStyle == 'Kathy' || ClientPrefs.data.ratingFallStyle == 'Kathy(Legacy)';
		var isLeatherStyle:Bool = ClientPrefs.data.timebarStyle == 'Leather' || ClientPrefs.data.timebarStyle == 'Leather (Legacy)';
		
		// 如果要选择的是 Blue Archive Language 选项，但当前 loading 样式不是 Blue Archive，则跳过它
		if (blueArchiveLanguageOptionIndex != -1 && newSelection == blueArchiveLanguageOptionIndex && ClientPrefs.data.customFadeStyle != 'Blue Archive') {
			// 决定要跳的方向
			if (change > 0) {
				newSelection++;
			} else {
				newSelection--;
			}
			// 确保不会越界
			newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
		}
		
		// 如果要选择的是 Rating Bounce 或 Extra-Rating Bounce 选项，但当前不是 Kathy 风格，则跳过它们
		if (!isKathyStyle) {
			if (ratingBounceOptionIndex != -1 && newSelection == ratingBounceOptionIndex) {
				if (change > 0) {
					newSelection++;
				} else {
					newSelection--;
				}
				newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
			}
			
			if (extraRatingBounceOptionIndex != -1 && newSelection == extraRatingBounceOptionIndex) {
				if (change > 0) {
					newSelection++;
				} else {
					newSelection--;
				}
				newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
			}
		}

		// 如果要选择的是 Camellia Scale Mode 选项，但当前不是 Camellia 风格，则跳过它
		if (ClientPrefs.data.ratingFallStyle != 'Camellia' && camelliaScaleOptionIndex != -1 && newSelection == camelliaScaleOptionIndex) {
			if (change > 0) {
				newSelection++;
			} else {
				newSelection--;
			}
			newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
		}

		// 如果要选择的是 Bigger Info Text 选项，但当前不是 Leather 风格，则跳过它
		if (!isLeatherStyle && biggerInfoTextOptionIndex != -1 && newSelection == biggerInfoTextOptionIndex) {
			if (change > 0) {
				newSelection++;
			} else {
				newSelection--;
			}
			newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
		}

		// 如果要选择的是 Health Overflow Icons 选项，但丝滑血条未开启，则跳过它
		if (!ClientPrefs.data.smoothHP && healthOverflowOptionIndex != -1 && newSelection == healthOverflowOptionIndex) {
			if (change > 0) newSelection++; else newSelection--;
			newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
		}

		// 如果要选择的是 Overflow Return Speed 选项，但超满血未开启，则跳过它
		if (!ClientPrefs.data.healthOverflow && healthOverflowDrainOptionIndex != -1 && newSelection == healthOverflowDrainOptionIndex) {
			if (change > 0) newSelection++; else newSelection--;
			newSelection = FlxMath.wrap(newSelection, 0, optionsArray.length - 1);
		}

		// 调用父类的 changeSelection，但直接修改 curSelected 来改变位置
		curSelected = newSelection - change;
		super.changeSelection(change);
	}
	
	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		updateBounceOptionsVisibility();
		updateCamelliaScaleVisibility();
		updateBiggerInfoTextVisibility();
		
		// 控制 Blue Archive Language 选项的可见性和禁用状态
		if (blueArchiveLanguageOptionIndex != -1) {
			var isBlueArchiveActive:Bool = ClientPrefs.data.customFadeStyle == 'Blue Archive';
			
			// 找到选项的视觉元素并调整其透明度
			for (i in 0...grpOptions.length) {
				var optText:Alphabet = grpOptions.members[i];
				if (optText != null && i == blueArchiveLanguageOptionIndex) {
					optText.alpha = isBlueArchiveActive ? 1 : 0.3;
				}
			}
			
			for (text in grpTexts) {
				if (text.ID == blueArchiveLanguageOptionIndex) {
					text.alpha = isBlueArchiveActive ? 1 : 0.3;
				}
			}
		}
	}
	
	function updateBounceOptionsVisibility()
	{
		var isKathyStyle:Bool = ClientPrefs.data.ratingFallStyle == 'Kathy' || ClientPrefs.data.ratingFallStyle == 'Kathy(Legacy)';
		
		// 更新 Rating Bounce 选项的可见性
		if (ratingBounceOptionIndex != -1) {
			for (i in 0...grpOptions.length) {
				var optText:Alphabet = grpOptions.members[i];
				if (optText != null && i == ratingBounceOptionIndex) {
					optText.alpha = isKathyStyle ? 1 : 0.3;
				}
			}
			
			for (checkbox in checkboxGroup) {
				if (checkbox.ID == ratingBounceOptionIndex) {
					checkbox.alpha = isKathyStyle ? 1 : 0.3;
				}
			}
		}
		
		// 更新 Extra-Rating Bounce 选项的可见性
		if (extraRatingBounceOptionIndex != -1) {
			for (i in 0...grpOptions.length) {
				var optText:Alphabet = grpOptions.members[i];
				if (optText != null && i == extraRatingBounceOptionIndex) {
					optText.alpha = isKathyStyle ? 1 : 0.3;
				}
			}
			
			for (checkbox in checkboxGroup) {
				if (checkbox.ID == extraRatingBounceOptionIndex) {
					checkbox.alpha = isKathyStyle ? 1 : 0.3;
				}
			}
		}
	}

	// Camellia Scale Mode 仅在 Camellia 风格下可用，其它风格变灰
	function updateCamelliaScaleVisibility()
	{
		if (camelliaScaleOptionIndex == -1) return;

		var isCamellia:Bool = ClientPrefs.data.ratingFallStyle == 'Camellia';
		var targetAlpha:Float = isCamellia ? 1 : 0.3;

		for (i in 0...grpOptions.length) {
			var optText:Alphabet = grpOptions.members[i];
			if (optText != null && i == camelliaScaleOptionIndex) {
				optText.alpha = targetAlpha;
			}
		}

		for (text in grpTexts) {
			if (text.ID == camelliaScaleOptionIndex) {
				text.alpha = targetAlpha;
			}
		}
	}

	function updateBiggerInfoTextVisibility()
	{
		var isLeatherStyle:Bool = ClientPrefs.data.timebarStyle == 'Leather' || ClientPrefs.data.timebarStyle == 'Leather (Legacy)';
		
		if (biggerInfoTextOptionIndex != -1) {
			// 更新选项文本的透明度
			for (i in 0...grpOptions.length) {
				var optText:Alphabet = grpOptions.members[i];
				if (optText != null && i == biggerInfoTextOptionIndex) {
					optText.alpha = isLeatherStyle ? 1 : 0.3;
				}
			}
			
			// 更新值文本的透明度
			for (text in grpTexts) {
				if (text.ID == biggerInfoTextOptionIndex) {
					text.alpha = isLeatherStyle ? 1 : 0.3;
				}
			}
			
			// 更新复选框的透明度（针对 BOOL 类型）
			for (checkbox in checkboxGroup) {
				if (checkbox.ID == biggerInfoTextOptionIndex) {
					checkbox.alpha = isLeatherStyle ? 1 : 0.3;
				}
			}
		}
	}
}