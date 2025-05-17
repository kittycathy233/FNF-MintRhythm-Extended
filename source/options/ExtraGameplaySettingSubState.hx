package options;

class ExtraGameplaySettingSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Extra Options\nWTF, silly Chinese Option\n\nNot Done';
		rpcTitle = 'Extra Gameplay Settings Menu'; //for Discord Rich Presence

		// BOOL 类型设置
		var option:Option = new Option('show Game Version',
			Language.get("show_version_desc"),
			'exgameversion',
			BOOL);
		addOption(option);

		option = new Option('Focus Game',
			Language.get("focus_game_desc"),
			'autoPause',
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
		addOption(option);

		option = new Option('Extra-Rating Bounce',
			Language.get("exrating_bounce_desc"),
			'exratbounce',
			BOOL);
		addOption(option);

		option = new Option('Remove Perfect! Note Judgement',
			Language.get("rm_perfect_judge_desc"),
			'rmperfect',
			BOOL);
		addOption(option);

		option = new Option('Remove the "ms" offset',
			Language.get("rm_ms_offset_desc"),
			'rmmsTimeTxt',
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

		option = new Option('IconBop Style',
			Language.get("iconbop_style_desc"),
			'iconbopstyle',
			STRING,
			['Psych', 'OS', 'MintRhythm', 'Kade', 'Leather', 'SB', 'Vanilla', 'VSlice', 'Codename', 'NONE']);
		addOption(option);

		option = new Option('ScoreTxt Style',
			Language.get("scoretxt_style_desc"),
			'scoretxtstyle',
			STRING,
			['Psych', 'OS', 'MintRhythm', 'Kade']);
		addOption(option);

		option = new Option('Loading Style',
			Language.get("loading_style_desc"),
			'customFadeStyle',
			STRING,
			['Vanilla', 'NovaFlare Move', 'NovaFlare Alpha', 'MintRhythm']);
		addOption(option);

		option = new Option('TimeBar Style',
			Language.get("timebar_style_desc"),
			'timebarStyle',
			STRING,
			['default', 'Kade']);
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

		option = new Option('FPS-Txt Style',
			Language.get("fpstxt_style_desc"),
			'fpstxtStyle',
			STRING,
			['default', 'Kade']);
		addOption(option);

		option = new Option('Ratings Position',
			Language.get("ratings_pos_desc"),
			'ratingsPos',
			STRING,
			['camHUD', 'camGame']);
		addOption(option);

		// 语言设置放在最后
		option = new Option("Engine Language",
			Language.get("change_language_desc"),
			'language',
			STRING,
			["en_us", "zh_cn", "zh_tw"]);
		option.onChange = function() {
			ClientPrefs.saveSettings(); // 保存设置
			Language.load();            // 立即重载语言
			refreshAllTexts();          // 自定义方法刷新界面文本
		};
		addOption(option);

		super();
	}

	function onChangeHitsoundVolume()
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;
}