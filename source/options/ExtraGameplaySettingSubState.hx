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

	public function new()
	{
		title = 'Extra Options\n\nNot Done';
		rpcTitle = 'Extra Gameplay Settings Menu'; //for Discord Rich Presence

		// BOOL 类型设置
		var option:Option = new Option('Show Extra-Rating',
			Language.get("show_exrating_desc"),
			'exratingDisplay',
			BOOL);
		addOption(option);

		option = new Option('Rating Bounce',
			Language.get("rating_bounce_desc"),
			'ratbounce',
			BOOL);
		addOption(option);

		option = new Option('Extra-Rating Bounce',
			Language.get("exrating_bounce_desc"),
			'exratbounce',
			BOOL);
		addOption(option);

		option = new Option('Remove Perfect! Note Judgement',
			Language.get("rm_perfect_judge_desc"),
			'rmPerfect',
			BOOL);
		addOption(option);

		option = new Option('Remove the "ms" offset',
			Language.get("rm_ms_offset_desc"),
			'rmmsTimeTxt',
			BOOL);
		addOption(option);

		option = new Option('Show mode label in ms text',
			'Show (BOT) or (REPLAY) label in ms timing text',
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

		option = new Option('smooth HP Bar',
			Language.get("smooth_hpbar_desc"),
			'smoothHP',
			BOOL);
		addOption(option);

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
			['Simple', 'Legacy', 'Kathy', 'Kathy(Legacy)']);
		addOption(option);

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
		addOption(option);

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
			['Psych', 'OS', 'Kade']);
		addOption(option);
		
		option = new Option('Time Bar Stripes',
			Language.get("time_bar_stripes_desc"),
			'timeBarStripes',
			BOOL);
		addOption(option);

		option = new Option('IconBop Style',
			Language.get("iconbop_style_desc"),
			'iconbopstyle',
			STRING,
			['Psych', 'OS', 'Kathy', 'Leather', 'SB', 'Vanilla', 'VSlice(New)', 'VSlice(Old)', 'Codename', 'Dave', 'NovaFlare', 'NONE']);
		addOption(option);

		option = new Option('ScoreTxt Style',
			Language.get("scoretxt_style_desc"),
			'scoretxtstyle',
			STRING,
			['Psych', 'OS', 'Kathy', 'Kade', 'V-Slice']);
		addOption(option);

		option = new Option('Loading Style',
			Language.get("loading_style_desc"),
			'customFadeStyle',
			STRING,
			['V-Slice', 'NovaFlare Move', 'NovaFlare Alpha', 'Blue Archive', 'BA_Schale_Glow']);
		var loadingStyleOption = addOption(option);
		
		option = new Option('Blue Archive Language',
			'Select language for Blue Archive loading transition',
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
			['Psych', 'Kade (Legacy)', 'Leather']);
		addOption(option);

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

	override function changeSelection(change:Int = 0)
	{
		var newSelection = FlxMath.wrap(curSelected + change, 0, optionsArray.length - 1);
		
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
		
		// 调用父类的 changeSelection，但直接修改 curSelected 来改变位置
		curSelected = newSelection - change;
		super.changeSelection(change);
	}
	
	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
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
}